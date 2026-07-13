import 'package:oidc_core/oidc_core.dart';

/// An event raised when a UserInfo request (OpenID Connect Core §5.3) made
/// while re-validating an already-authenticated session is rejected by the
/// resource server with an HTTP `401 Unauthorized`.
///
/// ## Why this is a sibling of [OidcTokenRefreshFailedEvent], not an extension
///
/// A refresh failure (RFC 6749 §5.2/§6) and a UserInfo `401` are two distinct
/// protocol surfaces, and conflating them would blur the taxonomy:
///
/// * A refresh failure originates at the **token endpoint** and carries its
///   OAuth error in a **JSON body** (`{"error":"invalid_grant", ...}`).
/// * A UserInfo `401` originates at a **protected resource** and carries its
///   OAuth error in the **`WWW-Authenticate` response header** per RFC 6750 §3
///   (`Bearer error="invalid_token"`), optionally with the RFC 9470 step-up
///   hints (`error="insufficient_user_authentication"`, `acr_values`,
///   `max_age`).
///
/// Modelling this as a first-class sibling under [OidcEvent] keeps each event's
/// fields honest to its own wire format while mirroring the [OidcEvent]
/// conventions established by [OidcTokenRefreshFailedEvent]
/// (`httpStatusCode` / `oauthErrorCode` / `errorDescription`, plus a typed
/// [challenge]).
///
/// ## Why this rides [OidcUserManagerBase.events], not
/// [OidcUserManagerBase.userChanges]
///
/// Same rationale as [OidcTokenRefreshFailedEvent]: `userChanges()` is a value
/// stream of the current [OidcUser] (or `null`); pushing a failure through it
/// would break existing `onData`-only listeners. Failures are surfaced as
/// first-class events on `events()` instead, leaving the value stream clean.
///
/// ## What the manager does before emitting this
///
/// When the failing UserInfo request happens while resuming/validating a live
/// session and a refresh token is available, the manager first attempts **one**
/// refresh-token grant (reusing the same machinery that powers
/// [OidcTokenRefreshFailedEvent]) and retries UserInfo once — a revoked access
/// token paired with a still-valid refresh token is recoverable without
/// re-authentication. This event is emitted only when that recovery is not
/// possible or does not succeed; on a successful recovery no failure event is
/// emitted. When the recovery refresh itself fails, an
/// [OidcTokenRefreshFailedEvent] is also emitted (by the refresh path).
///
/// The manager deliberately does **not** call `forgetUser` in reaction to this
/// event (mirroring the terminal-retention default for refresh failures): the
/// cached session is retained and the decision — sign the user out, launch an
/// RFC 9470 step-up, or ignore a transient blip — is left to the application.
///
/// ### Recommended application recipe
///
/// ```dart
/// manager.events().whereType<OidcUserInfoFailedEvent>().listen((event) {
///   if (event.isStepUpChallenge) {
///     // RFC 9470: re-authenticate at the challenged acr / max_age.
///     manager.loginAuthorizationCodeFlow(
///       extraParameters: {
///         if (event.challenge?.acrValues case final acrs?)
///           'acr_values': acrs.join(' '),
///         if (event.challenge?.maxAge case final maxAge?)
///           'max_age': '${maxAge.inSeconds}',
///       },
///     );
///   } else {
///     // The access token was rejected and could not be recovered.
///     manager.forgetUser();
///   }
/// });
/// ```
class OidcUserInfoFailedEvent extends OidcEvent {
  ///
  const OidcUserInfoFailedEvent({
    required this.error,
    required super.at,
    this.stackTrace,
    this.httpStatusCode,
    this.oauthErrorCode,
    this.errorDescription,
    this.challenge,
    super.additionalInfo,
  });

  ///
  OidcUserInfoFailedEvent.now({
    required this.error,
    this.stackTrace,
    this.httpStatusCode,
    this.oauthErrorCode,
    this.errorDescription,
    this.challenge,
    super.additionalInfo,
  }) : super.now();

  /// Builds an event from a caught [error], extracting the HTTP status from an
  /// [OidcException]'s raw response and parsing its `WWW-Authenticate` header
  /// (RFC 6750 §3 / RFC 9470) into a typed [OidcStepUpChallenge].
  factory OidcUserInfoFailedEvent.fromError({
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  }) {
    int? httpStatusCode;
    OidcStepUpChallenge? challenge;
    if (error is OidcException) {
      final rawResponse = error.rawResponse;
      httpStatusCode = rawResponse?.statusCode;
      challenge = OidcStepUpChallenge.parse(
        rawResponse?.headers[_wwwAuthenticateHeaderKey],
      );
    }
    return OidcUserInfoFailedEvent.now(
      error: error,
      stackTrace: stackTrace,
      httpStatusCode: httpStatusCode,
      // For a protected-resource 401 the OAuth error lives in the
      // `WWW-Authenticate` header (RFC 6750 §3), not a JSON body.
      oauthErrorCode: challenge?.error,
      errorDescription: challenge?.errorDescription,
      challenge: challenge,
      additionalInfo: additionalInfo,
    );
  }

  /// The response header key that carries the RFC 6750 §3 bearer-token
  /// challenge. `package:http` lowercases all response header keys, so the
  /// lookup MUST use the lowercase form.
  static const _wwwAuthenticateHeaderKey = 'www-authenticate';

  /// The raw error that caused the UserInfo request to fail.
  final Object error;

  /// The stack trace captured with [error], if available.
  final StackTrace? stackTrace;

  /// The HTTP status code of the UserInfo response, when available (typically
  /// `401`).
  final int? httpStatusCode;

  /// The RFC 6750 §3 `error` code parsed from the `WWW-Authenticate` header
  /// (e.g. `invalid_token`, `insufficient_scope`, or the RFC 9470
  /// `insufficient_user_authentication`), when present.
  final String? oauthErrorCode;

  /// The RFC 6750 §3 `error_description` parsed from the `WWW-Authenticate`
  /// header, when the resource server provided one.
  final String? errorDescription;

  /// The parsed `WWW-Authenticate` challenge (RFC 6750 §3), including any
  /// RFC 9470 step-up hints (`acr_values` / `max_age`), when the response
  /// carried one.
  final OidcStepUpChallenge? challenge;

  /// Whether the resource server asked for RFC 9470 step-up authentication
  /// (`error="insufficient_user_authentication"`).
  bool get isStepUpChallenge =>
      challenge?.isInsufficientUserAuthentication ?? false;
}
