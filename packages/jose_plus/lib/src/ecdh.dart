/// ECDH-ES key agreement per [RFC 7518 §4.6](https://tools.ietf.org/html/rfc7518#section-4.6)
library;

import 'dart:typed_data';

import 'package:crypto_keys_plus/crypto_keys.dart';

import 'jwk.dart';
import 'util.dart';

// ---------------------------------------------------------------------------
// EC point arithmetic for Weierstrass curves  y² = x³ + ax + b  (mod p)
// ---------------------------------------------------------------------------

class _ECPoint {
  final BigInt x;
  final BigInt y;
  final bool isInfinity;

  const _ECPoint(this.x, this.y) : isInfinity = false;
  _ECPoint.infinity()
      : x = BigInt.zero,
        y = BigInt.zero,
        isInfinity = true;

  _ECPoint add(_ECPoint other, BigInt p, BigInt a) {
    if (isInfinity) return other;
    if (other.isInfinity) return this;
    if (x == other.x && y == other.y) return double_(p, a);
    if (x == other.x) return _ECPoint.infinity();

    final lambda = ((other.y - y) * (other.x - x).modInverse(p)) % p;
    final rx = (lambda * lambda - x - other.x) % p;
    final ry = (lambda * (x - rx) - y) % p;
    return _ECPoint(rx, ry);
  }

  _ECPoint double_(BigInt p, BigInt a) {
    if (isInfinity || y == BigInt.zero) return _ECPoint.infinity();

    final lambda =
        ((BigInt.from(3) * x * x + a) * (BigInt.from(2) * y).modInverse(p)) % p;
    final rx = (lambda * lambda - BigInt.from(2) * x) % p;
    final ry = (lambda * (x - rx) - y) % p;
    return _ECPoint(rx, ry);
  }

  /// Scalar multiplication using double-and-add.
  _ECPoint multiply(BigInt k, BigInt p, BigInt a) {
    var result = _ECPoint.infinity();
    var base = this;
    var n = k;
    while (n > BigInt.zero) {
      if (n.isOdd) {
        result = result.add(base, p, a);
      }
      base = base.double_(p, a);
      n >>= 1;
    }
    return result;
  }
}

class _ECCurve {
  final BigInt p;
  final BigInt a;
  final BigInt b;
  final int fieldSize; // in bytes

  const _ECCurve(this.p, this.a, this.b, this.fieldSize);
}

// SEC 2 curve parameters
// https://www.secg.org/sec2-v2.pdf

final _p256 = _ECCurve(
  BigInt.parse(
      'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF',
      radix: 16),
  BigInt.parse(
      'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC',
      radix: 16),
  BigInt.parse(
      '5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B',
      radix: 16),
  32,
);

final _p384 = _ECCurve(
  BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE'
      'FFFFFFFF0000000000000000FFFFFFFF',
      radix: 16),
  BigInt.parse(
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE'
      'FFFFFFFF0000000000000000FFFFFFFC',
      radix: 16),
  BigInt.parse(
      'B3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875A'
      'C656398D8A2ED19D2A85C8EDD3EC2AEF',
      radix: 16),
  48,
);

final _p521 = _ECCurve(
  BigInt.parse(
      '01FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
      'FFFF',
      radix: 16),
  BigInt.parse(
      '01FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
      'FFFC',
      radix: 16),
  BigInt.parse(
      '0051953EB9618E1C9A1F929A21A0B68540EEA2DA725B99B315F3B8B489918EF1'
      '09E156193951EC7E937B1652C0BD3BB1BF073573DF883D2C34F1EF451FD46B50'
      '3F00',
      radix: 16),
  66,
);

_ECCurve _curveForName(String name) {
  switch (name) {
    case 'P-256':
      return _p256;
    case 'P-384':
      return _p384;
    case 'P-521':
      return _p521;
    default:
      throw UnsupportedError('Unsupported curve: $name');
  }
}

/// Returns the key length in bits for a content/wrapping algorithm.
int _keyLengthForAlgorithm(String algorithm) {
  switch (algorithm) {
    case 'A128CBC-HS256':
      return 256;
    case 'A192CBC-HS384':
      return 384;
    case 'A256CBC-HS512':
      return 512;
    case 'A128GCM':
      return 128;
    case 'A192GCM':
      return 192;
    case 'A256GCM':
      return 256;
    case 'A128KW':
      return 128;
    case 'A192KW':
      return 192;
    case 'A256KW':
      return 256;
    default:
      throw UnsupportedError('Unsupported algorithm: $algorithm');
  }
}

// ---------------------------------------------------------------------------
// ECDH shared secret  Z = x(d · Q)
// ---------------------------------------------------------------------------

BigInt _ecdhAgreement(EcPrivateKey privateKey, EcPublicKey publicKey) {
  final curveName = privateKey.curve.name.split('/').last;
  final curve = _curveForName(curveName);

  final q = _ECPoint(publicKey.xCoordinate, publicKey.yCoordinate);

  // Validate that the public key point lies on the curve: y² ≡ x³ + ax + b (mod p)
  final lhs = (q.y * q.y) % curve.p;
  final rhs = (q.x * q.x * q.x + curve.a * q.x + curve.b) % curve.p;
  if (lhs != rhs) {
    throw ArgumentError('Public key point is not on the curve');
  }

  final result = q.multiply(privateKey.eccPrivateKey, curve.p, curve.a);

  if (result.isInfinity) {
    throw StateError('ECDH produced point at infinity');
  }
  return result.x;
}

int _fieldSizeForCurve(String curveName) => _curveForName(curveName).fieldSize;

// ---------------------------------------------------------------------------
// Concat KDF  (NIST SP 800-56A, RFC 7518 §4.6.2)
// ---------------------------------------------------------------------------

Uint8List concatKdf(
  Uint8List sharedSecret, {
  required int keyDataLen,
  required String algorithmId,
  Uint8List? apu,
  Uint8List? apv,
}) {
  final keyDataBytes = keyDataLen ~/ 8;
  final hashLen = 32; // SHA-256
  final reps = (keyDataBytes + hashLen - 1) ~/ hashLen;

  final result = BytesBuilder();

  for (var counter = 1; counter <= reps; counter++) {
    final input = BytesBuilder();

    // counter (32-bit big-endian)
    input.add(_int32BigEndian(counter));

    // Z
    input.add(sharedSecret);

    // AlgorithmID
    final algIdBytes = Uint8List.fromList(algorithmId.codeUnits);
    input.add(_int32BigEndian(algIdBytes.length));
    input.add(algIdBytes);

    // PartyUInfo
    final apuBytes = apu ?? Uint8List(0);
    input.add(_int32BigEndian(apuBytes.length));
    if (apuBytes.isNotEmpty) input.add(apuBytes);

    // PartyVInfo
    final apvBytes = apv ?? Uint8List(0);
    input.add(_int32BigEndian(apvBytes.length));
    if (apvBytes.isNotEmpty) input.add(apvBytes);

    // SuppPubInfo
    input.add(_int32BigEndian(keyDataLen));

    final inputBytes = Uint8List.fromList(input.takeBytes());
    final digest = algorithms.digest.sha256.createAlgorithm();
    digest.update(inputBytes, 0, inputBytes.length);
    final hash = Uint8List(digest.digestSize);
    digest.doFinal(hash, 0);
    result.add(hash);
  }

  return Uint8List.fromList(result.takeBytes().sublist(0, keyDataBytes));
}

Uint8List _int32BigEndian(int value) {
  final bytes = Uint8List(4);
  ByteData.view(bytes.buffer).setUint32(0, value, Endian.big);
  return bytes;
}

Uint8List _bigIntToBytes(BigInt value, int fieldSize) {
  var hex = value.toRadixString(16);
  if (hex.length % 2 != 0) hex = '0$hex';
  final raw = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < raw.length; i++) {
    raw[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  if (raw.length > fieldSize) {
    throw StateError(
        'EC coordinate exceeds field size: ${raw.length} > $fieldSize');
  }
  if (raw.length < fieldSize) {
    final padded = Uint8List(fieldSize);
    padded.setRange(fieldSize - raw.length, fieldSize, raw);
    return padded;
  }
  return raw;
}

// ---------------------------------------------------------------------------
// AES Key Wrap / Unwrap  (RFC 3394)
// ---------------------------------------------------------------------------

Uint8List _aesKeyWrap(Uint8List kek, Uint8List plaintext) {
  if (plaintext.length % 8 != 0) {
    throw ArgumentError('Plaintext length must be a multiple of 8 bytes');
  }

  final wrapper = SymmetricKey(keyValue: kek)
      .createEncrypter(algorithms.encryption.aes.keyWrap);
  return Uint8List.fromList(wrapper.encrypt(plaintext).data);
}

Uint8List _aesKeyUnwrap(Uint8List kek, Uint8List ciphertext) {
  if (ciphertext.length % 8 != 0 || ciphertext.length < 24) {
    throw ArgumentError(
        'Ciphertext length must be at least 24 and a multiple of 8 bytes');
  }

  final wrapper = SymmetricKey(keyValue: kek)
      .createEncrypter(algorithms.encryption.aes.keyWrap);
  return Uint8List.fromList(wrapper.decrypt(EncryptionResult(ciphertext)));
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class EcdhEsResult {
  final Uint8List derivedKey;
  final JsonWebKey ephemeralPublicKey;

  EcdhEsResult({required this.derivedKey, required this.ephemeralPublicKey});
}

/// Sender side: generate ephemeral key, perform ECDH, derive key material.
EcdhEsResult ecdhEsDerive({
  required JsonWebKey recipientPublicKey,
  required String algorithmId,
  required int keyDataLen,
  Uint8List? apu,
  Uint8List? apv,
  KeyPair? ephemeralKeyPair,
}) {
  final recipientPublic = recipientPublicKey.cryptoKeyPair.publicKey;
  if (recipientPublic is! EcPublicKey) {
    throw ArgumentError('Recipient key must be an EC public key');
  }

  final curveName = recipientPublicKey['crv'] as String;
  final curveId = curvesByName[curveName];
  if (curveId == null) {
    throw UnsupportedError('Unsupported curve: $curveName');
  }

  final ephemeral = ephemeralKeyPair ?? KeyPair.generateEc(curveId);
  final ephemeralPrivate = ephemeral.privateKey as EcPrivateKey;
  final ephemeralPublic = ephemeral.publicKey as EcPublicKey;

  final z = _ecdhAgreement(ephemeralPrivate, recipientPublic);
  final fieldSize = _fieldSizeForCurve(curveName);
  final zBytes = _bigIntToBytes(z, fieldSize);

  final derivedKey = concatKdf(
    zBytes,
    keyDataLen: keyDataLen,
    algorithmId: algorithmId,
    apu: apu,
    apv: apv,
  );

  final epk = JsonWebKey.fromCryptoKeys(publicKey: ephemeralPublic);

  return EcdhEsResult(derivedKey: derivedKey, ephemeralPublicKey: epk);
}

/// Recipient side: use private key + EPK to derive key material.
Uint8List ecdhEsDecrypt({
  required JsonWebKey recipientPrivateKey,
  required JsonWebKey ephemeralPublicKey,
  required String algorithmId,
  required int keyDataLen,
  Uint8List? apu,
  Uint8List? apv,
}) {
  final recipientPrivate = recipientPrivateKey.cryptoKeyPair.privateKey;
  if (recipientPrivate is! EcPrivateKey) {
    throw ArgumentError('Recipient key must have an EC private key');
  }

  final ephemeralPublic = ephemeralPublicKey.cryptoKeyPair.publicKey;
  if (ephemeralPublic is! EcPublicKey) {
    throw ArgumentError('Ephemeral key must be an EC public key');
  }

  // Verify curve of EPK matches recipient key
  final recipientCurve = recipientPrivateKey['crv'] as String;
  final ephemeralCurve = ephemeralPublicKey['crv'] as String;
  if (recipientCurve != ephemeralCurve) {
    throw ArgumentError('Ephemeral key curve ($ephemeralCurve) does not match '
        'recipient key curve ($recipientCurve)');
  }

  final z = _ecdhAgreement(recipientPrivate, ephemeralPublic);
  final curveName = recipientCurve;
  final fieldSize = _fieldSizeForCurve(curveName);
  final zBytes = _bigIntToBytes(z, fieldSize);

  return concatKdf(
    zBytes,
    keyDataLen: keyDataLen,
    algorithmId: algorithmId,
    apu: apu,
    apv: apv,
  );
}

// ---------------------------------------------------------------------------
// Algorithm helpers
// ---------------------------------------------------------------------------

String ecdhAlgorithmId(String algorithm, String encAlgorithm) {
  if (algorithm == 'ECDH-ES') return encAlgorithm;
  return algorithm;
}

int ecdhKeyDataLen(String algorithm, String encAlgorithm) {
  if (algorithm == 'ECDH-ES') return _keyLengthForAlgorithm(encAlgorithm);
  final wrapAlg = algorithm.substring('ECDH-ES+'.length);
  return _keyLengthForAlgorithm(wrapAlg);
}

List<int> ecdhEsWrapKey(Uint8List derivedKey, JsonWebKey cek) {
  final cekBytes = Uint8List.fromList(decodeBase64EncodedBytes(cek['k']));
  return _aesKeyWrap(derivedKey, cekBytes);
}

Uint8List ecdhEsUnwrapKey(Uint8List derivedKey, List<int> encryptedKey) {
  return _aesKeyUnwrap(derivedKey, Uint8List.fromList(encryptedKey));
}
