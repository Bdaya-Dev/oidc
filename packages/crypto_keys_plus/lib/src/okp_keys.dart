part of '../crypto_keys.dart';

/// Base class for Octet Key Pair (OKP) keys (RFC 8037), such as Ed25519.
///
/// Unlike [RsaKey] or [EcKey], an OKP key is represented by a raw octet string
/// ([rawBytes]) rather than big-endian integers.
abstract class OkpKey extends Key {
  /// The cryptographic curve used with the key, e.g. [curves.ed25519].
  Identifier get curve;

  /// The raw key octet string (RFC 8037 §2).
  ///
  /// For Ed25519 this is the 32-byte public key (for an [OkpPublicKey]) or the
  /// 32-byte private seed (for an [OkpPrivateKey]).
  Uint8List get rawBytes;
}

/// An Octet Key Pair (OKP) public key, e.g. an Ed25519 public key.
abstract class OkpPublicKey extends OkpKey implements PublicKey {
  factory OkpPublicKey({
    required Uint8List rawBytes,
    required Identifier curve,
  }) = OkpPublicKeyImpl;
}

/// An Octet Key Pair (OKP) private key, e.g. an Ed25519 private key.
///
/// For Ed25519, [rawBytes] holds the RFC 8032 32-byte private seed (the JWK
/// `d` parameter), not the expanded private key.
abstract class OkpPrivateKey extends OkpKey implements PrivateKey {
  factory OkpPrivateKey({
    required Uint8List rawBytes,
    required Identifier curve,
  }) = OkpPrivateKeyImpl;
}
