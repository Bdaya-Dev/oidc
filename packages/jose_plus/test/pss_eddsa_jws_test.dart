import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('RSASSA-PSS JWS', () {
    for (final alg in ['PS256', 'PS384', 'PS512']) {
      test('$alg sign + verify round trip', () async {
        final key = JsonWebKey.generate(alg);

        final builder = JsonWebSignatureBuilder()
          ..content = 'It works with $alg!'
          ..addRecipient(key, algorithm: alg);
        final jws = builder.build();

        // Re-parse from the compact serialization to exercise the full path.
        final parsed = JsonWebSignature.fromCompactSerialization(
            jws.toCompactSerialization());

        final keyStore = JsonWebKeyStore()..addKey(key);
        expect(await parsed.verify(keyStore), isTrue);
        final payload = await parsed.getPayload(keyStore);
        expect(payload.stringContent, 'It works with $alg!');
      });

      test('$alg verification fails with the wrong key', () async {
        final key = JsonWebKey.generate(alg);
        final builder = JsonWebSignatureBuilder()
          ..content = 'tamper-evident'
          ..addRecipient(key, algorithm: alg);
        final jws = builder.build();
        final parsed = JsonWebSignature.fromCompactSerialization(
            jws.toCompactSerialization());

        final otherKey = JsonWebKey.generate(alg);
        final keyStore = JsonWebKeyStore()..addKey(otherKey);
        expect(await parsed.verify(keyStore), isFalse);
      });
    }
  });

  group('EdDSA JWS (RFC 8037 Appendix A.4)', () {
    // RFC 8037 Appendix A.4 published compact JWS and public JWK (A.2).
    const compactJws =
        'eyJhbGciOiJFZERTQSJ9.RXhhbXBsZSBvZiBFZDI1NTE5IHNpZ25pbmc.'
        'hgyY0il_MGCjP0JzlnLWG1PPOt7-09PGcvMg3AIbQR6dWbhijcNR4ki4iylGjg5Bh'
        'VsPt9g7sVvpAr_MuM0KAg';

    final publicKey = JsonWebKey.fromJson({
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': '11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo',
    });

    test('verifies the published JWS with the public key', () async {
      final jws = JsonWebSignature.fromCompactSerialization(compactJws);
      final keyStore = JsonWebKeyStore()..addKey(publicKey);
      expect(await jws.verify(keyStore), isTrue);
    });

    test('rejects a tampered payload', () async {
      // Flip the last char of the payload segment.
      final parts = compactJws.split('.');
      final tamperedPayload = '${parts[1].substring(0, parts[1].length - 1)}A';
      final tampered = '${parts[0]}.$tamperedPayload.${parts[2]}';
      final jws = JsonWebSignature.fromCompactSerialization(tampered);
      final keyStore = JsonWebKeyStore()..addKey(publicKey);
      expect(await jws.verify(keyStore), isFalse);
    });

    test('full key sign + verify round trip', () async {
      final key = JsonWebKey.generate('EdDSA');
      final builder = JsonWebSignatureBuilder()
        ..content = 'EdDSA works end to end'
        ..addRecipient(key, algorithm: 'EdDSA');
      final jws = builder.build();
      final parsed = JsonWebSignature.fromCompactSerialization(
          jws.toCompactSerialization());

      final keyStore = JsonWebKeyStore()..addKey(key);
      expect(await parsed.verify(keyStore), isTrue);
      expect((await parsed.getPayload(keyStore)).stringContent,
          'EdDSA works end to end');
    });
  });
}
