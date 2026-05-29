part of '../crypto_keys.dart';

/// A cryptographic key
abstract class Key {
  /// Creates an [Encrypter] using this key and the specified algorithm
  Encrypter createEncrypter(Identifier algorithm) {
    if (this is SymmetricKey) {
      return _SymmetricEncrypter(algorithm, this as SymmetricKey);
    }

    return _AsymmetricEncrypter(algorithm, this);
  }
}

/// A cryptographic public key
abstract class PublicKey implements Key {
  /// Creates a signature [Verifier] using this key and the specified algorithm
  Verifier createVerifier(Identifier algorithm) {
    if (this is SymmetricKey) {
      return _SymmetricSignerAndVerifier(algorithm, this as SymmetricKey);
    }

    return _AsymmetricVerifier(algorithm, this);
  }
}

/// A cryptographic private key
abstract class PrivateKey implements Key {
  /// Creates a [Signer] using this key and the specified algorithm.
  Signer createSigner(Identifier algorithm) {
    if (this is SymmetricKey) {
      return _SymmetricSignerAndVerifier(algorithm, this as SymmetricKey);
    }

    return _AsymmetricSigner(algorithm, this);
  }
}

/// Holds a key pair (private and public key)
class KeyPair {
  /// The public key
  final PublicKey? publicKey;

  /// The private key
  final PrivateKey? privateKey;

  /// Creates a [KeyPair] from a public and private key
  KeyPair({required this.publicKey, required this.privateKey});

  /// Creates a [KeyPair] from a symmetric key
  KeyPair.symmetric(SymmetricKey key) : this(privateKey: key, publicKey: key);

  /// Generates a random symmetric [KeyPair] with specified bit length
  factory KeyPair.generateSymmetric(int bitLength) =>
      KeyPair.symmetric(SymmetricKey.generate(bitLength));

  factory KeyPair.generateRsa({BigInt? exponent, int bitStrength = 2048}) {
    exponent ??= BigInt.from(65537);

    var generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(exponent, bitStrength, 5),
          DefaultSecureRandom()));

    var pair = generator.generateKeyPair();

    return KeyPair(
        publicKey: RsaPublicKey(
          exponent: pair.publicKey.publicExponent!,
          modulus: pair.publicKey.n!,
        ),
        privateKey: RsaPrivateKey(
          modulus: pair.privateKey.n!,
          privateExponent: pair.privateKey.privateExponent!,
          firstPrimeFactor: pair.privateKey.p!,
          secondPrimeFactor: pair.privateKey.q!,
        ));
  }

  factory KeyPair.generateEc(Identifier curve) {
    var generator = pc.ECKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.ECKeyGeneratorParameters(
            _AsymmetricOperator.createCurveParameters(curve),
          ),
          DefaultSecureRandom(),
        ),
      );

    var pair = generator.generateKeyPair();

    return KeyPair(
        publicKey: EcPublicKey(
            xCoordinate: pair.publicKey.Q!.x!.toBigInteger()!,
            yCoordinate: pair.publicKey.Q!.y!.toBigInteger()!,
            curve: curve),
        privateKey:
            EcPrivateKey(eccPrivateKey: pair.privateKey.d!, curve: curve));
  }

  /// Create a key pair from a JsonWebKey
  static KeyPair? fromJwk(Map<String, dynamic> jwk) {
    switch (jwk['kty']) {
      case 'oct':
        var key = SymmetricKey(keyValue: _base64ToBytes(jwk['k']) as Uint8List);
        return KeyPair(publicKey: key, privateKey: key);
      case 'RSA':
        return KeyPair(
            publicKey: jwk.containsKey('n') && jwk.containsKey('e')
                ? RsaPublicKey(
                    modulus: _base64ToInt(jwk['n']),
                    exponent: _base64ToInt(jwk['e']),
                  )
                : null,
            privateKey: jwk.containsKey('n') &&
                    jwk.containsKey('d') &&
                    jwk.containsKey('p') &&
                    jwk.containsKey('q')
                ? RsaPrivateKey(
                    modulus: _base64ToInt(jwk['n']),
                    privateExponent: _base64ToInt(jwk['d']),
                    firstPrimeFactor: _base64ToInt(jwk['p']),
                    secondPrimeFactor: _base64ToInt(jwk['q']),
                  )
                : null);
      case 'EC':
        final curve = _parseCurve(jwk['crv']);
        return KeyPair(
          privateKey: jwk.containsKey('d') && curve != null
              ? EcPrivateKey(
                  eccPrivateKey: _base64ToInt(jwk['d']),
                  curve: curve,
                )
              : null,
          publicKey:
              jwk.containsKey('x') && jwk.containsKey('y') && curve != null
                  ? EcPublicKey(
                      xCoordinate: _base64ToInt(jwk['x']),
                      yCoordinate: _base64ToInt(jwk['y']),
                      curve: curve,
                    )
                  : null,
        );
    }
    return null;
  }

  /// Creates a [Signer] using the private key and the specified algorithm.
  Signer createSigner(Identifier algorithm) {
    if (privateKey == null) {
      throw StateError('Need a private key to create a signer.');
    }
    return privateKey!.createSigner(algorithm);
  }

  /// Creates a signature [Verifier] using the public key and the specified
  /// algorithm
  Verifier createVerifier(Identifier algorithm) {
    if (publicKey == null) {
      throw StateError('Need a public key to create a verifier.');
    }
    return publicKey!.createVerifier(algorithm);
  }
}

List<int> _base64ToBytes(String encoded) {
  encoded += List.filled((4 - encoded.length % 4) % 4, '=').join();
  return base64Url.decode(encoded);
}

BigInt _base64ToInt(String encoded) {
  final b256 = BigInt.from(256);
  return _base64ToBytes(encoded)
      .fold(BigInt.zero, (a, b) => a * b256 + BigInt.from(b));
}

Identifier? _parseCurve(String name) {
  var v = {
    'P-256': curves.p256,
    'P-256K': curves.p256k,
    'P-384': curves.p384,
    'P-521': curves.p521,
  }[name];
  return v;
}
