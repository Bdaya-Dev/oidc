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
