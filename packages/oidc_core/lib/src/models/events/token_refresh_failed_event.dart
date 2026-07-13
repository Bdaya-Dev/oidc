import 'package:oidc_core/oidc_core.dart';

/// Identifies which code path attempted the refresh that failed.
enum OidcTokenRefreshSource {
  /// The automatic refresh-on-expiry path (the `expiring` timer fired and the
  /// manager tried to exchange the refresh token in the background).
  autoExpiry,

  /// An explicit, caller-initiated `refreshToken()` call.
  manual,

  /// The refresh attempted while rehydrating a cached user during
  /// initialization (a persisted token was loaded and needed refreshing).
  startupLoad,
}

/// Classifies a refresh failure as recoverable or not, per RFC 6749 §5.2.
///
/// The classification reuses the same categorization that drives offline-mode
/// handling (see [OidcOfflineAuthErrorHandler.categorizeError]); it is surfaced
/// here so observers can react without re-implementing the mapping.
enum OidcTokenRefreshFailureKind {
  /// The failure is potentially recoverable: the liveness of the refresh token
  /// is unknown (network unreachable, timeout, TLS error, or a 5xx / temporary
  /// server error). The cached session should be kept and the refresh retried.
  transient,

  /// The failure is definitive: the authorization server rejected the grant
  /// (e.g. `invalid_grant` per RFC 6749 §5.2 — the refresh token was revoked,
  /// expired, or already rotated) or otherwise returned a non-recoverable
  /// client error. Retrying with the same refresh token cannot succeed;
  /// re-authentication is required.
  terminal,
}

/// An event raised whenever an OAuth 2.0 refresh-token grant (RFC 6749 §6)
/// fails, from any of the three refresh paths (see [OidcTokenRefreshSource]).
///
/// ## Why this rides [OidcUserManagerBase.events], not
/// [OidcUserManagerBase.userChanges]
///
/// `userChanges()` is backed by an `OidcValueStream`, which carries *values*
/// (the current [OidcUser] or `null`). Pushing an error through it would either
/// break existing `listen(onData)` consumers (they never registered an
/// `onError`) or force every listener to handle errors. Failures are therefore
/// surfaced as first-class events on `events()`, alongside the other
/// observability events, leaving the value stream clean.
///
/// ## Terminal vs. transient (RFC 6749 §5.2)
///
/// * `invalid_grant` means the refresh token is dead — revoked, expired, or
///   already rotated — so re-authentication is required. This is reported as
///   [OidcTokenRefreshFailureKind.terminal].
/// * A network error or a 5xx response leaves the refresh token's liveness
///   unknown, so the failure is [OidcTokenRefreshFailureKind.transient] and the
///   cached session is retained (retried when offline support is enabled).
///
/// ## Double-signal for the manual path
///
/// For [OidcTokenRefreshSource.manual] this event is emitted *in addition to*
/// the [OidcException] that `refreshToken()` still throws (the throw is
/// preserved unchanged). This mirrors the MSAL pattern: the awaiting caller
/// gets the exception, while background observers of `events()` get the event.
class OidcTokenRefreshFailedEvent extends OidcEvent {
  ///
  const OidcTokenRefreshFailedEvent({
    required this.error,
    required this.source,
    required this.kind,
    required this.willRetry,
    required super.at,
    this.stackTrace,
    this.oauthErrorCode,
    this.httpStatusCode,
    this.errorDescription,
    super.additionalInfo,
  });

  ///
  OidcTokenRefreshFailedEvent.now({
    required this.error,
    required this.source,
    required this.kind,
    required this.willRetry,
    this.stackTrace,
    this.oauthErrorCode,
    this.httpStatusCode,
    this.errorDescription,
    super.additionalInfo,
  }) : super.now();

  /// Builds an event from a caught [error], deriving [kind] from the shared
  /// error categorization and extracting the RFC 6749 §5.2 error fields
  /// (`error`, `error_description`) and HTTP status from an [OidcException]
  /// when present.
  factory OidcTokenRefreshFailedEvent.fromError({
    required Object error,
    required OidcTokenRefreshSource source,
    required bool willRetry,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  }) {
    String? oauthErrorCode;
    String? errorDescription;
    int? httpStatusCode;
    if (error is OidcException) {
      final errorResponse = error.errorResponse;
      if (errorResponse != null) {
        oauthErrorCode = errorResponse.error;
        errorDescription = errorResponse.errorDescription;
      }
      httpStatusCode = error.rawResponse?.statusCode;
    }

    final errorType = OidcOfflineAuthErrorHandler.categorizeError(error);
    final kind = switch (errorType) {
      OfflineAuthErrorType.authenticationError ||
      OfflineAuthErrorType.clientError => OidcTokenRefreshFailureKind.terminal,
      OfflineAuthErrorType.networkUnavailable ||
      OfflineAuthErrorType.networkTimeout ||
      OfflineAuthErrorType.serverError ||
      OfflineAuthErrorType.sslError ||
      OfflineAuthErrorType.unknown => OidcTokenRefreshFailureKind.transient,
    };

    return OidcTokenRefreshFailedEvent.now(
      error: error,
      source: source,
      kind: kind,
      willRetry: willRetry,
      stackTrace: stackTrace,
      oauthErrorCode: oauthErrorCode,
      errorDescription: errorDescription,
      httpStatusCode: httpStatusCode,
      additionalInfo: additionalInfo,
    );
  }

  /// The raw error that caused the refresh to fail.
  final Object error;

  /// The stack trace captured with [error], if available.
  final StackTrace? stackTrace;

  /// Which refresh path failed.
  final OidcTokenRefreshSource source;

  /// Whether the failure is [OidcTokenRefreshFailureKind.terminal] (the refresh
  /// token is dead — re-authentication required) or
  /// [OidcTokenRefreshFailureKind.transient] (recoverable — session kept).
  final OidcTokenRefreshFailureKind kind;

  /// Whether the offline machinery scheduled an automatic retry for this
  /// failure. `false` when offline support is disabled, when the failure is
  /// terminal, or on paths that do not schedule retries (manual / startup).
  final bool willRetry;

  /// The RFC 6749 §5.2 `error` code parsed from the token-endpoint response
  /// (e.g. `invalid_grant`), when the failure was an [OidcException] carrying a
  /// server error response. `null` for transport-level failures.
  final String? oauthErrorCode;

  /// The HTTP status code of the token-endpoint response, when available.
  final int? httpStatusCode;

  /// The RFC 6749 §5.2 `error_description`, when the server provided one.
  final String? errorDescription;
}
