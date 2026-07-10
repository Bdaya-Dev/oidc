import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  final octKw = JsonWebKey.fromJson({
    'kty': 'oct',
    'alg': 'A128KW',
    'k': 'GawgguFyGrWKav7AX4VKUg',
  })!;

  group('JsonWebEncryption.fromCompactSerialization', () {
    test('throws when the serialization does not have five parts', () {
      expect(
        () => JsonWebEncryption.fromCompactSerialization('a.b.c'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JsonWebEncryption.toCompactSerialization guards', () {
    test('throws when there are multiple recipients', () {
      final key2 = JsonWebKey.fromJson({
        'kty': 'oct',
        'alg': 'A128KW',
        'k': 'AAECAwQFBgcICQoLDA0ODw',
      })!;
      final jwe = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128CBC-HS256'
            ..content = 'multi'
            ..addRecipient(octKw, algorithm: 'A128KW')
            ..addRecipient(key2, algorithm: 'A128KW'))
          .build();
      expect(() => jwe.toCompactSerialization(), throwsStateError);
    });

    test('throws when a shared unprotected header is present', () {
      // Using additionalAuthenticatedData forces the non-compact build path,
      // which produces a shared unprotected header.
      final jwe = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128CBC-HS256'
            ..content = 'aad-forces-json'
            ..additionalAuthenticatedData = utf8.encode('extra')
            ..addRecipient(octKw, algorithm: 'A128KW'))
          .build();
      expect(() => jwe.toCompactSerialization(), throwsStateError);
    });

    test('throws when only a per-recipient unprotected header is present', () {
      // Build a valid compact JWE, then re-serialize it as flattened JSON with
      // a per-recipient `header` (and no shared `unprotected`).
      final dirKey = JsonWebKey.generate('A128CBC-HS256');
      final compact = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128CBC-HS256'
            ..content = 'hi'
            ..addRecipient(dirKey, algorithm: 'dir'))
          .build()
          .toCompactSerialization()
          .split('.');
      final flattened = JsonWebEncryption.fromJson({
        'protected': compact[0],
        'header': {'kid': 'x'},
        'iv': compact[2],
        'ciphertext': compact[3],
        'tag': compact[4],
      });
      expect(() => flattened.toCompactSerialization(), throwsStateError);
    });
  });

  group('JsonWebEncryptionBuilder.build guards', () {
    test('throws when the encryption algorithm is null', () {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = null
        ..content = 'x'
        ..addRecipient(octKw, algorithm: 'A128KW');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when the encryption algorithm is `none`', () {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'none'
        ..content = 'x'
        ..addRecipient(octKw, algorithm: 'A128KW');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when there are no recipients', () {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128CBC-HS256'
        ..content = 'x';
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when no payload has been set', () {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128CBC-HS256'
        ..addRecipient(octKw, algorithm: 'A128KW');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when using `dir` with more than one recipient', () {
      final k1 = JsonWebKey.generate('A128CBC-HS256');
      final k2 = JsonWebKey.generate('A128CBC-HS256');
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128CBC-HS256'
        ..content = 'x'
        ..addRecipient(k1, algorithm: 'dir')
        ..addRecipient(k2, algorithm: 'dir');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when using ECDH-ES direct with more than one recipient', () {
      final k1 = JsonWebKey.generate('ECDH-ES');
      final k2 = JsonWebKey.generate('ECDH-ES');
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..content = 'x'
        ..addRecipient(k1, algorithm: 'ECDH-ES')
        ..addRecipient(k2, algorithm: 'ECDH-ES');
      expect(() => builder.build(), throwsStateError);
    });

    test('throws JoseException for an unsupported compression algorithm', () {
      final dirKey = JsonWebKey.generate('A128CBC-HS256');
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128CBC-HS256'
        ..compressionAlgorithm = 'GZIP'
        ..content = 'x'
        ..addRecipient(dirKey, algorithm: 'dir');
      expect(() => builder.build(), throwsA(isA<JoseException>()));
    });
  });

  group('JsonWebEncryption with DEF compression', () {
    test('round-trips a payload through deflate/inflate', () async {
      final dirKey = JsonWebKey.generate('A128CBC-HS256');
      final payload = 'compress me ' * 20;
      final jwe = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128CBC-HS256'
            ..compressionAlgorithm = 'DEF'
            ..content = payload
            ..addRecipient(dirKey, algorithm: 'dir'))
          .build();

      final parsed = JsonWebEncryption.fromCompactSerialization(
          jwe.toCompactSerialization());
      final keyStore = JsonWebKeyStore()..addKey(dirKey);
      final result = await parsed.getPayload(keyStore);
      expect(result.stringContent, payload);
    });
  });

  group('ECDH-ES decryption error paths', () {
    // Re-encodes a compact JWE after mutating its protected header JSON.
    String withMutatedHeader(
      String compact,
      void Function(Map<String, dynamic>) mutate,
    ) {
      final parts = compact.split('.');
      final header = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))))
          as Map<String, dynamic>;
      mutate(header);
      parts[0] = base64Url
          .encode(utf8.encode(json.encode(header)))
          .replaceAll('=', '');
      return parts.join('.');
    }

    test('fails when the ephemeral public key is missing from the header',
        () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');
      final compact = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128GCM'
            ..content = 'secret'
            ..addRecipient(ecKey, algorithm: 'ECDH-ES'))
          .build()
          .toCompactSerialization();

      final tampered = withMutatedHeader(compact, (h) => h.remove('epk'));
      final parsed = JsonWebEncryption.fromCompactSerialization(tampered);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      // The missing-epk JoseException is swallowed per-recipient; the overall
      // decryption then fails.
      expect(parsed.getPayload(keyStore), throwsA(isA<JoseException>()));
    });

    test('processes apu/apv agreement info during key derivation', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');
      final compact = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128GCM'
            ..content = 'secret'
            ..addRecipient(ecKey, algorithm: 'ECDH-ES'))
          .build()
          .toCompactSerialization();

      // Inject apu/apv that the sender did not use; derivation will run the
      // apu/apv branches and produce a different key, so decryption ultimately
      // fails.
      final tampered = withMutatedHeader(compact, (h) {
        h['apu'] = 'QWxpY2U'; // "Alice"
        h['apv'] = 'Qm9i'; // "Bob"
      });
      final parsed = JsonWebEncryption.fromCompactSerialization(tampered);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      expect(parsed.getPayload(keyStore), throwsA(isA<JoseException>()));
    });
  });

  group('JsonWebEncryption with additional authenticated data', () {
    test('toJson exposes aad and the payload round-trips via JSON', () async {
      final dirKey = JsonWebKey.generate('A128CBC-HS256');
      final payload = 'protected by aad';
      final jwe = (JsonWebEncryptionBuilder()
            ..encryptionAlgorithm = 'A128CBC-HS256'
            ..additionalAuthenticatedData = utf8.encode('bound-data')
            ..content = payload
            ..addRecipient(dirKey, algorithm: 'dir'))
          .build();

      final asJson = jwe.toJson();
      expect(asJson['aad'], isNotNull);

      final parsed = JsonWebEncryption.fromJson(asJson);
      final keyStore = JsonWebKeyStore()..addKey(dirKey);
      final result = await parsed.getPayload(keyStore);
      expect(result.stringContent, payload);
    });
  });
}
