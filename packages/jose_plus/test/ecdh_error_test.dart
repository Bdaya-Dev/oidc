import 'dart:convert';
import 'dart:typed_data';

import 'package:jose_plus/jose.dart';
import 'package:jose_plus/src/ecdh.dart';
import 'package:jose_plus/src/util.dart';
import 'package:test/test.dart';

/// Builds a bare EC JWK (public + private) with only the crypto parameters,
/// stripping the alg/use/key_ops fields that [JsonWebKey.generate] adds.
JsonWebKey _bareEcKey(String sigAlgorithm) {
  final generated = JsonWebKey.generate(sigAlgorithm);
  final jsonKey = Map<String, dynamic>.from(generated.toJson())
    ..remove('alg')
    ..remove('use')
    ..remove('key_ops');
  return JsonWebKey.fromJson(jsonKey)!;
}

void main() {
  group('ecdhKeyDataLen / ecdhAlgorithmId', () {
    test('direct ECDH-ES uses the content encryption algorithm', () {
      expect(ecdhAlgorithmId('ECDH-ES', 'A128GCM'), 'A128GCM');
      expect(ecdhKeyDataLen('ECDH-ES', 'A128GCM'), 128);
      expect(ecdhKeyDataLen('ECDH-ES', 'A256CBC-HS512'), 512);
    });

    test('ECDH-ES+A*KW uses the wrapping algorithm key length', () {
      expect(ecdhAlgorithmId('ECDH-ES+A192KW', 'A128GCM'), 'ECDH-ES+A192KW');
      expect(ecdhKeyDataLen('ECDH-ES+A192KW', 'A128GCM'), 192);
    });

    test('throws for an unsupported content/wrapping algorithm', () {
      expect(
        () => ecdhKeyDataLen('ECDH-ES', 'BOGUS-ENC'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('ecdhEsDerive', () {
    test('throws when the recipient key is not an EC public key', () {
      final rsaKey = JsonWebKey.generate('RS256');
      expect(
        () => ecdhEsDerive(
          recipientPublicKey: rsaKey,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('derives a key and ephemeral public key for a valid EC recipient', () {
      final ecKey = _bareEcKey('ES256');
      final result = ecdhEsDerive(
        recipientPublicKey: ecKey,
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      );
      expect(result.derivedKey, hasLength(16));
      expect(result.ephemeralPublicKey.keyType, 'EC');
      // Sender and recipient derive the same secret.
      final recovered = ecdhEsDecrypt(
        recipientPrivateKey: ecKey,
        ephemeralPublicKey: result.ephemeralPublicKey,
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      );
      expect(recovered, result.derivedKey);
    });
  });

  group('ecdhEsDecrypt', () {
    test('throws when the recipient key has no EC private key', () {
      final rsaKey = JsonWebKey.generate('RS256');
      final ecEphemeral = ecdhEsDerive(
        recipientPublicKey: _bareEcKey('ES256'),
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      ).ephemeralPublicKey;
      expect(
        () => ecdhEsDecrypt(
          recipientPrivateKey: rsaKey,
          ephemeralPublicKey: ecEphemeral,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the ephemeral key is not an EC public key', () {
      final recipient = _bareEcKey('ES256');
      final rsaEphemeral = JsonWebKey.generate('RS256');
      expect(
        () => ecdhEsDecrypt(
          recipientPrivateKey: recipient,
          ephemeralPublicKey: rsaEphemeral,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the ephemeral curve does not match the recipient curve',
        () {
      final recipient = _bareEcKey('ES256'); // P-256
      final ephemeral = ecdhEsDerive(
        recipientPublicKey: _bareEcKey('ES384'), // P-384
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      ).ephemeralPublicKey;
      expect(
        () => ecdhEsDecrypt(
          recipientPrivateKey: recipient,
          ephemeralPublicKey: ephemeral,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the ephemeral point is not on the curve', () {
      final recipient = _bareEcKey('ES256');
      // Take a valid ephemeral key on P-256, then replace its y-coordinate with
      // that of a different P-256 key so the (x, y) pair no longer lies on the
      // curve.
      final validEphemeral = ecdhEsDerive(
        recipientPublicKey: recipient,
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      ).ephemeralPublicKey;
      final otherKey = _bareEcKey('ES256');

      final tamperedJson = Map<String, dynamic>.from(validEphemeral.toJson());
      tamperedJson['y'] = otherKey['y'];
      final tampered = JsonWebKey.fromJson(tamperedJson)!;

      expect(
        () => ecdhEsDecrypt(
          recipientPrivateKey: recipient,
          ephemeralPublicKey: tampered,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ecdhEsDerive with a JWK whose `crv` is not in curvesByName', () {
    test('throws UnsupportedError before any curve arithmetic runs', () {
      // `JsonWebKey.fromKeyPair` (unlike `fromJson`) does not cross-check the
      // JSON `crv` against the crypto_keys `EcPublicKey.curve` it is paired
      // with, so this builds a JWK whose `cryptoKeyPair.publicKey` really is
      // an `EcPublicKey` (passing `ecdhEsDerive`'s initial type check) but
      // whose own `['crv']` is an unrecognized string — reaching
      // `curveId == null` directly, one layer earlier than the P-256K case
      // above (which resolves a curveId but then fails deeper).
      final normal = JsonWebKey.generate('ES256');
      final weirdKey = JsonWebKey.fromKeyPair(
        keyPair: normal.cryptoKeyPair,
        json: {
          'kty': 'EC',
          'crv': 'BOGUS-CURVE',
          'x': normal['x'],
          'y': normal['y'],
        },
      );
      expect(
        () => ecdhEsDerive(
          recipientPublicKey: weirdKey,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          'Unsupported curve: BOGUS-CURVE',
        )),
      );
    });
  });

  group('ecdhEsDerive with a curve unsupported by ECDH-ES key agreement', () {
    test(
        'P-256K passes the curvesByName lookup but fails ECDH parameter '
        'construction', () {
      // `curvesByName` (shared with EC signing) recognizes 'P-256K', so the
      // initial `curveId == null` guard in `ecdhEsDerive` passes — but
      // RFC 7518 §4.6 (and this file's local `_ECCurve` table) only defines
      // ECDH-ES domain parameters for P-256/P-384/P-521, so curve-parameter
      // resolution fails one layer deeper, inside `_ecdhAgreement`.
      final recipient = _bareEcKey('ES256K');
      expect(
        () => ecdhEsDerive(
          recipientPublicKey: recipient,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('Unsupported curve'),
        )),
      );
    });
  });

  group('ecdhEsDecrypt point-at-infinity guard', () {
    test(
        'a zero private scalar produces a point at infinity and throws '
        'StateError', () {
      // Scalar multiplication by 0 short-circuits `_ECPoint.multiply`'s
      // double-and-add loop, returning the infinity point directly —
      // independent of which public key point it would otherwise have been
      // multiplied against.
      final recipient = _bareEcKey('ES256');
      final ephemeral = _bareEcKey('ES256');
      final zeroScalarJson = Map<String, dynamic>.from(recipient.toJson())
        ..['d'] = base64Url.encode([0]).replaceAll('=', '');
      final zeroScalarKey = JsonWebKey.fromJson(zeroScalarJson)!;

      expect(
        () => ecdhEsDecrypt(
          recipientPrivateKey: zeroScalarKey,
          ephemeralPublicKey: ephemeral,
          algorithmId: 'A128GCM',
          keyDataLen: 128,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('point at infinity'),
        )),
      );
    });
  });

  group('_bigIntToBytes short-coordinate padding', () {
    test('a shared secret shorter than the field size is left-zero-padded', () {
      // `_ecdhAgreement`'s result.x is only guaranteed to be < curve.p, not
      // exactly `fieldSize` bytes — its minimal big-endian encoding is one
      // byte short whenever the top byte happens to be zero (~1/256 of
      // random keys). Using random keys per-test-run would make this
      // assertion flaky, so this pins a specific (private, harmless-to-leak)
      // P-256 key pair, found by brute-force search, that deterministically
      // reproduces a 31-byte (not 32-byte) shared secret.
      final recipient = JsonWebKey.fromJson({
        'kty': 'EC',
        'd': 'cgfsVBNkdlzuwDqmg8IwIpzQtkpCZ-kz2mzPnd913uA=',
        'x': 'rWk9DoplEjp_ljpMD_izHRMJ1z9fQJa27GBEKxyDq2c=',
        'y': '-yGzFUeWjY5ZbYdvvc5wQZZQcLBxGtYatrzd0rv6j68=',
        'crv': 'P-256',
      })!;
      final ephemeral = JsonWebKey.fromJson({
        'kty': 'EC',
        'd': 'fUZk1M60Tgr_eHDvuWjxqriDvuikgNT1VGSdLeUUH8w=',
        'x': 'NFCvO3XvAkaqm1XI7dj1filojdyYKAUcv7UeTX34Z1c=',
        'y': 'lw_1QmVG-ovIpEzd0bDc5sKkr1_IJoH3AEmx7x-oRbw=',
        'crv': 'P-256',
      })!;

      final result = ecdhEsDerive(
        recipientPublicKey: recipient,
        algorithmId: 'A128GCM',
        keyDataLen: 128,
        ephemeralKeyPair: ephemeral.cryptoKeyPair,
      );
      // The derived key is still the full requested length regardless of the
      // padding applied to the intermediate shared secret.
      expect(result.derivedKey, hasLength(16));

      // ECDH is symmetric: deriving from the other side with the same two
      // points must reach the identical padding branch and agree on the key.
      final recovered = ecdhEsDecrypt(
        recipientPrivateKey: recipient,
        ephemeralPublicKey: result.ephemeralPublicKey,
        algorithmId: 'A128GCM',
        keyDataLen: 128,
      );
      expect(recovered, result.derivedKey);
    });
  });

  group('AES key wrap helpers', () {
    test('ecdhEsWrapKey rejects a CEK whose length is not a multiple of 8', () {
      // 5-byte "key" -> not a multiple of 8.
      final cek = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'AAAAAAA', // decodes to 5 bytes
      })!;
      expect(
        () => ecdhEsWrapKey(Uint8List(16), cek),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ecdhEsUnwrapKey rejects ciphertext that is too short', () {
      expect(
        () => ecdhEsUnwrapKey(Uint8List(16), [1, 2, 3]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('wrap/unwrap round-trips a 16-byte content key', () {
      final derivedKey = Uint8List.fromList(List.generate(16, (i) => i));
      final cek = JsonWebKey.generate('A128GCM');
      final wrapped = ecdhEsWrapKey(derivedKey, cek);
      final unwrapped = ecdhEsUnwrapKey(derivedKey, wrapped);
      expect(unwrapped, decodeBase64EncodedBytes(cek['k']));
    });
  });
}
