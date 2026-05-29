part of '../crypto_keys.dart';

/// Base class for RSA keys
abstract class RsaKey extends Key {
  /// The modulus value for the RSA key
  BigInt get modulus;
}

/// A RSA public key
abstract class RsaPublicKey extends RsaKey implements PublicKey {
  /// The exponent value for the RSA public key
  BigInt get exponent;

  factory RsaPublicKey({required BigInt modulus, required BigInt exponent}) =
      RsaPublicKeyImpl;
}

/// A RSA private key
abstract class RsaPrivateKey extends RsaKey implements PrivateKey {
  /// The private exponent value for the RSA private key
  BigInt get privateExponent;

  /// The first prime factor
  BigInt get firstPrimeFactor;

  /// The second prime factor
  BigInt get secondPrimeFactor;

  factory RsaPrivateKey(
      {required BigInt privateExponent,
      required BigInt firstPrimeFactor,
      required BigInt secondPrimeFactor,
      required BigInt modulus}) = RsaPrivateKeyImpl;
}
