// coverage:ignore-file
import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

class OidcException implements Exception {
  const OidcException(
    this.message, {
    this.extra = const {},
    this.internalException,
    this.internalStackTrace,
    this.rawRequest,
    this.rawResponse,
    this.kind,
  }) : errorResponse = null;

  const OidcException.serverError({
    required OidcErrorResponse this.errorResponse,
    this.extra = const {},
    this.rawRequest,
    this.rawResponse,
    String? message,
    this.kind,
  }) : message = message ?? 'Server sent an error response',
       internalException = null,
       internalStackTrace = null;

  /// Creates an exception with every field supplied explicitly.
  ///
  /// Unlike the default constructor (which forces `errorResponse` to null) and
  /// [OidcException.serverError] (which forces the internal error fields to
  /// null), this lets a caller carry BOTH an [errorResponse] and an
  /// [internalException]/[internalStackTrace] at once, which is what re-throwing
  /// an already-classified failure needs in order to preserve the original
  /// diagnostics. Used by [OidcInteractionRequiredException].
  const OidcException.raw({
    required this.message,
    this.extra = const {},
    this.errorResponse,
    this.internalException,
    this.internalStackTrace,
    this.rawRequest,
    this.rawResponse,
    this.kind,
  });

  final String message;
  final Map<String, dynamic> extra;
  final OidcErrorResponse? errorResponse;
  final Object? internalException;
  final StackTrace? internalStackTrace;
  final http.Request? rawRequest;
  final http.Response? rawResponse;

  /// The classification of this failure, when the library could derive one.
  ///
  /// Mirrors the classification already carried by
  /// [OidcTokenRefreshFailedEvent.kind] (derived from
  /// [OidcOfflineAuthErrorHandler.categorizeError]), so an awaiting caller can
  /// decide "re-authenticate now" vs. "retry later" WITHOUT string-comparing
  /// RFC 6749 §5.2 error codes:
  ///
  /// * [OidcTokenRefreshFailureKind.terminal] — the grant is dead
  ///   (`invalid_grant`, or a `prompt=none` attempt that came back
  ///   `login_required` / `interaction_required` / `consent_required`).
  ///   Re-authentication is required; such failures are thrown as
  ///   [OidcInteractionRequiredException].
  /// * [OidcTokenRefreshFailureKind.transient] — the liveness of the grant is
  ///   unknown (network / timeout / TLS / 5xx). Retrying can succeed.
  ///
  /// `null` on the many paths that raise an [OidcException] without any
  /// refresh-failure classification (validation errors, misconfiguration, …),
  /// which is every path that existed before this field was added.
  final OidcTokenRefreshFailureKind? kind;

  @override
  String toString() {
    final message = this.message;
    return 'OidcException: $message, '
        'extra: $extra, '
        'error: ${errorResponse?.error}';
  }
}

/// Thrown when the session cannot be renewed without user interaction.
///
/// This is the typed counterpart of MSAL.NET's `MsalUiRequiredException`: it
/// marks exactly the failures whose recommended handling is "start an
/// interactive login", so consumers never have to string-match OAuth error
/// codes:
///
/// ```dart
/// try {
///   final accessToken = await manager.getAccessToken();
///   // ... use it
/// } on OidcInteractionRequiredException {
///   await manager.loginAuthorizationCodeFlow();
/// }
/// ```
///
/// It is raised when:
///
/// * the refresh-token grant failed terminally — the refresh token was revoked,
///   expired, or already rotated (`invalid_grant`, RFC 6749 §5.2), or the
///   authorization server returned another non-recoverable client error;
/// * there is no refresh token at all to renew a stale access token with; or
/// * a `prompt=none` attempt (see [OidcUserManagerBase.signInSilent]) came back
///   with `login_required`, `interaction_required`, `consent_required` or
///   `account_selection_required` (OpenID Connect Core 1.0 §3.1.2.6).
///
/// Being a subclass, every existing `on OidcException` catch keeps matching it.
/// [kind] is always [OidcTokenRefreshFailureKind.terminal].
class OidcInteractionRequiredException extends OidcException {
  ///
  const OidcInteractionRequiredException({
    required super.message,
    super.extra,
    super.errorResponse,
    super.internalException,
    super.internalStackTrace,
    super.rawRequest,
    super.rawResponse,
  }) : super.raw(kind: OidcTokenRefreshFailureKind.terminal);

  /// Wraps an already-caught [error] while preserving its diagnostics.
  ///
  /// When [error] is an [OidcException], its `errorResponse`, `extra` and raw
  /// HTTP exchange are carried over and the ORIGINAL exception is kept as
  /// [internalException] so nothing is lost; otherwise [error] itself becomes
  /// [internalException].
  factory OidcInteractionRequiredException.from(
    Object error, {
    required String message,
    StackTrace? stackTrace,
  }) {
    if (error is OidcException) {
      return OidcInteractionRequiredException(
        message: message,
        extra: error.extra,
        errorResponse: error.errorResponse,
        internalException: error,
        internalStackTrace: stackTrace ?? error.internalStackTrace,
        rawRequest: error.rawRequest,
        rawResponse: error.rawResponse,
      );
    }
    return OidcInteractionRequiredException(
      message: message,
      internalException: error,
      internalStackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    final message = this.message;
    return 'OidcInteractionRequiredException: $message, '
        'extra: $extra, '
        'error: ${errorResponse?.error}';
  }
}
