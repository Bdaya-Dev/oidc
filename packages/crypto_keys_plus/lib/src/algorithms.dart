library crypto_keys.algorithms;

import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc; // TODO
import 'package:pointycastle/pointycastle.dart';

import 'pointycastle_ext.dart' as pce;

/// Contains the identifiers for supported algorithms
///
/// ## Encryption algorithms
///
/// ### AES
///
/// - [algorithms.encryption.aes.cbc] AES CBC
/// - [algorithms.encryption.aes.cbcWithHmac] AES CBC with HMAC
/// - [algorithms.encryption.aes.gcm] AES GCM
final algorithms = Algorithms();

class Algorithms {
  /// Contains the identifiers for supported signing algorithms
  final signing = _SigAlgorithms();

  /// Contains the identifiers for supported encryption algorithms
  final encryption = EncAlgorithms();

  /// Contains the identifiers for supported digest algorithms
  final digest = DigestAlgorithms();

  @Deprecated('Use encryption.aes.cbc instead.')
  // ignore: non_constant_identifier_names
  AlgorithmIdentifier get encrypting_aes_cbc => encryption.aes.cbc;

  Algorithms();
}

class DigestAlgorithms extends Identifier {
  DigestAlgorithms() : super._('digest');

  /// SHA-1 digest
  final sha1 = AlgorithmIdentifier._('digest/SHA-1', () => pc.SHA1Digest());

  /// SHA-224 digest
  final sha224 =
      AlgorithmIdentifier._('digest/SHA-224', () => pc.SHA224Digest());

  /// SHA-256 digest
  final sha256 =
      AlgorithmIdentifier._('digest/SHA-256', () => pc.SHA256Digest());

  /// SHA-384 digest
  final sha384 =
      AlgorithmIdentifier._('digest/SHA-384', () => pc.SHA384Digest());

  /// SHA-512 digest
  final sha512 =
      AlgorithmIdentifier._('digest/SHA-512', () => pc.SHA512Digest());

  /// SHA-512/t digest
  AlgorithmIdentifier sha512t(int digestSizeBytes) => AlgorithmIdentifier._(
      'digest/SHA-512/${digestSizeBytes * 8}',
      () => pc.SHA512tDigest(digestSizeBytes));

  /// MD2 digest
  final md2 = AlgorithmIdentifier._('digest/MD2', () => pc.MD2Digest());

  /// MD4 digest
  final md4 = AlgorithmIdentifier._('digest/MD4', () => pc.MD4Digest());

  /// MD5 digest
  final md5 = AlgorithmIdentifier._('digest/MD5', () => pc.MD5Digest());
}

class EncAlgorithms extends Identifier {
  /// Contains the identifiers for supported AES encryption algorithms
  final aes = AesEncAlgorithms();

  /// Contains the identifiers for supported RSA encryption algorithms
  final rsa = _RsaEncAlgorithms();

  /// Contains the identifiers for supported hybrid encryption algorithms
  final hybrid = HybridEncAlgorithms();

  EncAlgorithms() : super._('enc');
}

class HybridEncAlgorithms extends Identifier {
  HybridEncAlgorithms() : super._('enc/hybrid');

  AlgorithmIdentifier withParameters(
      {required keySize,
      required Identifier curve,
      required AlgorithmIdentifier<Digest> hkdfHash}) {
    return AlgorithmIdentifier._(
        'enc/hybrid', () => pc.HKDFKeyDerivator(hkdfHash.factory()));
  }
}

class AesEncAlgorithms extends Identifier {
  /// AES CBC
  final cbc = AlgorithmIdentifier._(
      'enc/AES/CBC/PKCS7',
      () => pc.PaddedBlockCipherImpl(
          pc.PKCS7Padding(), pc.CBCBlockCipher(pc.AESEngine())));

  final cbcWithHmac = AesWithHmacEncAlgorithms();

  /// AES GCM

  final gcm = AlgorithmIdentifier._(
      'enc/AES/GCM', () => pc.GCMBlockCipher(pc.AESEngine()));

  /// AES EAX
  final eax =
      AlgorithmIdentifier._('enc/AES/EAX', () => throw UnimplementedError());

  /// AES Key Wrap with default initial value
  final keyWrap = AlgorithmIdentifier._('enc/AES/KW', () => pce.AESKeyWrap());

  AesEncAlgorithms() : super._('enc/AES');
}

class AesWithHmacEncAlgorithms extends Identifier {
  /// AES_128_CBC_HMAC_SHA_256 authenticated encryption algorithm
  final sha256 = AlgorithmIdentifier._(
      'enc/AES/CBC/PKCS7+HMAC/SHA-256',
      () => pce.AesCbcAuthenticatedCipherWithHash(
          algorithms.signing.hmac.sha256.createAlgorithm()));

  /// AES_192_CBC_HMAC_SHA_384 authenticated encryption algorithm
  final sha384 = AlgorithmIdentifier._(
      'enc/AES/CBC/PKCS7+HMAC/SHA-384',
      () => pce.AesCbcAuthenticatedCipherWithHash(
          algorithms.signing.hmac.sha384.createAlgorithm()));

  /// AES_256_CBC_HMAC_SHA_512 authenticated encryption algorithm
  final sha512 = AlgorithmIdentifier._(
      'enc/AES/CBC/PKCS7+HMAC/SHA-512',
      () => pce.AesCbcAuthenticatedCipherWithHash(
          algorithms.signing.hmac.sha512.createAlgorithm()));

  AesWithHmacEncAlgorithms() : super._('enc/AES/CBC/PKCS7+HMAC');
}

class _RsaEncAlgorithms extends Identifier {
  /// RSAES-PKCS1-v1_5
  final pkcs1 = AlgorithmIdentifier._(
      'enc/RSA/PKCS1', () => pc.PKCS1Encoding(pc.RSAEngine()));

  /// RSAES OAEP using default parameters
  final oaep = AlgorithmIdentifier._('enc/RSA/ECB/OAEPWithSHA-1AndMGF1Padding',
      () => pc.OAEPEncoding.withSHA1(pc.RSAEngine()));

  /// RSAES OAEP using SHA-256 and MGF1 with SHA-256
  final oaep256 = AlgorithmIdentifier._(
      'enc/RSA/ECB/OAEPWithSHA-256AndMGF1Padding',
      () => pc.OAEPEncoding.withSHA256(pc.RSAEngine()));

  _RsaEncAlgorithms() : super._('enc/RSA');
}

class _SigAlgorithms extends Identifier {
  /// Contains the identifiers for supported HMAC signing algorithms
  final hmac = _HmacSigAlgorithms();

  /// Contains the identifiers for supported RSA signing algorithms
  final rsa = _RsaSigAlgorithms();

  /// Contains the identifiers for supported ECDSA signing algorithms
  final ecdsa = _EcdsaSigAlgorithms();

  /// Contains the identifiers for supported EdDSA signing algorithms
  final eddsa = _EddsaSigAlgorithms();

  _SigAlgorithms() : super._('sig');
}

class _HmacSigAlgorithms extends Identifier {
  /// HMAC using SHA-256
  final sha256 = AlgorithmIdentifier._(
      'sig/HMAC/SHA-256', () => pc.HMac(pc.SHA256Digest(), 64));

  /// HMAC using SHA-384
  final sha384 = AlgorithmIdentifier._(
      'sig/HMAC/SHA-384', () => pc.HMac(pc.SHA384Digest(), 128));

  /// HMAC using SHA-512
  final sha512 = AlgorithmIdentifier._(
      'sig/HMAC/SHA-512', () => pc.HMac(pc.SHA512Digest(), 128));

  _HmacSigAlgorithms() : super._('sig/HMAC');
}

class _RsaSigAlgorithms extends Identifier {
  /// RSASSA-PKCS1-v1_5 using SHA-256
  final sha256 = AlgorithmIdentifier._('sig/RSA/SHA-256',
      () => pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201'));

  /// RSASSA-PKCS1-v1_5 using SHA-384
  final sha384 = AlgorithmIdentifier._('sig/RSA/SHA-384',
      () => pc.RSASigner(pc.SHA384Digest(), '0609608648016503040202'));

  /// RSASSA-PKCS1-v1_5 using SHA-512
  final sha512 = AlgorithmIdentifier._('sig/RSA/SHA-512',
      () => pc.RSASigner(pc.SHA512Digest(), '0609608648016503040203'));

  /// Contains the identifiers for supported RSASSA-PSS signing algorithms
  final pss = _RsaPssAlgorithms();

  _RsaSigAlgorithms() : super._('sig/RSA');
}

class _RsaPssAlgorithms extends Identifier {
  _RsaPssAlgorithms() : super._('sig/RSA/PSS');

  /// RSASSA-PSS using SHA-256 and MGF1 with SHA-256 (salt length 32).
  final sha256 = AlgorithmIdentifier._('sig/RSA/PSS/SHA-256',
      () => pc.PSSSigner(pc.RSAEngine(), pc.SHA256Digest(), pc.SHA256Digest()));

  /// RSASSA-PSS using SHA-384 and MGF1 with SHA-384 (salt length 48).
  final sha384 = AlgorithmIdentifier._('sig/RSA/PSS/SHA-384',
      () => pc.PSSSigner(pc.RSAEngine(), pc.SHA384Digest(), pc.SHA384Digest()));

  /// RSASSA-PSS using SHA-512 and MGF1 with SHA-512 (salt length 64).
  final sha512 = AlgorithmIdentifier._('sig/RSA/PSS/SHA-512',
      () => pc.PSSSigner(pc.RSAEngine(), pc.SHA512Digest(), pc.SHA512Digest()));

  /// RSASSA-PSS with an explicit content digest, MGF1 digest and salt length.
  ///
  /// The chosen [saltLength] is encoded into the resulting identifier name (as
  /// a `/salt<N>` suffix) so the signer/verifier can recover it.
  AlgorithmIdentifier withParameters(
      {required AlgorithmIdentifier sigHash,
      required AlgorithmIdentifier mgf1Hash,
      required int saltLength}) {
    return AlgorithmIdentifier._(
        'sig/RSA/PSS/${sigHash.name}/mgf1${mgf1Hash.name}/salt$saltLength',
        () => pc.PSSSigner(pc.RSAEngine(), sigHash.factory() as pc.Digest,
            mgf1Hash.factory() as pc.Digest));
  }
}

/// Placeholder pointycastle [pc.Algorithm] for EdDSA.
///
/// pointycastle has no Ed25519 implementation. The EdDSA signer/verifier
/// (see `eddsa_operator.dart`) bypass pointycastle entirely and never use this
/// instance; it exists only so the generic [Operator] constructor (which eagerly
/// builds a [pc.Algorithm]) has something to hold.
class _Ed25519Algorithm implements pc.Algorithm {
  @override
  String get algorithmName => 'Ed25519';
}

class _EddsaSigAlgorithms extends Identifier {
  _EddsaSigAlgorithms() : super._('sig/EdDSA');

  /// EdDSA using the Ed25519 curve (RFC 8037).
  final ed25519 = AlgorithmIdentifier<pc.Algorithm>._(
      'sig/EdDSA/Ed25519', () => _Ed25519Algorithm());
}

class _EcdsaSigAlgorithms extends Identifier {
  /// ECDSA using P-256 and SHA-256
  final sha256 = AlgorithmIdentifier._(
      'sig/ECDSA/SHA-256', () => pc.ECDSASigner(pc.SHA256Digest(), null));

  /// ECDSA using P-384 and SHA-384
  final sha384 = AlgorithmIdentifier._(
      'sig/ECDSA/SHA-384', () => pc.ECDSASigner(pc.SHA384Digest(), null));

  /// ECDSA using P-521 and SHA-512
  final sha512 = AlgorithmIdentifier._(
      'sig/ECDSA/SHA-512', () => pc.ECDSASigner(pc.SHA512Digest(), null));

  _EcdsaSigAlgorithms() : super._('sig/ECDSA');
}

/// Contains the identifiers for supported cryptographic curves
final curves = _Curves();

class _Curves {
  /// P-256
  final p256 = const Identifier._('curve/P-256');

  /// P-384
  final p384 = const Identifier._('curve/P-384');

  /// P-521
  final p521 = const Identifier._('curve/P-521');

  /// P-256K
  final p256k = const Identifier._('curve/P-256K');

  /// Ed25519 (RFC 8037 / RFC 8032)
  final ed25519 = const Identifier._('curve/Ed25519');
}

/// An identifier for uniquely identify algorithms and other objects
class Identifier {
  final String name;

  const Identifier._(this.name);

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(other) => other is Identifier && other.name == name;
}

class AlgorithmIdentifier<T extends pc.Algorithm> extends Identifier {
  final T Function() factory;

  AlgorithmIdentifier._(String name, this.factory) : super._(name);

  static final _jwaAlgorithms = <String, AlgorithmIdentifier?>{
    // Algorithms for JWS

    /// HMAC using SHA-256
    'HS256': algorithms.signing.hmac.sha256,

    /// HMAC using SHA-384
    'HS384': algorithms.signing.hmac.sha384,

    /// HMAC using SHA-512
    'HS512': algorithms.signing.hmac.sha512,

    /// RSASSA-PKCS1-v1_5 using SHA-256
    'RS256': algorithms.signing.rsa.sha256,

    /// RSASSA-PKCS1-v1_5 using SHA-384
    'RS384': algorithms.signing.rsa.sha384,

    /// RSASSA-PKCS1-v1_5 using SHA-512
    'RS512': algorithms.signing.rsa.sha512,

    /// ECDSA using P-256 and SHA-256
    'ES256': algorithms.signing.ecdsa.sha256,

    /// ECDSA using P-256K and SHA-256
    'ES256K': algorithms.signing.ecdsa.sha256,

    /// ECDSA using P-384 and SHA-384
    'ES384': algorithms.signing.ecdsa.sha384,

    /// ECDSA using P-521 and SHA-512
    'ES512': algorithms.signing.ecdsa.sha512,

    /// RSASSA-PSS using SHA-256 and MGF1 with SHA-256
    'PS256': algorithms.signing.rsa.pss.sha256,

    /// RSASSA-PSS using SHA-384 and MGF1 with SHA-384
    'PS384': algorithms.signing.rsa.pss.sha384,

    /// RSASSA-PSS using SHA-512 and MGF1 with SHA-512
    'PS512': algorithms.signing.rsa.pss.sha512,

    /// EdDSA using Ed25519 (RFC 8037)
    'EdDSA': algorithms.signing.eddsa.ed25519,

    /// The fully-specified Ed25519 algorithm identifier, treated as `EdDSA`.
    'Ed25519': algorithms.signing.eddsa.ed25519,

    /// No digital signature or MAC
    'none': null,

    // Algorithms for JWE
    /// RSAES-PKCS1-v1_5
    'RSA1_5': algorithms.encryption.rsa.pkcs1,

    /// RSAES OAEP using default parameters
    'RSA-OAEP': algorithms.encryption.rsa.oaep,

    /// RSAES OAEP using SHA-256 and MGF1 with SHA-256
    'RSA-OAEP-256': algorithms.encryption.rsa.oaep256,

    /// AES Key Wrap with default initial value using 128-bit key
    'A128KW': algorithms.encryption.aes.keyWrap,

    /// AES Key Wrap with default initial value using 192-bit key
    'A192KW': algorithms.encryption.aes.keyWrap,

    /// AES Key Wrap with default initial value using 256-bit key
    'A256KW': algorithms.encryption.aes.keyWrap,

    /// Direct use of a shared symmetric key as the CEK
    'dir': null,

    /// Elliptic Curve Diffie-Hellman Ephemeral Static key agreement using Concat KDF
    'ECDH-ES': null,

    /// ECDH-ES using Concat KDF and CEK wrapped with 'A128KW'
    'ECDH-ES+A128KW': null,

    /// ECDH-ES using Concat KDF and CEK wrapped with 'A192KW'
    'ECDH-ES+A192KW': null,

    /// ECDH-ES using Concat KDF and CEK wrapped with 'A256KW'
    'ECDH-ES+A256KW': null,

    /// Key wrapping with AES GCM using 128-bit key
    'A128GCMKW': null,

    /// Key wrapping with AES GCM using 192-bit key
    'A192GCMKW': null,

    /// Key wrapping with AES GCM using 256-bit key
    'A256GCMKW': null,

    /// PBES2 with HMAC SHA-256 and 'A128KW' wrapping
    'PBES2-HS256+A128KW': null,

    /// PBES2 with HMAC SHA-384 and 'A192KW' wrapping
    'PBES2-HS384+A192KW': null,

    /// PBES2 with HMAC SHA-512 and 'A256KW' wrapping
    'PBES2-HS512+A256KW': null,

    // Encryption Algorithms for JWE
    /// AES_128_CBC_HMAC_SHA_256 authenticated encryption algorithm
    'A128CBC-HS256': algorithms.encryption.aes.cbcWithHmac.sha256,

    /// AES_192_CBC_HMAC_SHA_384 authenticated encryption algorithm
    'A192CBC-HS384': algorithms.encryption.aes.cbcWithHmac.sha384,

    /// AES_256_CBC_HMAC_SHA_512 authenticated encryption algorithm
    'A256CBC-HS512': algorithms.encryption.aes.cbcWithHmac.sha512,

    /// AES GCM using 128-bit key
    'A128GCM': algorithms.encryption.aes.gcm,

    /// AES GCM using 192-bit key
    'A192GCM': algorithms.encryption.aes.gcm,

    /// AES GCM using 256-bit key
    'A256GCM': algorithms.encryption.aes.gcm,
  };

  static AlgorithmIdentifier? getByJwaName(String alg) {
    var i = _jwaAlgorithms[alg];
    if (i == null && alg != 'none') {
      if (_jwaAlgorithms.containsKey(alg)) {
        throw UnimplementedError("Algorithm '$alg' not implemented");
      }
      throw UnsupportedError("Algorithm '$alg' not supported");
    }
    return i;
  }

  T createAlgorithm() => factory();
}

class DefaultSecureRandom implements pc.SecureRandom {
  final Random random = Random.secure();

  @override
  String get algorithmName => 'dart.math.Random.secure()';

  @override
  BigInt nextBigInteger(int bitLength) {
    return BigInt.parse(
        Iterable.generate(bitLength, (_) => random.nextBool() ? '1' : '0')
            .join(''),
        radix: 2);
  }

  @override
  Uint8List nextBytes(int count) =>
      Uint8List.fromList(List.generate(count, (_) => nextUint8()));

  @override
  int nextUint16() => random.nextInt(256 * 256);

  @override
  int nextUint32() => random.nextInt(256 * 256 * 256 * 256);

  @override
  int nextUint8() => random.nextInt(256);

  @override
  void seed(pc.CipherParameters params) {
    throw UnsupportedError('Seed not supported for this SecureRandom');
  }
}
