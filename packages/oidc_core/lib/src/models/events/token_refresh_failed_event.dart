import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised when the auto token refresh fails.
class OidcTokenRefreshFailedEvent extends OidcEvent {
  ///
  const OidcTokenRefreshFailedEvent({
    required this.error,
    required super.at,
  });

  ///
  OidcTokenRefreshFailedEvent.now({
    required this.error,
  }) : super.now();

  final Object error;
}
