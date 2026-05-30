@TestOn('vm')
library;

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

String _signJarm(Map<String, dynamic> claims, JsonWebKey key) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(key, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();

Uri _responseUri(String jwt) =>
    Uri.parse('https://app.example.com/cb').replace(
      queryParameters: {OidcConstants_AuthParameters.response: jwt},
    );

int _epoch(Duration fromNow) =>
    clock.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('JARM (JWT Secured Authorization Response Mode)', () {
    test('verifies the response JWT and extracts the inner params', () async {
      final key = JsonWebKey.generate('RS256');
      final jwt = _signJarm({
        'iss': 'https://op.example.com',
        'aud': 'client-1',
        'exp': _epoch(const Duration(minutes: 5)),
        'code': 'auth-code-1',
        'state': 'state-1',
      }, key);

      final resp = await OidcEndpoints.parseAuthorizeResponse(
        responseUri: _responseUri(jwt),
        keyStore: JsonWebKeyStore()..addKey(key),
        allowedAlgorithms: const ['RS256'],
      );

      expect(resp.code, 'auth-code-1');
      expect(resp.state, 'state-1');
      expect(resp.iss, Uri.parse('https://op.example.com'));
    });

    test('rejects a response JWT signed by an untrusted key', () async {
      final signingKey = JsonWebKey.generate('RS256');
      final otherKey = JsonWebKey.generate('RS256');
      final jwt = _signJarm({
        'iss': 'https://op.example.com',
        'aud': 'client-1',
        'exp': _epoch(const Duration(minutes: 5)),
        'code': 'auth-code-1',
        'state': 'state-1',
      }, signingKey);

      expect(
        () => OidcEndpoints.parseAuthorizeResponse(
          responseUri: _responseUri(jwt),
          keyStore: JsonWebKeyStore()..addKey(otherKey),
          allowedAlgorithms: const ['RS256'],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('surfaces a JARM error response as an OidcException', () async {
      final key = JsonWebKey.generate('RS256');
      final jwt = _signJarm({
        'iss': 'https://op.example.com',
        'aud': 'client-1',
        'exp': _epoch(const Duration(minutes: 5)),
        'error': 'access_denied',
        'state': 'state-1',
      }, key);

      expect(
        () => OidcEndpoints.parseAuthorizeResponse(
          responseUri: _responseUri(jwt),
          keyStore: JsonWebKeyStore()..addKey(key),
          allowedAlgorithms: const ['RS256'],
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });
}
