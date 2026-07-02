@TestOn('vm')
library;

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Builds a compact-serialized RS256 id_token signed by [signingKey].
Future<String> _signIdToken(
  JsonWebKey signingKey,
  Map<String, dynamic> claims,
) async {
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..addRecipient(signingKey, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

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
    'fromIdToken rejects an unverifiable signature by default (fail-closed)',
    () async {
      final signingKey = JsonWebKey.generate('RS256');
      final idToken = await _signIdToken(signingKey, _baseClaims());

      // The keystore does NOT contain the signing key, so verification fails.
      final foreignKeystore = JsonWebKeyStore()
        ..addKey(JsonWebKey.generate('RS256'));

      await expectLater(
        // No strictVerification arg -> exercises the fail-closed DEFAULT.
        OidcUser.fromIdToken(
          token: _tokenWith(idToken),
          keystore: foreignKeystore,
          allowedAlgorithms: const ['RS256'],
        ),
        throwsA(anything),
      );
    },
  );

  test('fromIdToken accepts an unverifiable signature only when strict '
      'verification is explicitly disabled', () async {
    final signingKey = JsonWebKey.generate('RS256');
    final idToken = await _signIdToken(signingKey, _baseClaims());
    final foreignKeystore = JsonWebKeyStore()
      ..addKey(JsonWebKey.generate('RS256'));

    final user = await OidcUser.fromIdToken(
      token: _tokenWith(idToken),
      keystore: foreignKeystore,
      strictVerification: false,
      allowedAlgorithms: const ['RS256'],
    );
    // The unverified token is still parsed (claims readable) but NOT verified.
    expect(user.claims.subject, 'user-1');
    expect(user.parsedIdToken.isVerified, isNot(true));
  });

  test('fromIdToken accepts a signature the keystore can verify', () async {
    final signingKey = JsonWebKey.generate('RS256');
    final idToken = await _signIdToken(signingKey, _baseClaims());
    final keystore = JsonWebKeyStore()..addKey(signingKey);

    final user = await OidcUser.fromIdToken(
      token: _tokenWith(idToken),
      keystore: keystore,
      allowedAlgorithms: const ['RS256'],
    );
    expect(user.claims.subject, 'user-1');
    expect(user.parsedIdToken.isVerified, isTrue);
  });
}
