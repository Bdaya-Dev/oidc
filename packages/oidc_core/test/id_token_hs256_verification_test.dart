@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// The `oct` JWK derived from a client_secret, exactly as the manager's
/// `init()` now registers it (RFC 7518 §3.2 / OIDC Core §16.19).
JsonWebKey _octKeyFromSecret(String secret) => JsonWebKey.fromJson({
  'kty': 'oct',
  'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
  'use': 'sig',
})!;

Map<String, dynamic> _baseClaims() => {
  'iss': 'https://op.example.com',
  'sub': 'user-1',
  'aud': 'client-1',
  'exp':
      clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
};

OidcToken _tokenWith(String idToken) => OidcToken(
  idToken: idToken,
  accessToken: 'at',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
  creationTime: clock.now(),
);

void main() {
  test(
    'an HS256-signed id_token verifies when the client_secret oct key is in '
    'the keystore (what manager.init() now registers)',
    () async {
      const secret = 'a-very-secret-client-secret-value-0123456789';
      // Sign HS256 with the symmetric key derived from the client_secret.
      final signingKey = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
        'alg': 'HS256',
      })!;
      final idToken =
          (JsonWebSignatureBuilder()
                ..jsonContent = _baseClaims()
                ..addRecipient(signingKey, algorithm: 'HS256'))
              .build()
              .toCompactSerialization();

      // The keystore holds the client_secret-derived oct key (the init() fix).
      final keystore = JsonWebKeyStore()..addKey(_octKeyFromSecret(secret));

      final user = await OidcUser.fromIdToken(
        token: _tokenWith(idToken),
        keystore: keystore,
        allowedAlgorithms: const ['HS256'],
      );
      expect(user.claims.subject, 'user-1');
      expect(user.parsedIdToken.isVerified, isTrue);
    },
  );

  test(
    'an HS256 id_token is REJECTED (fail-closed) when the client_secret oct '
    'key is absent from the keystore',
    () async {
      const secret = 'a-very-secret-client-secret-value-0123456789';
      final signingKey = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
        'alg': 'HS256',
      })!;
      final idToken =
          (JsonWebSignatureBuilder()
                ..jsonContent = _baseClaims()
                ..addRecipient(signingKey, algorithm: 'HS256'))
              .build()
              .toCompactSerialization();

      // A keystore WITHOUT the secret-derived key cannot verify the HS256 MAC.
      final foreignKeystore = JsonWebKeyStore()
        ..addKey(JsonWebKey.generate('RS256'));

      await expectLater(
        OidcUser.fromIdToken(
          token: _tokenWith(idToken),
          keystore: foreignKeystore,
          allowedAlgorithms: const ['HS256'],
        ),
        throwsA(anything),
      );
    },
  );
}
