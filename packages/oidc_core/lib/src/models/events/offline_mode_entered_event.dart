import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised when the user manager enters offline mode.
///
/// This occurs when the app cannot reach the authentication server but
/// [OidcUserManagerSettings.supportOfflineAuth] is enabled, allowing
/// the user to remain authenticated with cached tokens.
class OidcOfflineModeEnteredEvent extends OidcEvent {
  ///
  const OidcOfflineModeEnteredEvent({
    required this.reason,
    required super.at,
    this.currentToken,
    this.lastSuccessfulServerContact,
    this.error,
    super.additionalInfo,
  });

  ///
  OidcOfflineModeEnteredEvent.now({
    required this.reason,
    this.currentToken,
    this.lastSuccessfulServerContact,
    this.error,
    super.additionalInfo,
  }) : super.now();

  /// The reason for entering offline mode.
  final OfflineModeReason reason;

  /// The current token being used in offline mode (may be expired).
  final OidcToken? currentToken;

  /// The last time the manager successfully contacted the server.
  /// Useful for displaying "Last synced: X minutes ago" in the UI.
  final DateTime? lastSuccessfulServerContact;

  /// The error that caused entering offline mode, if applicable.
  final Object? error;
}

/// The reason why offline mode was entered.
enum OfflineModeReason {
  /// Network is completely unavailable (no internet connection).
  networkUnavailable,

  /// Server is unreachable or returning errors (5xx).
  serverUnavailable,

  /// Token refresh failed due to network/server issues.
  tokenRefreshFailed,

  /// Discovery document fetch failed.
  discoveryDocumentUnavailable,

  /// UserInfo endpoint unavailable.
  userInfoUnavailable,
}
