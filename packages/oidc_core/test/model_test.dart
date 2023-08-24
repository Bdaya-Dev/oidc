import 'dart:convert';

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Models', () {
    setUp(() {});

    test('OidcProviderMetadata', () {
      // From https://accounts.google.com/.well-known/openid-configuration
      final src =
          '''{
            "issuer": "https://accounts.google.com",
            "authorization_endpoint": "https://accounts.google.com/o/oauth2/v2/auth",
            "device_authorization_endpoint": "https://oauth2.googleapis.com/device/code",
            "token_endpoint": "https://oauth2.googleapis.com/token",
            "userinfo_endpoint": "https://openidconnect.googleapis.com/v1/userinfo",
            "revocation_endpoint": "https://oauth2.googleapis.com/revoke",
            "jwks_uri": "https://www.googleapis.com/oauth2/v3/certs",
            "response_types_supported": [
              "code",
              "token",
              "id_token",
              "code token",
              "code id_token",
              "token id_token",
              "code token id_token",
              "none"
            ],
            "subject_types_supported": [
              "public"
            ],
            "id_token_signing_alg_values_supported": [
              "RS256"
            ],
            "scopes_supported": [
              "openid",
              "email",
              "profile"
            ],
            "token_endpoint_auth_methods_supported": [
              "client_secret_post",
              "client_secret_basic"
            ],
            "claims_supported": [
              "aud",
              "email",
              "email_verified",
              "exp",
              "family_name",
              "given_name",
              "iat",
              "iss",
              "locale",
              "name",
              "picture",
              "sub"
            ],
            "code_challenge_methods_supported": [
              "plain",
              "S256"
            ],
            "grant_types_supported": [
              "authorization_code",
              "refresh_token",
              "urn:ietf:params:oauth:grant-type:device_code",
              "urn:ietf:params:oauth:grant-type:jwt-bearer"
            ]
            }
            ''';

      final decoded = jsonDecode(src);
      final parsed = OidcProviderMetadata.fromJson(decoded);
      expect(parsed.src, decoded);
      expect(parsed.issuer.toString(), 'https://accounts.google.com');
      expect(parsed.grantTypesSupported, [
        "authorization_code",
        "refresh_token",
        "urn:ietf:params:oauth:grant-type:device_code",
        "urn:ietf:params:oauth:grant-type:jwt-bearer"
      ]);
    });
  });
}
