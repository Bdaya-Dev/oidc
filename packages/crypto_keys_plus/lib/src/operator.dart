part of '../crypto_keys.dart';

/// Base class for cryptographic operations
abstract class Operator<T extends Key> {
  /// The key used for this operation
  final T key;

  /// The algorithm used for this operation
  final AlgorithmIdentifier algorithm;

  final pc.Algorithm _algorithm;

  Operator._(this.algorithm, this.key)
      : _algorithm = algorithm.createAlgorithm();
}

/// Operator for signing
abstract class Signer<T extends PrivateKey> extends Operator<T> {
  Signer._(Identifier algorithm, T key)
      : super._(algorithm as AlgorithmIdentifier<pc.Algorithm>, key);

  /// Signs the input [data] using the [key] and [algorithm]
  Signature sign(List<int> data);
}

/// Operator for verifying a signature
abstract class Verifier<T extends PublicKey> extends Operator<T> {
  Verifier._(Identifier algorithm, T key)
      : super._(algorithm as AlgorithmIdentifier<pc.Algorithm>, key);

  /// Verifies that [signature] is a valid signature for the input [data] using
  /// the [key] and [algorithm]
  bool verify(Uint8List data, Signature signature);
}

/// Represents the result of signing some data
abstract class Signature {
  /// Byte representation of the signature
  Uint8List get data;

  factory Signature(Uint8List data) = SignatureImpl;
}

/// Operator for encrypting and decrypting data
abstract class Encrypter<T extends Key> extends Operator<T> {
  Encrypter._(Identifier algorithm, T key)
      : super._(algorithm as AlgorithmIdentifier<pc.Algorithm>, key);

  /// Encrypts the input data using the [key] and [algorithm]
  ///
  /// When the algorithm requires an initialization vector and none is provided,
  /// a random initialization vector is generated.
  EncryptionResult encrypt(Uint8List input,
      {Uint8List? initializationVector,
      Uint8List? additionalAuthenticatedData});

  /// Decrypts the input data using the [key] and [algorithm]
  Uint8List decrypt(EncryptionResult input);
}

/// Represents the result of encrypting some data
abstract class EncryptionResult {
  /// Byte representation of the ciphertext
  Uint8List get data;

  /// The initialization vector used for encrypting when required by the
  /// algorithm
  Uint8List? get initializationVector;

  Uint8List? get authenticationTag;

  Uint8List? get additionalAuthenticatedData;

  factory EncryptionResult(Uint8List data,
      {Uint8List? initializationVector,
      Uint8List? authenticationTag,
      Uint8List? additionalAuthenticatedData}) = EncryptionResultImpl;
}
