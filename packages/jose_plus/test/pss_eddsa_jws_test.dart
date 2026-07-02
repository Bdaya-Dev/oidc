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

  group('RSASSA-PSS JWS (RFC 7520 §4.2 PS384 published vector)', () {
    // §3.3 RSA public key (Figure 3) + §4.2.3 compact JWS (Figure 20),
    // extracted verbatim from RFC 7520. PS384 verification is independent of
    // the random salt (recovered from the signature during EMSA-PSS-VERIFY), so
    // this is a deterministic cross-implementation KAT proving our PSS
    // salt/MGF/digest wiring matches other implementations.
    final publicKey = JsonWebKey.fromJson({
      'kty': 'RSA',
      'kid': 'bilbo.baggins@hobbiton.example',
      'n':
          'n4EPtAOCc9AlkeQHPzHStgAbgs7bTZLwUBZdR8_KuKPEHLd4rHVTeT-O-XV2jRojdNhxJWTDvNd7nqQ0VEiZQHz_AJmSCpMaJMRBSFKrKb2wqVwGU_NsYOYL-QtiWN2lbzcEe6XC0dApr5ydQLrHqkHHig3RBordaZ6Aj-oBHqFEHYpPe7Tpe-OfVfHd1E6cS6M1FZcD1NNLYD5lFHpPI9bTwJlsde3uhGqC0ZCuEHg8lhzwOHrtIQbS0FVbb9k3-tVTU4fg_3L_vniUFAKwuCLqKnS2BYwdq_mzSnbLY7h_qixoR7jig3__kRhuaxwUkRz5iaiQkqgc5gHdrNP5zw',
      'e': 'AQAB',
    });
    const compactJws =
        'eyJhbGciOiJQUzM4NCIsImtpZCI6ImJpbGJvLmJhZ2dpbnNAaG9iYml0b24uZXhhbXBsZSJ9.SXTigJlzIGEgZGFuZ2Vyb3VzIGJ1c2luZXNzLCBGcm9kbywgZ29pbmcgb3V0IHlvdXIgZG9vci4gWW91IHN0ZXAgb250byB0aGUgcm9hZCwgYW5kIGlmIHlvdSBkb24ndCBrZWVwIHlvdXIgZmVldCwgdGhlcmXigJlzIG5vIGtub3dpbmcgd2hlcmUgeW91IG1pZ2h0IGJlIHN3ZXB0IG9mZiB0by4.cu22eBqkYDKgIlTpzDXGvaFfz6WGoz7fUDcfT0kkOy42miAh2qyBzk1xEsnk2IpN6-tPid6VrklHkqsGqDqHCdP6O8TTB5dDDItllVo6_1OLPpcbUrhiUSMxbbXUvdvWXzg-UD8biiReQFlfz28zGWVsdiNAUf8ZnyPEgVFn442ZdNqiVJRmBqrYRXe8P_ijQ7p8Vdz0TTrxUeT3lm8d9shnr2lfJT8ImUjvAA2Xez2Mlp8cBE5awDzT0qI0n6uiP1aCN_2_jLAeQTlqRHtfa64QQSUmFAAjVKPbByi7xho0uTOcbH510a6GYmJUAfmWjwZ6oD4ifKo8DYM-X72Eaw';

    test('verifies the published PS384 JWS with the public key', () async {
      final jws = JsonWebSignature.fromCompactSerialization(compactJws);
      final keyStore = JsonWebKeyStore()..addKey(publicKey);
      expect(await jws.verify(keyStore), isTrue);
    });

    test('rejects a tampered signature', () async {
      final parts = compactJws.split('.');
      final sig = parts[2];
      final tampered = '${parts[0]}.${parts[1]}.'
          '${sig.substring(0, sig.length - 1)}${sig.endsWith('A') ? 'B' : 'A'}';
      final jws = JsonWebSignature.fromCompactSerialization(tampered);
      final keyStore = JsonWebKeyStore()..addKey(publicKey);
      expect(await jws.verify(keyStore), isFalse);
    });
  });
}
