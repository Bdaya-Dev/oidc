@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = Uri.parse('https://op.example.com/introspect');

  test('introspect posts token + hint with client auth and parses the '
      'response (RFC 7662)', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'active': true,
          'scope': 'openid profile',
          'client_id': 'client-1',
          'username': 'jdoe',
          'token_type': 'Bearer',
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': 2000000000,
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    final resp = await OidcEndpoints.introspect(
      introspectionEndpoint: endpoint,
      credentials: const OidcClientAuthentication.clientSecretPost(
        clientId: 'client-1',
        clientSecret: 'secret',
      ),
      request: OidcIntrospectionRequest(
        token: 'at-123',
        tokenTypeHint: 'access_token',
      ),
      client: client,
    );

    expect(resp.active, isTrue);
    expect(resp.scope, 'openid profile');
    expect(resp.username, 'jdoe');
    expect(resp.subject, 'user-1');
    expect(resp.audience, ['client-1']);
    expect(
      resp.expiry,
      DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000, isUtc: true),
    );

    final body = Uri.splitQueryString(captured!.body);
    expect(body['token'], 'at-123');
    expect(body['token_type_hint'], 'access_token');
    // client_secret_post puts the credentials in the body.
    expect(body['client_id'], 'client-1');
    expect(body['client_secret'], 'secret');
  });

  test('active defaults to false for an inactive/unknown token', () async {
    final client = MockClient(
      (req) async => http.Response(
        jsonEncode({'active': false}),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );
    final resp = await OidcEndpoints.introspect(
      introspectionEndpoint: endpoint,
      credentials: const OidcClientAuthentication.none(clientId: 'client-1'),
      request: OidcIntrospectionRequest(token: 'expired'),
      client: client,
    );
    expect(resp.active, isFalse);
    expect(resp.scope, isNull);
  });
}
