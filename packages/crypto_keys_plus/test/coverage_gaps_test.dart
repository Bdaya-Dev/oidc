import 'dart:typed_data';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:test/test.dart';

/// Targeted tests for previously-uncovered branches: the algorithm registry
/// tables, JWA name lookup, key value semantics (== / hashCode), error paths in
/// the operators, and the AES-CBC-HMAC decrypt / AES-KeyWrap guards.

/// An `Object`-typed value of an unrelated runtime type, used to drive the
/// `other is XKey` false branch of the various `operator ==` overrides without
/// tripping the `unrelated_type_equality_checks` lint.
final Object _unrelated = ['not a key'];

void main() {
  group('digest algorithm registry', () {
    // Exercising createAlgorithm() runs each factory closure and returns a real
    // pointycastle digest, so we can assert its identity and output size.
    test('SHA family maps to correct digest sizes', () {
      expect(algorithms.digest.sha1.createAlgorithm().digestSize, 20);
      expect(algorithms.digest.sha224.createAlgorithm().digestSize, 28);
      expect(algorithms.digest.sha256.createAlgorithm().digestSize, 32);
      expect(algorithms.digest.sha384.createAlgorithm().digestSize, 48);
      expect(algorithms.digest.sha512.createAlgorithm().digestSize, 64);
    });

    test('SHA names are canonical', () {
      expect(algorithms.digest.sha1.createAlgorithm().algorithmName, 'SHA-1');
      expect(
          algorithms.digest.sha256.createAlgorithm().algorithmName, 'SHA-256');
      expect(
          algorithms.digest.sha512.createAlgorithm().algorithmName, 'SHA-512');
    });

    test('MD family maps to correct digest sizes', () {
      expect(algorithms.digest.md2.createAlgorithm().digestSize, 16);
      expect(algorithms.digest.md4.createAlgorithm().digestSize, 16);
      expect(algorithms.digest.md5.createAlgorithm().digestSize, 16);
    });

    test('SHA-512/t honours the requested truncated size', () {
      final d = algorithms.digest.sha512t(28);
      expect(d.name, 'digest/SHA-512/224');
      // sha512t is declared as the base AlgorithmIdentifier<Algorithm>, so
      // reach digestSize dynamically.
      expect((d.createAlgorithm() as dynamic).digestSize, 28);
    });
  });

  group('encryption algorithm registry', () {
    test('deprecated aes cbc getter aliases encryption.aes.cbc', () {
      // ignore: deprecated_member_use
      expect(
          algorithms.encrypting_aes_cbc, same(algorithms.encryption.aes.cbc));
    });

    test('AES EAX factory is unimplemented', () {
      expect(algorithms.encryption.aes.eax.createAlgorithm,
          throwsUnimplementedError);
    });

    test('AES key wrap and rsa identifiers expose their names', () {
      expect(algorithms.encryption.aes.keyWrap.name, 'enc/AES/KW');
      expect(algorithms.encryption.rsa.pkcs1.name, 'enc/RSA/PKCS1');
      expect(algorithms.encryption.aes.keyWrap.createAlgorithm().algorithmName,
          'AESWrap');
    });

    test('hybrid withParameters builds a HKDF key derivator', () {
      final id = algorithms.encryption.hybrid.withParameters(
        keySize: 256,
        curve: curves.p256,
        hkdfHash: algorithms.digest.sha256,
      );
      expect(id.name, 'enc/hybrid');
      expect(id.createAlgorithm().algorithmName, contains('HKDF'));
    });
  });

  group('EdDSA registry placeholder', () {
    test('Ed25519 placeholder algorithm reports its name', () {
      expect(algorithms.signing.eddsa.ed25519.createAlgorithm().algorithmName,
          'Ed25519');
      expect(algorithms.signing.eddsa.ed25519.name, 'sig/EdDSA/Ed25519');
    });
  });

  group('AlgorithmIdentifier.getByJwaName', () {
    test('resolves known JWS/JWE identifiers', () {
      expect(AlgorithmIdentifier.getByJwaName('HS256'),
          same(algorithms.signing.hmac.sha256));
      expect(AlgorithmIdentifier.getByJwaName('RS512'),
          same(algorithms.signing.rsa.sha512));
      expect(AlgorithmIdentifier.getByJwaName('ES256'),
          same(algorithms.signing.ecdsa.sha256));
      expect(AlgorithmIdentifier.getByJwaName('PS384'),
          same(algorithms.signing.rsa.pss.sha384));
      expect(AlgorithmIdentifier.getByJwaName('EdDSA'),
          same(algorithms.signing.eddsa.ed25519));
      expect(AlgorithmIdentifier.getByJwaName('A128GCM'),
          same(algorithms.encryption.aes.gcm));
      expect(AlgorithmIdentifier.getByJwaName('A256CBC-HS512'),
          same(algorithms.encryption.aes.cbcWithHmac.sha512));
    });

    test('returns null for the "none" algorithm', () {
      expect(AlgorithmIdentifier.getByJwaName('none'), isNull);
    });

    test('throws UnimplementedError for a known-but-unimplemented alg', () {
      // 'dir' is present in the table mapped to null (a placeholder), so it is
      // reported as not-yet-implemented rather than unsupported.
      expect(() => AlgorithmIdentifier.getByJwaName('dir'),
          throwsA(isA<UnimplementedError>()));
      expect(() => AlgorithmIdentifier.getByJwaName('ECDH-ES'),
          throwsA(isA<UnimplementedError>()));
    });

    test('throws UnsupportedError for an entirely unknown alg', () {
      expect(() => AlgorithmIdentifier.getByJwaName('NOPE-999'),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('key value semantics (== / hashCode)', () {
    test('RsaPublicKey', () {
      final a =
          RsaPublicKey(modulus: BigInt.from(3233), exponent: BigInt.from(17));
      final b =
          RsaPublicKey(modulus: BigInt.from(3233), exponent: BigInt.from(17));
      final c =
          RsaPublicKey(modulus: BigInt.from(3233), exponent: BigInt.from(19));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
      expect(identical(a, a) && a == a, isTrue);
    });

    test('RsaPrivateKey', () {
      RsaPrivateKey make(BigInt d) => RsaPrivateKey(
            privateExponent: d,
            firstPrimeFactor: BigInt.from(61),
            secondPrimeFactor: BigInt.from(53),
            modulus: BigInt.from(3233),
          );
      final a = make(BigInt.from(413));
      final b = make(BigInt.from(413));
      final c = make(BigInt.from(999));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });

    test('EcPublicKey', () {
      EcPublicKey make(BigInt x) => EcPublicKey(
          xCoordinate: x, yCoordinate: BigInt.two, curve: curves.p256);
      final a = make(BigInt.one);
      final b = make(BigInt.one);
      final c = make(BigInt.from(7));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      // Same coordinates, different curve -> not equal.
      expect(
          a,
          isNot(equals(EcPublicKey(
              xCoordinate: BigInt.one,
              yCoordinate: BigInt.two,
              curve: curves.p384))));
      expect(a == _unrelated, isFalse);
    });

    test('EcPrivateKey', () {
      final a = EcPrivateKey(eccPrivateKey: BigInt.from(5), curve: curves.p256);
      final b = EcPrivateKey(eccPrivateKey: BigInt.from(5), curve: curves.p256);
      final c = EcPrivateKey(eccPrivateKey: BigInt.from(6), curve: curves.p256);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(
          a,
          isNot(equals(EcPrivateKey(
              eccPrivateKey: BigInt.from(5), curve: curves.p384))));
      expect(a == _unrelated, isFalse);
    });

    test('OkpPublicKey', () {
      OkpPublicKey make(List<int> raw, [Identifier? crv]) => OkpPublicKey(
          rawBytes: Uint8List.fromList(raw), curve: crv ?? curves.ed25519);
      final a = make([1, 2, 3]);
      final b = make([1, 2, 3]);
      final c = make([1, 2, 4]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });

    test('OkpPrivateKey', () {
      OkpPrivateKey make(List<int> raw) => OkpPrivateKey(
          rawBytes: Uint8List.fromList(raw), curve: curves.ed25519);
      final a = make([9, 8, 7]);
      final b = make([9, 8, 7]);
      final c = make([9, 8, 6]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });

    test('SymmetricKey', () {
      SymmetricKey make(List<int> raw) =>
          SymmetricKey(keyValue: Uint8List.fromList(raw));
      final a = make([0, 1, 2, 3]);
      final b = make([0, 1, 2, 3]);
      final c = make([0, 1, 2, 4]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });

    test('Signature', () {
      final a = Signature(Uint8List.fromList([1, 2, 3]));
      final b = Signature(Uint8List.fromList([1, 2, 3]));
      final c = Signature(Uint8List.fromList([1, 2, 9]));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });

    test('EncryptionResult', () {
      EncryptionResult make(List<int> data) => EncryptionResult(
            Uint8List.fromList(data),
            initializationVector: Uint8List.fromList([9, 9]),
            authenticationTag: Uint8List.fromList([8]),
            additionalAuthenticatedData: Uint8List.fromList([7, 6]),
          );
      final a = make([1, 2, 3]);
      final b = make([1, 2, 3]);
      final c = make([1, 2, 4]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a == _unrelated, isFalse);
    });
  });

  group('operator error paths', () {
    test('generateEc rejects an unsupported curve', () {
      // curves.ed25519 is not an EC curve, so createCurveParameters throws.
      expect(() => KeyPair.generateEc(curves.ed25519), throwsArgumentError);
    });

    test('EdDSA signer/verifier reject a non-Ed25519 OKP curve', () {
      final priv = OkpPrivateKey(
          rawBytes: Uint8List(32), curve: curves.p256); // wrong curve
      final pub = OkpPublicKey(rawBytes: Uint8List(32), curve: curves.p256);
      expect(
          () => priv.createSigner(algorithms.signing.eddsa.ed25519).sign([1]),
          throwsA(isA<UnsupportedError>()));
      expect(
          () => pub.createVerifier(algorithms.signing.eddsa.ed25519).verify(
              Uint8List.fromList([1]), Signature(Uint8List.fromList([0]))),
          throwsA(isA<UnsupportedError>()));
    });

    test('SymmetricKey.generate rejects a non-byte-aligned bit length', () {
      expect(() => SymmetricKey.generate(100), throwsArgumentError);
    });

    test('KeyPair without a private key cannot create a signer', () {
      final pair = KeyPair(
        publicKey:
            RsaPublicKey(modulus: BigInt.from(3233), exponent: BigInt.from(17)),
        privateKey: null,
      );
      expect(() => pair.createSigner(algorithms.signing.rsa.sha256),
          throwsStateError);
    });

    test('KeyPair without a public key cannot create a verifier', () {
      final pair = KeyPair(
        publicKey: null,
        privateKey: RsaPrivateKey(
          privateExponent: BigInt.from(413),
          firstPrimeFactor: BigInt.from(61),
          secondPrimeFactor: BigInt.from(53),
          modulus: BigInt.from(3233),
        ),
      );
      expect(() => pair.createVerifier(algorithms.signing.rsa.sha256),
          throwsStateError);
    });
  });

  group('RSA operators with a generated key', () {
    // One 2048-bit key shared by the RSA-specific paths below.
    final rsa = KeyPair.generateRsa(bitStrength: 2048);
    final message = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

    test('verify returns false for an oversized/garbage signature', () {
      final verifier = rsa.createVerifier(algorithms.signing.rsa.sha256);
      // A signature far larger than the modulus makes pointycastle throw an
      // ArgumentError internally; verify() must swallow it and return false.
      final bogus = Signature(Uint8List(400)..fillRange(0, 400, 0xff));
      expect(verifier.verify(message, bogus), isFalse);
    });

    test('RSASSA-PSS with an explicit custom salt length round-trips', () {
      final alg = algorithms.signing.rsa.pss.withParameters(
        sigHash: algorithms.digest.sha256,
        mgf1Hash: algorithms.digest.sha256,
        saltLength: 48,
      );
      expect(alg.name, contains('/salt48'));
      // Building the signer runs the withParameters factory closure.
      final signer = rsa.createSigner(alg);
      final verifier = rsa.createVerifier(alg);
      final sig = signer.sign(message);
      expect(verifier.verify(message, sig), isTrue);
      // Tampered signature must fail.
      final tampered = Signature(Uint8List.fromList(sig.data)..[0] ^= 0x01);
      expect(verifier.verify(message, tampered), isFalse);
    });
  });

  group('symmetric AEAD guards', () {
    test('AES-128-CBC-HMAC-SHA-256 encrypt/decrypt round trip', () {
      final key = SymmetricKey.generate(256); // 16-byte mac + 16-byte enc
      final enc =
          key.createEncrypter(algorithms.encryption.aes.cbcWithHmac.sha256);
      final plaintext =
          Uint8List.fromList(List<int>.generate(40, (i) => i & 0xff));
      final result = enc.encrypt(plaintext,
          additionalAuthenticatedData: Uint8List.fromList([1, 2, 3, 4]));
      expect(result.authenticationTag, isNotNull);
      // Decrypt drives the auth-tag verification branch of process().
      expect(enc.decrypt(result), equals(plaintext));
    });

    test('AES key wrap rejects input that is not a multiple of 64 bits', () {
      final kek = SymmetricKey.generate(128);
      final enc = kek.createEncrypter(algorithms.encryption.aes.keyWrap);
      // 5 bytes is not a multiple of 8 -> ArgumentError from AESKeyWrap.process.
      expect(() => enc.encrypt(Uint8List.fromList([1, 2, 3, 4, 5])),
          throwsArgumentError);
    });
  });
}
