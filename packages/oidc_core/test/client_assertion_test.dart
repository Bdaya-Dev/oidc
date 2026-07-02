@TestOn('vm')
library;

import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

({Map<String, dynamic> header, Map<String, dynamic> payload}) _parse(
  String jwt,
) {
  Map<String, dynamic> dec(String s) =>
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(s))))
          as Map<String, dynamic>;
  final parts = jwt.split('.');
  return (header: dec(parts[0]), payload: dec(parts[1]));
}

void main() {
  final audience = Uri.parse('https://op.example.com/token');

  test(
    'privateKeyJwtGenerated mints a verifiable RFC 7523 assertion',
    () async {
      final key = JsonWebKey.generate('RS256');
      final auth = OidcClientAuthentication.privateKeyJwtGenerated(
        clientId: 'client-1',
        signingKey: key,
      );
      final body = auth.resolveForRequest(audience).getBodyParameters();
      expect(
        body['client_assertion_type'],
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      );
      final assertion = body['client_assertion']!;
      final (:header, :payload) = _parse(assertion);
      expect(header['alg'], 'RS256');
      expect(payload['iss'], 'client-1');
      expect(payload['sub'], 'client-1');
      expect(payload['aud'], 'https://op.example.com/token');
      expect(payload['jti'], isNotNull);
      expect(payload['exp'], greaterThan(payload['iat'] as int));

      // The assertion verifies with the registered public key.
      final jws = JsonWebSignature.fromCompactSerialization(assertion);
      expect(await jws.verify(JsonWebKeyStore()..addKey(key)), isTrue);
    },
  );

  test(
    'clientSecretJwtGenerated mints an HS256 assertion (secret never sent)',
    () async {
      const secret = 'top-secret-value';
      final auth = OidcClientAuthentication.clientSecretJwtGenerated(
        clientId: 'client-1',
        clientSecret: secret,
      );
      final body = auth.resolveForRequest(audience).getBodyParameters();
      final assertion = body['client_assertion']!;
      final (:header, :payload) = _parse(assertion);
      expect(header['alg'], 'HS256');
      expect(payload['sub'], 'client-1');
      expect(payload['aud'], 'https://op.example.com/token');
      // The raw secret is never placed in the request body.
      expect(body.containsKey('client_secret'), isFalse);

      // The assertion HMAC verifies with the secret-derived key.
      final octKey = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
        'alg': 'HS256',
      })!;
      final jws = JsonWebSignature.fromCompactSerialization(assertion);
      expect(await jws.verify(JsonWebKeyStore()..addKey(octKey)), isTrue);
    },
  );

  test('mints a fresh jti per request (single-use)', () {
    final auth = OidcClientAuthentication.clientSecretJwtGenerated(
      clientId: 'c',
      clientSecret: 's',
    );
    String jti() =>
        _parse(
              auth
                  .resolveForRequest(audience)
                  .getBodyParameters()['client_assertion']!,
            ).payload['jti']
            as String;
    expect(jti(), isNot(jti()));
  });

  test('non-jwt auth methods return themselves unchanged', () {
    const auth = OidcClientAuthentication.none(clientId: 'c');
    expect(identical(auth.resolveForRequest(audience), auth), isTrue);
  });
}
