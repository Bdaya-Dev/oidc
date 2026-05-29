part of '../crypto_keys.dart';

/// Base class for elliptic curve (EC) keys
abstract class EcKey extends Key {
  /// The cryptographic curve used with the key
  Identifier get curve;
}

/// An elliptic curve (EC) public key
abstract class EcPublicKey extends EcKey implements PublicKey {
  /// The x coordinate for the Elliptic Curve point
  BigInt get xCoordinate;

  /// The y coordinate for the Elliptic Curve point
  BigInt get yCoordinate;

  factory EcPublicKey(
      {required BigInt xCoordinate,
      required BigInt yCoordinate,
      required Identifier curve}) = EcPublicKeyImpl;
}

/// An elliptic curve (EC) private key
abstract class EcPrivateKey extends EcKey implements PrivateKey {
  /// The Elliptic Curve private key value
  BigInt get eccPrivateKey;

  factory EcPrivateKey(
      {required BigInt eccPrivateKey,
      required Identifier curve}) = EcPrivateKeyImpl;
}
