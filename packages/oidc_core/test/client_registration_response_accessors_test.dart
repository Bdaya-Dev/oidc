import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcClientRegistrationResponse typed accessors', () {
    test('reads every registered member from a full RFC 7591 response', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'abc123',
        'client_secret': 's3cr3t',
        'registration_access_token': 'reg-token',
        'registration_client_uri': 'https://op.example.com/register/abc123',
        // 2023-01-01T00:00:00Z in seconds since epoch.
        'client_id_issued_at': 1672531200,
        'client_secret_expires_at': 1704067200,
        'redirect_uris': [
          'https://app.example.com/cb',
          'com.example.app:/cb',
        ],
        'grant_types': ['authorization_code', 'refresh_token'],
        'response_types': ['code'],
        'token_endpoint_auth_method': 'client_secret_basic',
        'scope': 'openid profile',
        'client_name': 'My App',
      });

      expect(resp.clientId, 'abc123');
      expect(resp.clientSecret, 's3cr3t');
      expect(resp.registrationAccessToken, 'reg-token');
      expect(
        resp.registrationClientUri,
        Uri.parse('https://op.example.com/register/abc123'),
      );
      expect(
        resp.clientIdIssuedAt,
        DateTime.utc(2023),
      );
      expect(
        resp.clientSecretExpiresAt,
        DateTime.utc(2024),
      );
      expect(resp.clientSecretNeverExpires, isFalse);
      expect(resp.redirectUris, [
        Uri.parse('https://app.example.com/cb'),
        Uri.parse('com.example.app:/cb'),
      ]);
      expect(resp.grantTypes, ['authorization_code', 'refresh_token']);
      expect(resp.responseTypes, ['code']);
      expect(resp.tokenEndpointAuthMethod, 'client_secret_basic');
      expect(resp.scope, 'openid profile');
      expect(resp.clientName, 'My App');
    });

    test('absent optional members surface as null', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'only-id',
      });
      expect(resp.clientId, 'only-id');
      expect(resp.clientSecret, isNull);
      expect(resp.registrationAccessToken, isNull);
      expect(resp.registrationClientUri, isNull);
      expect(resp.clientIdIssuedAt, isNull);
      expect(resp.clientSecretExpiresAt, isNull);
      expect(resp.clientSecretNeverExpires, isFalse);
      expect(resp.redirectUris, isNull);
      expect(resp.grantTypes, isNull);
      expect(resp.responseTypes, isNull);
      expect(resp.tokenEndpointAuthMethod, isNull);
      expect(resp.scope, isNull);
      expect(resp.clientName, isNull);
    });

    test(
      'client_secret_expires_at == 0 means the secret never expires '
      '(RFC 7591 §3.2.1)',
      () {
        final resp = OidcClientRegistrationResponse.fromJson({
          'client_id': 'abc',
          'client_secret': 'shh',
          'client_secret_expires_at': 0,
        });
        expect(resp.clientSecretNeverExpires, isTrue);
        // 0 is still a valid numeric date (the epoch).
        expect(
          resp.clientSecretExpiresAt,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      },
    );

    test('registration_client_uri that is non-string is ignored', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'abc',
        'registration_client_uri': 12345,
      });
      expect(resp.registrationClientUri, isNull);
    });

    test('redirect_uris that is not a list surfaces as null', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'abc',
        'redirect_uris': 'not-a-list',
      });
      expect(resp.redirectUris, isNull);
    });

    test('numeric dates accept fractional seconds', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'abc',
        'client_id_issued_at': 1.5,
      });
      expect(
        resp.clientIdIssuedAt,
        DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true),
      );
    });
  });
}
