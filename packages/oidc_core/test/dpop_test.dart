@TestOn('vm')
library;

import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _decodeSegment(String segment) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segment))))
        as Map<String, dynamic>;

({Map<String, dynamic> header, Map<String, dynamic> payload}) _parseProof(
  String proof,
) {
  final parts = proof.split('.');
  expect(parts, hasLength(3), reason: 'compact JWS has 3 segments');
  return (header: _decodeSegment(parts[0]), payload: _decodeSegment(parts[1]));
}

void main() {
  group('oidcJwkThumbprint', () {
    test('matches the RFC 7638 §3.1 example vector', () {
      // The exact RSA public key from RFC 7638 §3.1.
      final key = JsonWebKey.fromJson({
        'kty': 'RSA',
        'n':
            '0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4'
            'cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn'
            '64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2Qvz'
            'qY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08'
            'qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1'
            'jF44-csFCur-kEgU8awapJzKnqDKgw',
        'e': 'AQAB',
        'alg': 'RS256',
        'kid': '2011-04-29',
      })!;
      expect(
        oidcJwkThumbprint(key),
        'NzbLsXh8uDCcd-6MNwXF4W_7noWXFZAfHkxZsRGC9Xs',
      );
    });

    test('is deterministic for a generated EC key and equals the manager '
        'thumbprint (dpop_jkt)', () {
      final dpop = OidcDPoPManager.generate(const OidcDPoPSettings());
      expect(oidcJwkThumbprint(dpop.key), dpop.thumbprint);
      expect(oidcJwkThumbprint(dpop.key), oidcJwkThumbprint(dpop.key));
    });
  });

  group('oidcNormalizeHtu', () {
    test('lowercases scheme/host, drops default port, query, and fragment', () {
      expect(
        oidcNormalizeHtu(Uri.parse('https://AS.Example:443/Token?x=1#frag')),
        'https://as.example/Token',
      );
    });

    test('keeps an explicit non-default port', () {
      expect(
        oidcNormalizeHtu(Uri.parse('https://as.example:8443/token')),
        'https://as.example:8443/token',
      );
    });
  });

  group('oidcDPoPPublicJwk', () {
    test('drops the private key material (no `d`)', () {
      final key = JsonWebKey.generate('ES256');
      final pub = oidcDPoPPublicJwk(key);
      expect(pub.keys.toSet(), {'kty', 'crv', 'x', 'y'});
      expect(pub.containsKey('d'), isFalse);
    });
  });

  group('createTokenProof', () {
    final dpop = OidcDPoPManager.generate(const OidcDPoPSettings());
    final tokenEndpoint = Uri.parse('https://op.example.com/token?ignored=1');

    test('produces a well-formed proof header (RFC 9449 §4.2)', () {
      final proof = dpop.createTokenProof(tokenEndpoint);
      final header = _parseProof(proof).header;
      expect(header['typ'], 'dpop+jwt');
      expect(header['alg'], 'ES256');
      final jwk = header['jwk']! as Map<String, dynamic>;
      expect(jwk['kty'], 'EC');
      expect(jwk.containsKey('x'), isTrue);
      expect(jwk.containsKey('y'), isTrue);
      // The proof MUST NOT carry the private key or a kid.
      expect(jwk.containsKey('d'), isFalse);
      expect(header.containsKey('kid'), isFalse);
    });

    test('produces the required payload claims, no ath/nonce', () {
      final proof = dpop.createTokenProof(tokenEndpoint);
      final payload = _parseProof(proof).payload;
      // jti present with >= 96 bits of entropy (>= 12 decoded bytes).
      final jti = payload['jti']! as String;
      expect(
        base64Url.decode(base64Url.normalize(jti)).length,
        greaterThanOrEqualTo(12),
      );
      expect(payload['htm'], 'POST');
      // htu normalized: query stripped.
      expect(payload['htu'], 'https://op.example.com/token');
      expect(payload['iat'], isA<int>());
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(((payload['iat']! as int) - now).abs(), lessThan(120));
      // No access token at the token endpoint -> no ath; no challenge -> no nonce.
      expect(payload.containsKey('ath'), isFalse);
      expect(payload.containsKey('nonce'), isFalse);
    });

    test(
      'signature verifies against the embedded public jwk (self-consistent)',
      () async {
        final proof = dpop.createTokenProof(tokenEndpoint);
        final header = _parseProof(proof).header;
        final embeddedKey = JsonWebKey.fromJson(
          (header['jwk']! as Map).cast<String, dynamic>(),
        );
        final keyStore = JsonWebKeyStore()..addKey(embeddedKey);
        final jws = JsonWebSignature.fromCompactSerialization(proof);
        expect(await jws.verify(keyStore), isTrue);
      },
    );

    test('mints a unique jti per proof', () {
      final a = _parseProof(
        dpop.createTokenProof(tokenEndpoint),
      ).payload['jti'];
      final b = _parseProof(
        dpop.createTokenProof(tokenEndpoint),
      ).payload['jti'];
      expect(a, isNot(b));
    });

    test('includes a cached nonce when present', () {
      final endpoint = Uri.parse('https://nonce.example.com/token');
      dpop.setNonceFor(endpoint, 'srv-nonce-1');
      final payload = _parseProof(dpop.createTokenProof(endpoint)).payload;
      expect(payload['nonce'], 'srv-nonce-1');
    });
  });

  group('createResourceProof', () {
    test('binds the access token via ath (RFC 9449 §4.2/§7.1)', () {
      final dpop = OidcDPoPManager.generate(const OidcDPoPSettings());
      const accessToken = 'access-token-123';
      final proof = dpop.createResourceProof(
        method: 'get',
        uri: Uri.parse('https://api.example.com/me'),
        accessToken: accessToken,
      );
      final payload = _parseProof(proof).payload;
      expect(payload['htm'], 'GET');
      expect(payload['ath'], oidcDPoPAth(accessToken));
      expect(payload['htu'], 'https://api.example.com/me');
    });
  });

  group('OidcDPoPAlgorithm', () {
    test('maps to the JOSE alg name', () {
      expect(OidcDPoPAlgorithm.es256.joseName, 'ES256');
      expect(OidcDPoPAlgorithm.rs256.joseName, 'RS256');
    });

    test('rs256 generates a usable RSA proof key', () {
      final dpop = OidcDPoPManager.generate(
        const OidcDPoPSettings(algorithm: OidcDPoPAlgorithm.rs256),
      );
      final proof = dpop.createTokenProof(
        Uri.parse('https://op.example.com/token'),
      );
      final header = _parseProof(proof).header;
      expect(header['alg'], 'RS256');
      final jwk = header['jwk']! as Map<String, dynamic>;
      expect(jwk['kty'], 'RSA');
      expect(jwk.containsKey('n'), isTrue);
      expect(jwk.containsKey('e'), isTrue);
      expect(jwk.containsKey('d'), isFalse);
    });
  });
}
