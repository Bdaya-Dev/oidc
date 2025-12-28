import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised to warn about security implications
/// of offline authentication.
///
/// This event is emitted when using cached expired tokens or
/// when offline mode has been active for an extended period.
class OidcOfflineAuthWarningEvent extends OidcEvent {
  ///
  const OidcOfflineAuthWarningEvent({
    required this.warningType,
    required this.message,
    required super.at,
    super.additionalInfo,
    this.tokenExpiredSince,
  });

  ///
  OidcOfflineAuthWarningEvent.now({
    required this.warningType,
    required this.message,
    this.tokenExpiredSince,
    super.additionalInfo,
  }) : super.now();

  /// The type of warning being issued.
  final OfflineAuthWarningType warningType;

  /// A human-readable warning message.
  final String message;

  /// Duration since the token expired (if applicable).
  final Duration? tokenExpiredSince;
}

/// Types of offline authentication warnings.
enum OfflineAuthWarningType {
  /// Using an expired token in offline mode.
  usingExpiredToken,

  /// Offline mode has been active for an extended period.
  extendedOfflineDuration,

  /// Unable to validate token with server.
  tokenValidationSkipped,

  /// UserInfo data may be stale.
  staleUserInfo,

  /// Token refresh has failed multiple times.
  repeatRefreshFailure,
}
