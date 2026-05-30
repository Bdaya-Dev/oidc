@TestOn('vm')
library;

import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _segment(String jwt, int index) =>
    jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(jwt.split('.')[index])),
          ),
        )
        as Map<String, dynamic>;

void main() {
  group('JAR request object (RFC 9101)', () {
    test('oidcCreateRequestObject signs the params with iss/aud/exp + typ '
        'and verifies with the public key', () async {
      final key = JsonWebKey.generate('RS256');
      final jwt = oidcCreateRequestObject(
        parameters: const {
          'response_type': 'code',
          'client_id': 'client-1',
          'scope': 'openid',
          'state': 's',
          'nonce': 'n',
        },
        key: key,
        algorithm: 'RS256',
        issuer: 'client-1',
        audience: 'https://op.example.com',
      );

      final header = _segment(jwt, 0);
      final payload = _segment(jwt, 1);
      expect(header['typ'], 'oauth-authz-req+jwt');
      expect(header['alg'], 'RS256');
      expect(payload['iss'], 'client-1');
      expect(payload['aud'], 'https://op.example.com');
      expect(payload['response_type'], 'code');
      expect(payload['scope'], 'openid');
      expect(payload['state'], 's');
      expect(payload['nonce'], 'n');
      expect(payload['exp'], isA<int>());
      expect(payload['jti'], isNotNull);

      // The authorization server verifies it against the client's public key.
      final jws = JsonWebSignature.fromCompactSerialization(jwt);
      final keyStore = JsonWebKeyStore()..addKey(key);
      expect(await jws.verify(keyStore), isTrue);
    });

    test('generateUri collapses to client_id + response_type + scope + request '
        'when a request object is set (OIDC Core §6.1)', () {
      final req = OidcAuthorizeRequest(
        responseType: const ['code'],
        clientId: 'client-1',
        redirectUri: Uri.parse('com.example.app://cb'),
        scope: const ['openid', 'profile'],
        state: 'xyz',
        nonce: 'abc',
        request: 'the.signed.jwt',
      );
      final qp = req
          .generateUri(Uri.parse('https://op.example.com/authorize'))
          .queryParameters;

      expect(qp['client_id'], 'client-1');
      expect(qp['response_type'], 'code');
      expect(qp['scope'], 'openid profile');
      expect(qp['request'], 'the.signed.jwt');
      // The remaining params live inside the (signed) request object only.
      expect(qp.containsKey('state'), isFalse);
      expect(qp.containsKey('redirect_uri'), isFalse);
      expect(qp.containsKey('nonce'), isFalse);
    });
  });
}
