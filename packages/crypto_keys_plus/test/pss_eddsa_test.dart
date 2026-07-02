import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:test/test.dart';

Uint8List _b64url(String s) {
  return Uint8List.fromList(
      base64Url.decode(s + List.filled((4 - s.length % 4) % 4, '=').join()));
}

void main() {
  group('RSASSA-PSS', () {
    // A single 2048-bit RSA key reused across the PSS algorithms.
    final rsa = KeyPair.generateRsa(bitStrength: 2048);
    final message =
        Uint8List.fromList(utf8.encode('the quick brown fox jumps over'));

    for (final entry in {
      'PS256': algorithms.signing.rsa.pss.sha256,
      'PS384': algorithms.signing.rsa.pss.sha384,
      'PS512': algorithms.signing.rsa.pss.sha512,
    }.entries) {
      group(entry.key, () {
        final alg = entry.value;

        test('sign/verify round trip', () {
          final signer = rsa.createSigner(alg);
          final signature = signer.sign(message);

          final verifier = rsa.createVerifier(alg);
          expect(verifier.verify(message, signature), isTrue);
        });

        test('is non-deterministic (random salt)', () {
          final signer = rsa.createSigner(alg);
          final a = signer.sign(message).data;
          final b = signer.sign(message).data;
          // Different salt => different signature, but both verify.
          expect(a, isNot(equals(b)));
          final verifier = rsa.createVerifier(alg);
          expect(verifier.verify(message, Signature(a)), isTrue);
          expect(verifier.verify(message, Signature(b)), isTrue);
        });

        test('rejects a flipped signature byte', () {
          final signer = rsa.createSigner(alg);
          final signature = signer.sign(message).data;
          final tampered = Uint8List.fromList(signature);
          tampered[tampered.length ~/ 2] ^= 0x01;

          final verifier = rsa.createVerifier(alg);
          expect(verifier.verify(message, Signature(tampered)), isFalse);
        });

        test('rejects a different message', () {
          final signer = rsa.createSigner(alg);
          final signature = signer.sign(message);

          final verifier = rsa.createVerifier(alg);
          final other = Uint8List.fromList(utf8.encode('a different message'));
          expect(verifier.verify(other, signature), isFalse);
        });
      });
    }
  });

  group('EdDSA / Ed25519 (RFC 8037 Appendix A)', () {
    // RFC 8037 Appendix A.1 / A.4 test vector.
    final d = _b64url('nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A');
    final x = _b64url('11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo');
    // The JWS Signing Input from Appendix A.4.
    final signingInput = Uint8List.fromList(ascii
        .encode('eyJhbGciOiJFZERTQSJ9.RXhhbXBsZSBvZiBFZDI1NTE5IHNpZ25pbmc'));
    final expectedSignature = _b64url(
        'hgyY0il_MGCjP0JzlnLWG1PPOt7-09PGcvMg3AIbQR6dWbhijcNR4ki4iylGjg5Bh'
        'VsPt9g7sVvpAr_MuM0KAg');

    final alg = algorithms.signing.eddsa.ed25519;

    test('JWK round-trips through KeyPair.fromJwk', () {
      final kp = KeyPair.fromJwk({
        'kty': 'OKP',
        'crv': 'Ed25519',
        'd': 'nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A',
        'x': '11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo',
      })!;
      expect((kp.publicKey as OkpPublicKey).rawBytes, equals(x));
      expect((kp.privateKey as OkpPrivateKey).rawBytes, equals(d));
      expect((kp.publicKey as OkpPublicKey).curve, equals(curves.ed25519));
    });

    test('signing produces the RFC 8037 known signature (deterministic)', () {
      final priv = OkpPrivateKey(rawBytes: d, curve: curves.ed25519);
      final signature = priv.createSigner(alg).sign(signingInput);
      expect(signature.data, equals(expectedSignature));
    });

    test('verifies the RFC 8037 known signature', () {
      final pub = OkpPublicKey(rawBytes: x, curve: curves.ed25519);
      expect(
        pub
            .createVerifier(alg)
            .verify(signingInput, Signature(expectedSignature)),
        isTrue,
      );
    });

    test('rejects a flipped signature byte', () {
      final pub = OkpPublicKey(rawBytes: x, curve: curves.ed25519);
      final tampered = Uint8List.fromList(expectedSignature);
      tampered[0] ^= 0x01;
      expect(
        pub.createVerifier(alg).verify(signingInput, Signature(tampered)),
        isFalse,
      );
    });

    test('rejects a different message', () {
      final pub = OkpPublicKey(rawBytes: x, curve: curves.ed25519);
      final other = Uint8List.fromList(ascii.encode('not the signed message'));
      expect(
        pub.createVerifier(alg).verify(other, Signature(expectedSignature)),
        isFalse,
      );
    });

    test('generate + sign + verify round trip', () {
      final kp = KeyPair.generateEd25519();
      final msg = Uint8List.fromList(utf8.encode('hello ed25519'));
      final sig = kp.createSigner(alg).sign(msg);
      expect(kp.createVerifier(alg).verify(msg, sig), isTrue);

      final tampered = Uint8List.fromList(msg)..[0] ^= 0x01;
      expect(kp.createVerifier(alg).verify(tampered, sig), isFalse);
    });
  });
}
