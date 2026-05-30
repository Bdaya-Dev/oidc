@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Resource Indicators (RFC 8707)', () {
    test('authorize request emits one repeated `resource` query param per '
        'value', () {
      final req = OidcAuthorizeRequest(
        responseType: const ['code'],
        clientId: 'client-1',
        redirectUri: Uri.parse('com.example.app://cb'),
        scope: const ['openid'],
        resource: [
          Uri.parse('https://api.example.com'),
          Uri.parse('https://files.example.com'),
        ],
      );
      final uri = req.generateUri(
        Uri.parse('https://op.example.com/authorize'),
      );
      expect(uri.queryParametersAll[OidcConstants_AuthParameters.resource], [
        'https://api.example.com',
        'https://files.example.com',
      ]);
    });

    test('token request body carries repeated `resource` params', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          '{"access_token":"at"}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      await OidcEndpoints.token(
        tokenEndpoint: Uri.parse('https://op.example.com/token'),
        credentials: const OidcClientAuthentication.none(clientId: 'client-1'),
        request: OidcTokenRequest.authorizationCode(
          code: 'auth-code',
          clientId: 'client-1',
          resource: [
            Uri.parse('https://api.example.com'),
            Uri.parse('https://files.example.com'),
          ],
        ),
        client: client,
      );
      final resources = captured!.body
          .split('&')
          .where((p) => p.startsWith('resource='))
          .toList();
      expect(resources, hasLength(2), reason: 'repeated, not space-joined');
      expect(
        captured!.body,
        contains('resource=https%3A%2F%2Fapi.example.com'),
      );
      // A scalar param in the same body is still encoded correctly.
      expect(captured!.body, contains('grant_type=authorization_code'));
    });
  });

  group('Token Exchange (RFC 8693)', () {
    test('.tokenExchange() builds the correct grant + fields', () {
      final req = OidcTokenRequest.tokenExchange(
        subjectToken: 'subj',
        subjectTokenType: 'urn:ietf:params:oauth:token-type:access_token',
        audience: 'https://api.example.com',
      );
      final map = req.toMap();
      expect(
        map[OidcConstants_AuthParameters.grantType],
        OidcConstants_GrantType.tokenExchange,
      );
      expect(map[OidcConstants_AuthParameters.subjectToken], 'subj');
      expect(
        map[OidcConstants_AuthParameters.subjectTokenType],
        'urn:ietf:params:oauth:token-type:access_token',
      );
      expect(map[OidcConstants_AuthParameters.audience], 'https://api.example.com');
    });

    test('token-exchange request reaches the token endpoint', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          '{"access_token":"at","token_type":"Bearer"}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final resp = await OidcEndpoints.token(
        tokenEndpoint: Uri.parse('https://op.example.com/token'),
        credentials: const OidcClientAuthentication.none(clientId: 'client-1'),
        request: OidcTokenRequest.tokenExchange(
          subjectToken: 'subj',
          subjectTokenType: 'urn:ietf:params:oauth:token-type:access_token',
        ),
        client: client,
      );
      expect(resp.accessToken, 'at');
      final body = Uri.splitQueryString(captured!.body);
      expect(
        body[OidcConstants_AuthParameters.grantType],
        OidcConstants_GrantType.tokenExchange,
      );
      expect(body[OidcConstants_AuthParameters.subjectToken], 'subj');
    });
  });
}
