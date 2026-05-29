part of '../crypto_keys.dart';

/// A symmetric key
abstract class SymmetricKey extends Key with PublicKey, PrivateKey {
  /// The value of the symmetric (or other single-valued) key
  Uint8List get keyValue;

  factory SymmetricKey({required Uint8List keyValue}) = SymmetricKeyImpl;

  factory SymmetricKey.generate(int bitLength) {
    if (bitLength % 8 != 0) {
      throw ArgumentError(
          'Illegal bit length $bitLength, should be mutiple of 8.');
    }
    var value = DefaultSecureRandom().nextBytes(bitLength ~/ 8);
    return SymmetricKey(keyValue: value);
  }
}
