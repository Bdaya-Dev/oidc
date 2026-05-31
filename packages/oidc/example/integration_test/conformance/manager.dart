import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

// Future<Map<String, dynamic>> prepareConformanceTest(String token) async {}
OidcUserManager conformanceManager(
  String issuer, {
  required String clientId,
  required String clientSecret,
  required Uri redirectUri,
  Uri? postLogoutRedirectUri,
  Uri? frontChannelLogoutUri,
}) => OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse(issuer),
  ),
  clientCredentials: OidcClientAuthentication.clientSecretBasic(
    clientId: clientId,
    clientSecret: clientSecret,
  ),
  store: OidcDefaultStore(),
  settings: OidcUserManagerSettings(
    redirectUri: redirectUri,
    postLogoutRedirectUri: postLogoutRedirectUri,
    frontChannelLogoutUri: frontChannelLogoutUri,
    strictJwtVerification: true,
    options: const OidcPlatformSpecificOptions(
      // using ephemeral session prevents annoying popups from blocking test
      macos: OidcNativeOptionsApple(prefersEphemeralWebBrowserSession: true),
      ios: OidcNativeOptionsApple(prefersEphemeralWebBrowserSession: true),
      // On headless CI emulators Custom Tabs opens but no user can interact,
      // so the redirect never arrives and loginAuthorizationCodeFlow hangs.
      // A 30 s timeout lets the module fail-fast (caught by the try/catch in
      // shared_e2e) so the rest of the conformance suite still runs.
      android: OidcNativeOptionsAndroid(flowTimeoutSeconds: 30),
    ),
    scope: const [
      OidcConstants_Scopes.openid,
      OidcConstants_Scopes.profile,
      OidcConstants_Scopes.email,
      OidcConstants_Scopes.address,
      OidcConstants_Scopes.phone,
    ],
  ),
);
