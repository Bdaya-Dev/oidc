// Targets the defensive "unexpected/unknown key type" fallback branches in
// `_AsymmetricOperator` (asymmetric_operator.dart) and `DefaultSecureRandom`
// (algorithms.dart), both of which are unreachable through the package's
// normal key-generation/JWK-parsing surface and require directly
// implementing the `Key`/`PrivateKey`/`PublicKey`/`EcKey` mixins to reach.
import 'dart:typed_data';

import 'package:crypto_keys_plus/crypto_keys.dart';
// DefaultSecureRandom is intentionally not part of the public `show` list on
// the `crypto_keys.dart` export, so it must be reached via its `src/` path.
import 'package:crypto_keys_plus/src/algorithms.dart' show DefaultSecureRandom;
import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

/// An `EcKey` that is deliberately neither an `EcPrivateKey` nor an
/// `EcPublicKey`. `EcKey` is a plain (non-sealed) abstract class, so this is
/// a legitimate way to reach `_AsymmetricOperator.keyParameter`'s final
/// `throw StateError('Unexpected key type $key')`: the getter always
/// computes `ecDomainParameters` (which only requires `key is EcKey`) before
/// checking for the two concrete EC subtypes.
class _EcKeyOfUnknownKind extends EcKey with PrivateKey {
  @override
  Identifier get curve => curves.p256;
}

/// A `PublicKey` that is neither a `SymmetricKey`, an `OkpPublicKey`, nor an
/// `EcKey`/`RsaKey`. Reaches `_AsymmetricVerifier.verify`'s final
/// `throw UnsupportedError('Unknown key type $key')`, which — unlike the
/// signer's equivalent branch — is checked only inside the `RsaKey`/`EcKey`
/// `if` branches, so no cast happens first for a key of neither kind.
class _NeitherRsaNorEcPublicKey with Key, PublicKey {}

void main() {
  group('_AsymmetricOperator.keyParameter unexpected-key-type branch', () {
    test(
        'signing with an EcKey that is neither EcPrivateKey nor EcPublicKey '
        'throws StateError', () {
      final key = _EcKeyOfUnknownKind();
      final signer = key.createSigner(algorithms.signing.ecdsa.sha256);
      expect(
        () => signer.sign(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unexpected key type'),
        )),
      );
    });
  });

  group('_AsymmetricVerifier.verify unknown-key-type branch', () {
    test(
        'verifying with a key that is neither RsaKey nor EcKey throws '
        'UnsupportedError without ever computing keyParameter', () {
      final key = _NeitherRsaNorEcPublicKey();
      final verifier = key.createVerifier(algorithms.signing.ecdsa.sha256);
      expect(
        () => verifier.verify(
          Uint8List.fromList([1, 2, 3]),
          Signature(Uint8List.fromList([0])),
        ),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('Unknown key type'),
        )),
      );
    });
  });

  group('DefaultSecureRandom', () {
    // Not exported from the public `crypto_keys.dart` barrel, but every
    // asymmetric key-generation and encryption path in the library routes
    // through it, so its full `pc.SecureRandom` surface (including the
    // members pointycastle's own call sites never happen to use) is part of
    // the documented contract via `implements pc.SecureRandom`.
    test('algorithmName reports the underlying dart:math source', () {
      expect(
        DefaultSecureRandom().algorithmName,
        'dart.math.Random.secure()',
      );
    });

    test('nextUint16 stays within the 16-bit range', () {
      final random = DefaultSecureRandom();
      for (var i = 0; i < 50; i++) {
        final v = random.nextUint16();
        expect(v, inInclusiveRange(0, 0xffff));
      }
    });

    test('nextUint32 stays within the 32-bit range', () {
      final random = DefaultSecureRandom();
      for (var i = 0; i < 50; i++) {
        final v = random.nextUint32();
        expect(v, inInclusiveRange(0, 0xffffffff));
      }
    });

    test('seed is unsupported', () {
      expect(
        () => DefaultSecureRandom().seed(pc.KeyParameter(Uint8List(1))),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('Seed not supported'),
        )),
      );
    });
  });
}
