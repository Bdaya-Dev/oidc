@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Dynamic Client Registration (RFC 7591/7592)', () {
    test(
      'registerClient POSTs JSON metadata and parses the response',
      () async {
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
      },
    );

    test('readClientConfiguration GETs with the registration access token '
        '(RFC 7592)', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'client_id': 'generated-id',
            'client_name': 'Example App',
          }),
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

    test(
      'deleteClientConfiguration accepts 200 leniently as success',
      () async {
        final client = MockClient((req) async {
          return http.Response('', 200);
        });
        await OidcEndpoints.deleteClientConfiguration(
          registrationClientUri: Uri.parse(
            'https://op.example.com/register/generated-id',
          ),
          registrationAccessToken: 'rat-1',
          client: client,
        );
      },
    );

    test(
      'deleteClientConfiguration throws on a 302 redirect '
      '(not a defined success status per RFC 7592 2.3)',
      () async {
        final client = MockClient((req) async {
          return http.Response(
            '',
            302,
            headers: const {'location': 'https://op.example.com/login'},
          );
        });
        await expectLater(
          OidcEndpoints.deleteClientConfiguration(
            registrationClientUri: Uri.parse(
              'https://op.example.com/register/generated-id',
            ),
            registrationAccessToken: 'rat-1',
            client: client,
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test(
      'deleteClientConfiguration surfaces a 401 RFC 6749-shaped error body '
      'as a typed OidcException',
      () async {
        final client = MockClient((req) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_token',
              'error_description': 'The access token expired',
            }),
            401,
            headers: const {'content-type': 'application/json'},
          );
        });
        try {
          await OidcEndpoints.deleteClientConfiguration(
            registrationClientUri: Uri.parse(
              'https://op.example.com/register/generated-id',
            ),
            registrationAccessToken: 'rat-1',
            client: client,
          );
          fail('should have thrown');
        } on OidcException catch (e) {
          expect(e.errorResponse, isNotNull);
          expect(e.errorResponse!.error, 'invalid_token');
          expect(
            e.errorResponse!.errorDescription,
            'The access token expired',
          );
          expect(e.rawResponse?.statusCode, 401);
        }
      },
    );

    test(
      'deleteClientConfiguration surfaces a 405 error body as a typed '
      'OidcException',
      () async {
        final client = MockClient((req) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_request',
              'error_description': 'DELETE is not supported',
            }),
            405,
            headers: const {'content-type': 'application/json'},
          );
        });
        try {
          await OidcEndpoints.deleteClientConfiguration(
            registrationClientUri: Uri.parse(
              'https://op.example.com/register/generated-id',
            ),
            registrationAccessToken: 'rat-1',
            client: client,
          );
          fail('should have thrown');
        } on OidcException catch (e) {
          expect(e.errorResponse, isNotNull);
          expect(e.errorResponse!.error, 'invalid_request');
          expect(
            e.errorResponse!.errorDescription,
            'DELETE is not supported',
          );
          expect(e.rawResponse?.statusCode, 405);
        }
      },
    );
  });

  group('OidcClientRegistrationRequest OIDC-Reg-1.0 typed metadata', () {
    test('serializes the OpenID Connect DCR §2 fields with correct types', () {
      final body = OidcClientRegistrationRequest(
        defaultMaxAge: const Duration(seconds: 3600),
        requireAuthTime: true,
        defaultAcrValues: const ['urn:mace:incommon:iap:silver', 'phr'],
        initiateLoginUri: Uri.parse('https://app.example.com/initiate'),
        requestUris: [
          Uri.parse('https://app.example.com/request/1'),
          Uri.parse('https://app.example.com/request/2'),
        ],
      ).toMap();

      // default_max_age is a Number of seconds.
      expect(body['default_max_age'], 3600);
      // require_auth_time is a Boolean.
      expect(body['require_auth_time'], true);
      // default_acr_values is a JSON array of strings (NOT space-joined).
      expect(body['default_acr_values'], [
        'urn:mace:incommon:iap:silver',
        'phr',
      ]);
      // initiate_login_uri is a URI string.
      expect(body['initiate_login_uri'], 'https://app.example.com/initiate');
      // request_uris is a JSON array of URI strings.
      expect(body['request_uris'], [
        'https://app.example.com/request/1',
        'https://app.example.com/request/2',
      ]);
    });

    test('omits the typed metadata fields entirely when unset', () {
      final body = OidcClientRegistrationRequest(clientName: 'x').toMap();
      expect(body.containsKey('default_max_age'), isFalse);
      expect(body.containsKey('require_auth_time'), isFalse);
      expect(body.containsKey('default_acr_values'), isFalse);
      expect(body.containsKey('initiate_login_uri'), isFalse);
      expect(body.containsKey('request_uris'), isFalse);
    });
  });

  group('OidcClientRegistrationResponse.toUpdateRequest (RFC 7592 §2.2)', () {
    test('echoes full metadata and drops server-managed fields', () {
      final resp = OidcClientRegistrationResponse.fromJson({
        'client_id': 'generated-id',
        'client_secret': 's3cr3t',
        'client_id_issued_at': 1672531200,
        'client_secret_expires_at': 0,
        'registration_access_token': 'rat-1',
        'registration_client_uri':
            'https://op.example.com/register/generated-id',
        'redirect_uris': ['com.example.app://cb'],
        'grant_types': ['authorization_code'],
        'token_endpoint_auth_method': 'client_secret_basic',
        'client_name': 'Example App',
        'scope': 'openid profile',
      });

      final body = resp.toUpdateRequest().toMap();

      // client_id (required) and client_secret (must match) are retained.
      expect(body['client_id'], 'generated-id');
      expect(body['client_secret'], 's3cr3t');
      // Full metadata is echoed back.
      expect(body['redirect_uris'], ['com.example.app://cb']);
      expect(body['grant_types'], ['authorization_code']);
      expect(body['token_endpoint_auth_method'], 'client_secret_basic');
      expect(body['client_name'], 'Example App');
      expect(body['scope'], 'openid profile');
      // Server-managed fields MUST NOT be sent back.
      expect(body.containsKey('registration_access_token'), isFalse);
      expect(body.containsKey('registration_client_uri'), isFalse);
      expect(body.containsKey('client_id_issued_at'), isFalse);
      expect(body.containsKey('client_secret_expires_at'), isFalse);
    });

    test('rotation: a new secret/registration token in the update response '
        'supersedes the old one', () {
      // Simulate the PUT response rotating both credentials.
      final updated = OidcClientRegistrationResponse.fromJson({
        'client_id': 'generated-id',
        'client_secret': 'rotated-secret',
        'registration_access_token': 'rotated-rat',
        'client_name': 'Example App v2',
      });
      expect(updated.clientSecret, 'rotated-secret');
      expect(updated.registrationAccessToken, 'rotated-rat');
    });
  });
}
