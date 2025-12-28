import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised when the user manager exits offline mode.
///
/// This occurs when network connectivity is restored and the app
/// can successfully communicate with the authentication server again.
class OidcOfflineModeExitedEvent extends OidcEvent {
  ///
  const OidcOfflineModeExitedEvent({
    required this.networkRestored,
    required super.at,
    this.newToken,
    this.lastSuccessfulServerContact,
    super.additionalInfo,
  });

  ///
  OidcOfflineModeExitedEvent.now({
    required this.networkRestored,
    this.newToken,
    this.lastSuccessfulServerContact,
    super.additionalInfo,
  }) : super.now();

  /// Whether network connectivity was restored.
  final bool networkRestored;

  /// The new token obtained after exiting offline mode (if token was refreshed).
  final OidcToken? newToken;

  /// The timestamp when server contact was re-established.
  /// This should be the current time when exiting offline mode.
  final DateTime? lastSuccessfulServerContact;
}
