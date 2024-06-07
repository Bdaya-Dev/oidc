import 'package:oidc_core/oidc_core.dart';
import 'event.dart';

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
