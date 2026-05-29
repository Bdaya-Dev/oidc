part of '../crypto_keys.dart';

class _SymmetricSignerAndVerifier extends Signer<SymmetricKey>
    implements Verifier<SymmetricKey> {
  _SymmetricSignerAndVerifier(Identifier algorithm, SymmetricKey key)
      : super._(algorithm, key);

  @override
  pc.Mac get _algorithm => super._algorithm as pc.Mac;

  @override
  Signature sign(List<int> data) {
    data = data is Uint8List ? data : Uint8List.fromList(data);
    _algorithm.init(pc.KeyParameter(key.keyValue));
    return Signature(_algorithm.process(data));
  }

  @override
  bool verify(Uint8List data, Signature signature) => sign(data) == signature;
}

class _SymmetricEncrypter extends Encrypter<SymmetricKey> {
  _SymmetricEncrypter(Identifier algorithm, SymmetricKey key)
      : super._(algorithm, key);

  @override
  pc.BlockCipher get _algorithm => super._algorithm as pc.BlockCipher;

  pc.CipherParameters _getParams(
      Uint8List? initializationVector, Uint8List? additionalAuthenticatedData) {
    var keyParam = pc.KeyParameter(key.keyValue);

    if (_algorithm is pc.AESKeyWrap) return keyParam;
    if (_algorithm is pc.GCMBlockCipher) {
      return pc.AEADParameters(keyParam, 128, initializationVector!,
          additionalAuthenticatedData ?? Uint8List(0));
    }

    var paramsWithIV = pc.ParametersWithIVAndAad(keyParam,
        initializationVector!, additionalAuthenticatedData ?? Uint8List(0));

    if (_algorithm is pc.PaddedBlockCipher) {
      return pc.PaddedBlockCipherParameters(paramsWithIV, null);
    }

    return paramsWithIV;
  }

  @override
  Uint8List decrypt(EncryptionResult input) {
    _algorithm.init(
        false,
        _getParams(
            input.initializationVector, input.additionalAuthenticatedData));
    var data = input.data;
    if (input.authenticationTag != null) {
      data = Uint8List(data.length + input.authenticationTag!.length);
      data.setAll(0, input.data);
      data.setAll(input.data.length, input.authenticationTag!);
    }
    return _algorithm.process(data);
  }

  @override
  EncryptionResult encrypt(Uint8List input,
      {Uint8List? initializationVector,
      Uint8List? additionalAuthenticatedData}) {
    initializationVector ??=
        DefaultSecureRandom().nextBytes(_algorithm.blockSize);

    _algorithm.init(
        true, _getParams(initializationVector, additionalAuthenticatedData));
    var r = _algorithm.process(input);
    Uint8List? tag;
    if (_algorithm is pc.GCMBlockCipher) {
      var tagLength = 16;
      tag = Uint8List.view(
          r.buffer, r.offsetInBytes + r.length - tagLength, tagLength);
      r = Uint8List.view(r.buffer, r.offsetInBytes, r.length - tagLength);
    }
    if (_algorithm is pc.BlockCipherWithAuthenticationTag) {
      var tagLength =
          (_algorithm as pc.BlockCipherWithAuthenticationTag).tagLength;
      tag = Uint8List.view(
          r.buffer, r.offsetInBytes + r.length - tagLength, tagLength);
      r = Uint8List.view(r.buffer, r.offsetInBytes, r.length - tagLength);
    }

    return EncryptionResult(r,
        initializationVector:
            _algorithm is pc.AESKeyWrap ? null : initializationVector,
        additionalAuthenticatedData: additionalAuthenticatedData,
        authenticationTag: tag);
  }
}
