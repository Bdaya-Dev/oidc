/// [JSON Web Algorithms](https://tools.ietf.org/html/rfc7518)
// ignore_for_file: constant_identifier_names

library;

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:jose_plus/jose.dart';
import 'package:jose_plus/src/util.dart';
import 'package:meta/meta.dart';

class JsonWebAlgorithm {
  /// Name of the algorithm as used in the `alg` or `enc` header parameter
  /// values.
  final String name;

  /// The cryptographic algorithm family, such as `RSA` or `EC`.
  final String type;

  /// The intended use of the algorithm.
  ///
  /// Supported values are:
  ///
  /// * `sig` (signature)
  /// * `enc` (encryption)
  /// * `key` (key management)
  final String use;

  /// The minimum bit length of the key
  final int? minKeyBitLength;

  final String? curve;

  const JsonWebAlgorithm(this.name,
      {required this.type,
      required this.use,
      this.minKeyBitLength,
      this.curve});

  static JsonWebAlgorithm getByName(String? name) {
    return allAlgorithms.firstWhere((element) => element.name == name,
        orElse: (() =>
            throw UnsupportedError('Algorithm \'$name\' not supported.')));
  }

  static Iterable<JsonWebAlgorithm> find({
    String? operation,
    String? keyType,
  }) sync* {
    for (var a in allAlgorithms) {
      if (operation != null) {
        if (!a.keyOperations.contains(operation)) continue;
      }
      if (keyType != null) {
        if (a.type != keyType) continue;
      }
      yield a;
    }
  }

  static const List<JsonWebAlgorithm> allAlgorithms = [
    hs256,
    hs384,
    hs512,
    rs256,
    rs384,
    rs512,
    es256,
    es384,
    es512,
    es256k,
    ps256,
    ps384,
    ps512,
    eddsa,
    rsa1_5,
    rsa_oaep,
    rsa_oaep_256,
    a128kw,
    a192kw,
    a256kw,
    ecdh_es,
    ecdh_es_a128kw,
    ecdh_es_a192kw,
    ecdh_es_a256kw,
    a128cbc_hs256,
    a192cbc_hs384,
    a256cbc_hs512,
    a128gcm,
    a192gcm,
    a256gcm,
  ];

  /// HMAC using SHA-256
  static const hs256 =
      JsonWebAlgorithm('HS256', type: 'oct', use: 'sig', minKeyBitLength: 256);

  /// HMAC using SHA-384
  static const hs384 =
      JsonWebAlgorithm('HS384', type: 'oct', use: 'sig', minKeyBitLength: 384);

  /// HMAC using SHA-512
  static const hs512 =
      JsonWebAlgorithm('HS512', type: 'oct', use: 'sig', minKeyBitLength: 512);

  /// RSASSA-PKCS1-v1_5 using SHA-256
  static const rs256 =
      JsonWebAlgorithm('RS256', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// RSASSA-PKCS1-v1_5 using SHA-384
  static const rs384 =
      JsonWebAlgorithm('RS384', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// RSASSA-PKCS1-v1_5 using SHA-512
  static const rs512 =
      JsonWebAlgorithm('RS512', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// ECDSA using P-256 and SHA-256
  static const es256 =
      JsonWebAlgorithm('ES256', type: 'EC', use: 'sig', curve: 'P-256');

  /// ECDSA using P-384 and SHA-384
  static const es384 =
      JsonWebAlgorithm('ES384', type: 'EC', use: 'sig', curve: 'P-384');

  /// ECDSA using P-521 and SHA-512
  static const es512 =
      JsonWebAlgorithm('ES512', type: 'EC', use: 'sig', curve: 'P-521');

  /// ECDSA using P-256 and SHA-256
  static const es256k =
      JsonWebAlgorithm('ES256K', type: 'EC', use: 'sig', curve: 'P-256K');

  /// RSASSA-PSS using SHA-256 and MGF1 with SHA-256
  static const ps256 =
      JsonWebAlgorithm('PS256', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// RSASSA-PSS using SHA-384 and MGF1 with SHA-384
  static const ps384 =
      JsonWebAlgorithm('PS384', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// RSASSA-PSS using SHA-512 and MGF1 with SHA-512
  static const ps512 =
      JsonWebAlgorithm('PS512', type: 'RSA', use: 'sig', minKeyBitLength: 2048);

  /// EdDSA signature algorithms (RFC 8037) using the Ed25519 curve.
  static const eddsa =
      JsonWebAlgorithm('EdDSA', type: 'OKP', use: 'sig', curve: 'Ed25519');

  /// RSAES-PKCS1-v1_5
  static const rsa1_5 = JsonWebAlgorithm('RSA1_5',
      type: 'RSA', use: 'key', minKeyBitLength: 2048);

  /// RSAES OAEP using default parameters
  static const rsa_oaep = JsonWebAlgorithm('RSA-OAEP',
      type: 'RSA', use: 'key', minKeyBitLength: 2048);

  /// RSAES OAEP using SHA-256 and MGF1 with SHA-256
  static const rsa_oaep_256 = JsonWebAlgorithm('RSA-OAEP-256',
      type: 'RSA', use: 'key', minKeyBitLength: 2048);

  /// AES Key Wrap with default initial value using 128-bit key
  static const a128kw =
      JsonWebAlgorithm('A128KW', type: 'oct', use: 'key', minKeyBitLength: 128);

  /// AES Key Wrap with default initial value using 192-bit key
  static const a192kw =
      JsonWebAlgorithm('A192KW', type: 'oct', use: 'key', minKeyBitLength: 192);

  /// AES Key Wrap with default initial value using 256-bit key
  static const a256kw =
      JsonWebAlgorithm('A256KW', type: 'oct', use: 'key', minKeyBitLength: 256);

  /// ECDH-ES using Concat KDF
  static const ecdh_es =
      JsonWebAlgorithm('ECDH-ES', type: 'EC', use: 'key', curve: 'P-256');

  /// ECDH-ES using Concat KDF and A128KW wrapping
  static const ecdh_es_a128kw = JsonWebAlgorithm('ECDH-ES+A128KW',
      type: 'EC', use: 'key', curve: 'P-256');

  /// ECDH-ES using Concat KDF and A192KW wrapping
  static const ecdh_es_a192kw = JsonWebAlgorithm('ECDH-ES+A192KW',
      type: 'EC', use: 'key', curve: 'P-256');

  /// ECDH-ES using Concat KDF and A256KW wrapping
  static const ecdh_es_a256kw = JsonWebAlgorithm('ECDH-ES+A256KW',
      type: 'EC', use: 'key', curve: 'P-256');

  /// AES_128_CBC_HMAC_SHA_256 authenticated encryption algorithm
  static const a128cbc_hs256 = JsonWebAlgorithm('A128CBC-HS256',
      type: 'oct', use: 'enc', minKeyBitLength: 256);

  /// AES_192_CBC_HMAC_SHA_384 authenticated encryption algorithm
  static const a192cbc_hs384 = JsonWebAlgorithm('A192CBC-HS384',
      type: 'oct', use: 'enc', minKeyBitLength: 384);

  /// AES_256_CBC_HMAC_SHA_512 authenticated encryption algorithm
  static const a256cbc_hs512 = JsonWebAlgorithm('A256CBC-HS512',
      type: 'oct', use: 'enc', minKeyBitLength: 512);

  /// AES GCM using 128-bit key
  static const a128gcm = JsonWebAlgorithm('A128GCM',
      type: 'oct', use: 'enc', minKeyBitLength: 128);

  /// AES GCM using 192-bit key
  static const a192gcm = JsonWebAlgorithm('A192GCM',
      type: 'oct', use: 'enc', minKeyBitLength: 192);

  /// AES GCM using 256-bit key
  static const a256gcm = JsonWebAlgorithm('A256GCM',
      type: 'oct', use: 'enc', minKeyBitLength: 256);

  /// The operation(s) that the key is intended to be used for.
  ///
  /// Values defined by the specification are:
  ///
  /// * `sign` (compute digital signature or MAC)
  /// * `verify` (verify digital signature or MAC)
  /// * `encrypt` (encrypt content)
  /// * `decrypt` (decrypt content and validate decryption, if applicable)
  /// * `wrapKey` (encrypt key)
  /// * `unwrapKey` (decrypt key and validate decryption, if applicable)
  /// * `deriveKey` (derive key)
  /// * `deriveBits` (derive bits not to be used as a key)
  ///
  /// Other values MAY be used.
  List<String> get keyOperations {
    switch (use) {
      case 'sig':
        return ['sign', 'verify'];
      case 'key':
        return ['wrapKey', 'unwrapKey'];
      case 'enc':
        return ['encrypt', 'decrypt'];
    }
    throw UnsupportedError('Algorithms for use \'$use\' not supported');
  }

  @visibleForTesting
  JsonWebKey? jwkFromCryptoKeyPair(KeyPair keyPair) {
    return JsonWebKey.fromJson({
      'kty': type,
      if (type == 'oct')
        'k': encodeBase64EncodedBytes(
            (keyPair.publicKey as SymmetricKey).keyValue),
      if (type == 'RSA') ...{
        'n': encodeBigInt((keyPair.publicKey as RsaPublicKey).modulus),
        'e': encodeBigInt((keyPair.publicKey as RsaPublicKey).exponent),
        'd':
            encodeBigInt((keyPair.privateKey as RsaPrivateKey).privateExponent),
        'p': encodeBigInt(
            (keyPair.privateKey as RsaPrivateKey).firstPrimeFactor),
        'q': encodeBigInt(
            (keyPair.privateKey as RsaPrivateKey).secondPrimeFactor),
      },
      if (type == 'EC') ...{
        'd': encodeBigInt((keyPair.privateKey as EcPrivateKey).eccPrivateKey),
        'x': encodeBigInt((keyPair.publicKey as EcPublicKey).xCoordinate),
        'y': encodeBigInt((keyPair.publicKey as EcPublicKey).yCoordinate),
        'crv': curve,
      },
      if (type == 'OKP') ...{
        // RFC 8037 §2: `x`/`d` are base64url of the RAW octet string, not of a
        // big-endian integer like the EC coordinates above.
        'crv': curve,
        'x': encodeBase64EncodedBytes(
            (keyPair.publicKey as OkpPublicKey).rawBytes),
        if (keyPair.privateKey != null)
          'd': encodeBase64EncodedBytes(
              (keyPair.privateKey as OkpPrivateKey).rawBytes),
      },
      'alg': name,
      'use': use,
      'key_ops': keyOperations
    });
  }

  JsonWebKey generateRandomKey({int? keyBitLength}) {
    final res = jwkFromCryptoKeyPair(
      generateCryptoKeyPair(keyBitLength: keyBitLength),
    );
    if (res == null) {
      throw UnimplementedError('Unkown key type.');
    }
    return res;
  }

  @visibleForTesting
  KeyPair generateCryptoKeyPair({int? keyBitLength}) {
    switch (type) {
      case 'oct':
        return KeyPair.generateSymmetric(_getKeyBitLength(keyBitLength));
      case 'RSA':
        return KeyPair.generateRsa(bitStrength: _getKeyBitLength(keyBitLength));
      case 'EC':
        return KeyPair.generateEc(curvesByName[curve!]!);
      case 'OKP':
        return KeyPair.generateEd25519();
    }
    throw UnsupportedError('Algorithms of type \'$type\' not supported');
  }

  int _getKeyBitLength(int? keyBitLength) {
    keyBitLength ??= minKeyBitLength;
    if (keyBitLength! < minKeyBitLength!) {
      throw ArgumentError.value(keyBitLength, 'keyLength',
          'Minimum key length for algorithm $name is $minKeyBitLength');
    }
    return keyBitLength;
  }
}
