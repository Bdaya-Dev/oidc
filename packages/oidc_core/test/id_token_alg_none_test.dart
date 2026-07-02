@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Builds an UNSIGNED (`alg:none`) compact JWT — header `{"alg":"none"}`, the
/// given claims, and an empty signature segment. This is the shape an attacker
/// forges when the RP accepts `alg:none`.
String _unsignedIdToken(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'none', 'typ': 'JWT'});
  final payload = seg(claims);
  return '$header.$payload.';
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
    'fromIdToken REJECTS an alg:none id_token even when the OP advertises '
    '`none` in id_token_signing_alg_values_supported (no unsigned forgery)',
    () async {
      final idToken = _unsignedIdToken(_baseClaims());
      // A real keystore is present (the verify path runs), and the OP-advertised
      // allow-list happens to include `none` — jose_plus only auto-rejects
      // `none` when the list is null, so without an explicit strip this would
      // accept the forged unsigned token. Verification is always-strict.
      final keystore = JsonWebKeyStore()..addKey(JsonWebKey.generate('RS256'));

      await expectLater(
        OidcUser.fromIdToken(
          token: _tokenWith(idToken),
          keystore: keystore,
          allowedAlgorithms: const ['RS256', 'none'],
        ),
        throwsA(anything),
        reason: 'an alg:none id_token must never be accepted as verified',
      );
    },
  );

  test(
    'fromIdToken still accepts a genuinely-signed RS256 token when `none` is '
    'also advertised (the strip must not break valid algs)',
    () async {
      final signingKey = JsonWebKey.generate('RS256');
      final builder = JsonWebSignatureBuilder()
        ..jsonContent = _baseClaims()
        ..addRecipient(signingKey, algorithm: 'RS256');
      final idToken = builder.build().toCompactSerialization();
      final keystore = JsonWebKeyStore()..addKey(signingKey);

      final user = await OidcUser.fromIdToken(
        token: _tokenWith(idToken),
        keystore: keystore,
        allowedAlgorithms: const ['RS256', 'none'],
      );
      expect(user.claims.subject, 'user-1');
      expect(user.parsedIdToken.isVerified, isTrue);
    },
  );
}
