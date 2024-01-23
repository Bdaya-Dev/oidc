import 'package:oidc_core/oidc_core.dart';

/// Represents an arbitrary event.
abstract class OidcEvent {
  ///
  const OidcEvent({
    required this.at,
  });

  /// Creates an event whose [at] is now.
  OidcEvent.now() : at = DateTime.now();

  /// when the event occurred.
  final DateTime at;
}

/// An event that gets raised before the user is forgotten.
class OidcPreLogoutEvent extends OidcEvent {
  /// The current user that will get logged out.
  final OidcUser currentUser;

  ///
  const OidcPreLogoutEvent({
    required this.currentUser,
    required super.at,
  });

  ///
  OidcPreLogoutEvent.now({
    required this.currentUser,
  }) : super.now();
}
