@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Dynamic Client Registration (RFC 7591/7592)', () {
    test('registerClient POSTs JSON metadata and parses the response', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'client_id': 'generated-id',
            'client_secret': 'generated-secret',
            'client_secret_expires_at': 0,
            'registration_access_token': 'rat-1',
            'registration_client_uri':
                'https://op.example.com/register/generated-id',
            'redirect_uris': ['com.example.app://cb'],
            'grant_types': ['authorization_code'],
            'token_endpoint_auth_method': 'none',
          }),
          201,
          headers: const {'content-type': 'application/json'},
        );
      });

      final resp = await OidcEndpoints.registerClient(
        registrationEndpoint: Uri.parse('https://op.example.com/register'),
        initialAccessToken: 'init-token',
        request: OidcClientRegistrationRequest(
          redirectUris: [Uri.parse('com.example.app://cb')],
          grantTypes: const ['authorization_code'],
          responseTypes: const ['code'],
          clientName: 'Example App',
          applicationType: 'native',
          tokenEndpointAuthMethod: 'none',
          scope: const ['openid', 'profile'],
        ),
        client: client,
      );

      // Request: JSON body + Bearer initial access token.
      expect(captured!.method, 'POST');
      expect(captured!.headers['content-type'], contains('application/json'));
      expect(captured!.headers['authorization'], 'Bearer init-token');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['redirect_uris'], ['com.example.app://cb']);
      expect(body['client_name'], 'Example App');
      expect(body['scope'], 'openid profile'); // space-joined
      expect(body['grant_types'], ['authorization_code']);

      // Response parsing.
      expect(resp.clientId, 'generated-id');
      expect(resp.clientSecret, 'generated-secret');
      expect(resp.clientSecretNeverExpires, isTrue);
      expect(resp.registrationAccessToken, 'rat-1');
      expect(
        resp.registrationClientUri,
        Uri.parse('https://op.example.com/register/generated-id'),
      );
      expect(resp.redirectUris, [Uri.parse('com.example.app://cb')]);
      expect(resp.tokenEndpointAuthMethod, 'none');
    });

    test('readClientConfiguration GETs with the registration access token '
        '(RFC 7592)', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'client_id': 'generated-id', 'client_name': 'Example App'}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final resp = await OidcEndpoints.readClientConfiguration(
        registrationClientUri: Uri.parse(
          'https://op.example.com/register/generated-id',
        ),
        registrationAccessToken: 'rat-1',
        client: client,
      );
      expect(captured!.method, 'GET');
      expect(captured!.headers['authorization'], 'Bearer rat-1');
      expect(resp.clientId, 'generated-id');
      expect(resp.clientName, 'Example App');
    });

    test('deleteClientConfiguration DELETEs and succeeds on 204', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      await OidcEndpoints.deleteClientConfiguration(
        registrationClientUri: Uri.parse(
          'https://op.example.com/register/generated-id',
        ),
        registrationAccessToken: 'rat-1',
        client: client,
      );
      expect(captured!.method, 'DELETE');
      expect(captured!.headers['authorization'], 'Bearer rat-1');
    });
  });
}
