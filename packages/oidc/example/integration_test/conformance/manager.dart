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
}) =>
    OidcUserManager.lazy(
      discoveryDocumentUri:
          OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(issuer)),
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
          macos: OidcPlatformSpecificOptions_AppAuth_IosMacos(
            // using ephemeral session prevents annoying popups from blocking test
            externalUserAgent:
                OidcAppAuthExternalUserAgent.ephemeralAsWebAuthenticationSession,

          ),
          ios: OidcPlatformSpecificOptions_AppAuth_IosMacos(
            externalUserAgent:
                OidcAppAuthExternalUserAgent.ephemeralAsWebAuthenticationSession,
          ),
          
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
