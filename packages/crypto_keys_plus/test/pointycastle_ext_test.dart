// Targeted tests for `lib/src/pointycastle_ext.dart`. This file is combined
// (not `part of`) into the main `crypto_keys.dart` library and its classes
// are not re-exported from the package's public entrypoints, so it must be
// imported directly by its `src/` path to reach the branches below.
import 'dart:typed_data';

import 'package:crypto_keys_plus/src/pointycastle_ext.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

/// A minimal concrete [BlockCipherWithAuthenticationTag] that does NOT
/// override [BlockCipherWithAuthenticationTag.processBlocks], so calling
/// [BlockCipherWithAuthenticationTag.process] exercises the base-class
/// `processBlocks` loop directly (the only production subclass,
/// `AesCbcAuthenticatedCipherWithHash`, overrides it).
class _IdentityTaggedCipher extends BlockCipherWithAuthenticationTag {
  @override
  String get algorithmName => 'identity-tagged';

  @override
  int get blockSize => 4;

  @override
  int get tagLength => 2;

  @override
  void initParameters(pc.CipherParameters? parameters) {}

  @override
  Uint8List finalizeTag() => Uint8List.fromList([0xaa, 0xbb]);

  @override
  int processBlock(Uint8List inp, int inpOff, Uint8List out, int outOff) {
    // Identity transform: copy up to `blockSize` bytes (or whatever remains)
    // from `inp` at `inpOff` into `out` at `outOff`.
    var n = blockSize;
    if (inpOff + n > inp.length) {
      n = inp.length - inpOff;
    }
    for (var i = 0; i < n; i++) {
      out[outOff + i] = inp[inpOff + i];
    }
    return blockSize;
  }

  @override
  void reset() {}
}

void main() {
  group('toHex', () {
    test('encodes bytes as lowercase two-digit hex, zero-padded', () {
      expect(toHex([0, 255, 16, 1]), '00ff1001');
    });

    test('empty input yields empty string', () {
      expect(toHex(const []), '');
    });
  });

  group('BlockCipherWithAuthenticationTag base processBlocks', () {
    test('encrypting: appends the finalized tag after the ciphertext', () {
      final cipher = _IdentityTaggedCipher();
      cipher.init(
        true,
        ParametersWithIVAndAad(
          pc.KeyParameter(Uint8List(16)),
          Uint8List(12),
          Uint8List(0),
        ),
      );
      final out = cipher.process(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
      // 8 bytes of (identity) ciphertext + the 2-byte tag from finalizeTag().
      expect(out, [1, 2, 3, 4, 5, 6, 7, 8, 0xaa, 0xbb]);
    });

    test('decrypting: strips and verifies the trailing tag', () {
      final cipher = _IdentityTaggedCipher();
      cipher.init(
        false,
        ParametersWithIVAndAad(
          pc.KeyParameter(Uint8List(16)),
          Uint8List(12),
          Uint8List(0),
        ),
      );
      final combined = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 0xaa, 0xbb]);
      expect(cipher.process(combined), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('decrypting: throws when the trailing tag does not match', () {
      final cipher = _IdentityTaggedCipher();
      cipher.init(
        false,
        ParametersWithIVAndAad(
          pc.KeyParameter(Uint8List(16)),
          Uint8List(12),
          Uint8List(0),
        ),
      );
      final tampered = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 0x00, 0x00]);
      expect(() => cipher.process(tampered), throwsA(anything));
    });

    test(
        'processBlocks pads the final partial block by reading past the '
        'declared length', () {
      // Exercises the `inputBlocks` ceil-division branch: 5 bytes over a
      // block size of 4 requires 2 iterations.
      final cipher = _IdentityTaggedCipher();
      cipher.init(
        true,
        ParametersWithIVAndAad(
          pc.KeyParameter(Uint8List(16)),
          Uint8List(12),
          Uint8List(0),
        ),
      );
      final out = cipher.process(Uint8List.fromList([9, 8, 7, 6, 5]));
      expect(out.sublist(0, 5), [9, 8, 7, 6, 5]);
      expect(out.sublist(5), [0xaa, 0xbb]);
    });
  });

  group('AesCbcAuthenticatedCipherWithHash', () {
    test('algorithmName combines the underlying cipher and MAC names', () {
      final cipher =
          AesCbcAuthenticatedCipherWithHash(pc.HMac(pc.SHA256Digest(), 64));
      expect(cipher.algorithmName, 'AES/CBC/PKCS7+SHA-256/HMAC');
    });

    test('blockSize matches the underlying AES-CBC block size', () {
      final cipher =
          AesCbcAuthenticatedCipherWithHash(pc.HMac(pc.SHA256Digest(), 64));
      expect(cipher.blockSize, 16);
    });

    test('processBlock is defensively unimplemented', () {
      final cipher =
          AesCbcAuthenticatedCipherWithHash(pc.HMac(pc.SHA256Digest(), 64));
      expect(
        () => cipher.processBlock(Uint8List(16), 0, Uint8List(16), 0),
        throwsUnsupportedError,
      );
    });

    test('reset is defensively unimplemented', () {
      final cipher =
          AesCbcAuthenticatedCipherWithHash(pc.HMac(pc.SHA256Digest(), 64));
      expect(() => cipher.reset(), throwsUnsupportedError);
    });
  });

  group('AESKeyWrap', () {
    test('processBlock is defensively unimplemented', () {
      final wrap = AESKeyWrap();
      expect(
        () => wrap.processBlock(Uint8List(16), 0, Uint8List(16), 0),
        throwsUnsupportedError,
      );
    });

    test('reset is defensively unimplemented', () {
      final wrap = AESKeyWrap();
      expect(() => wrap.reset(), throwsUnsupportedError);
    });
  });
}
