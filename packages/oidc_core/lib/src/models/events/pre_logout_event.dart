import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised before the user is forgotten.
class OidcPreLogoutEvent extends OidcEvent {
  ///
  const OidcPreLogoutEvent({
    required this.currentUser,
    required super.at,
  });

  ///
  OidcPreLogoutEvent.now({
    required this.currentUser,
  }) : super.now();

  /// The current user that will get logged out.
  final OidcUser currentUser;
}
