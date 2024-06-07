// ignore_for_file: avoid_print, omit_local_variable_types

import 'package:oidc_core/oidc_core.dart';

// Check this file to see how the user manager is implemented
import 'cli_user_manager.dart';

// This example shows how to use the authorization code flow using
// https://demo.duendesoftware.com idp from the cli.
// you can login with google, or with bob/bob, or with alice/alice.

final idp = Uri.parse('https://demo.duendesoftware.com/');
const String clientId = 'interactive.public';
final store = OidcMemoryStore();

void main() async {
  final manager = CliUserManager.lazy(
    discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(idp),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: clientId,
    ),
    store: store,
    settings: OidcUserManagerSettings(
      //get any available port
      redirectUri: Uri.parse('http://127.0.0.1:0'),
      postLogoutRedirectUri: Uri.parse('http://127.0.0.1:0'),
    ),
  );

  print('Initializing the CLI user manager ...');
  await manager.init();
  print('User manager initialized !');

  final OidcUser? user =
      manager.currentUser ?? await manager.loginAuthorizationCodeFlow();
  if (user == null) {
    print('failed to get the user.');
  } else {
    print('user validated!\n'
        'subject: ${user.claims.subject}\n'
        'claims: ${user.aggregatedClaims}\n'
        'userInfo: ${user.userInfo}');

    print('Logging out the user again:');

    await manager.logout();

    print('user logged out.');
  }
}
