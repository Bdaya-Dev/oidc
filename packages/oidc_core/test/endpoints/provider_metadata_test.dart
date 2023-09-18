import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Models', () {
    setUp(() {});
    group('OidcUtils.getWellKnownUriFromBase', () {
      test('keycloak', () {
        final base = Uri.parse('http://keycloakhost:5030/auth/realms/my-realm');

        final res = OidcUtils.getOpenIdConfigWellKnownUri(base);
        expect(
          res.toString(),
          'http://keycloakhost:5030/auth/realms/my-realm/.well-known/openid-configuration',
        );
      });
      test('google', () {
        //
        final base = Uri.parse('https://accounts.google.com/');
        final res = OidcUtils.getOpenIdConfigWellKnownUri(base);
        expect(
          res.toString(),
          'https://accounts.google.com/.well-known/openid-configuration',
        );
      });
    });

    group('OidcProviderMetadata', () {
      // From https://accounts.google.com/.well-known/openid-configuration
      test('Facebook', () {
        final src = {
          'issuer': 'https://www.facebook.com',
          'authorization_endpoint': 'https://facebook.com/dialog/oauth/',
          'jwks_uri': 'https://www.facebook.com/.well-known/oauth/openid/jwks/',
          'response_types_supported': ['id_token', 'token id_token'],
          'subject_types_supported': ['pairwise'],
          'id_token_signing_alg_values_supported': ['RS256'],
          'claims_supported': [
            'iss',
            'aud',
            'sub',
            'iat',
            'exp',
            'jti',
            'nonce',
            'at_hash',
            'name',
            'given_name',
            'middle_name',
            'family_name',
            'email',
            'picture',
            'user_friends',
            'user_birthday',
            'user_age_range',
            'user_link',
            'user_hometown',
            'user_location',
            'user_gender',
          ],
        };

        final parsed = OidcProviderMetadata.fromJson(src);
        expect(parsed.src, src);
        expect(parsed.issuer.toString(), 'https://www.facebook.com');
        expect(
          parsed.grantTypesSupportedOrDefault,
          const ['authorization_code', 'implicit'],
        );
      });
      test('Google', () {
        final src = {
          'issuer': 'https://accounts.google.com',
          'authorization_endpoint':
              'https://accounts.google.com/o/oauth2/v2/auth',
          'device_authorization_endpoint':
              'https://oauth2.googleapis.com/device/code',
          'token_endpoint': 'https://oauth2.googleapis.com/token',
          'userinfo_endpoint':
              'https://openidconnect.googleapis.com/v1/userinfo',
          'revocation_endpoint': 'https://oauth2.googleapis.com/revoke',
          'jwks_uri': 'https://www.googleapis.com/oauth2/v3/certs',
          'response_types_supported': [
            'code',
            'token',
            'id_token',
            'code token',
            'code id_token',
            'token id_token',
            'code token id_token',
            'none',
          ],
          'subject_types_supported': ['public'],
          'id_token_signing_alg_values_supported': ['RS256'],
          'scopes_supported': ['openid', 'email', 'profile'],
          'token_endpoint_auth_methods_supported': [
            'client_secret_post',
            'client_secret_basic',
          ],
          'claims_supported': [
            'aud',
            'email',
            'email_verified',
            'exp',
            'family_name',
            'given_name',
            'iat',
            'iss',
            'locale',
            'name',
            'picture',
            'sub',
          ],
          'code_challenge_methods_supported': ['plain', 'S256'],
          'grant_types_supported': [
            'authorization_code',
            'refresh_token',
            'urn:ietf:params:oauth:grant-type:device_code',
            'urn:ietf:params:oauth:grant-type:jwt-bearer',
          ],
        };

        final parsed = OidcProviderMetadata.fromJson(src);
        expect(parsed.src, src);
        expect(parsed.issuer.toString(), 'https://accounts.google.com');
        expect(parsed.grantTypesSupported, [
          'authorization_code',
          'refresh_token',
          'urn:ietf:params:oauth:grant-type:device_code',
          'urn:ietf:params:oauth:grant-type:jwt-bearer',
        ]);
      });
    });
  });
}
