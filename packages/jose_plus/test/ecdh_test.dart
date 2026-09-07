@Tags(['slow-web-crypto'])
library;

import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('ECDH-ES roundtrip', () {
    late JsonWebKey ecKey;

    setUp(() {
      ecKey = JsonWebKey.generate('ECDH-ES');
    });

    test('ECDH-ES with A128GCM', () async {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'Hello ECDH-ES with A128GCM!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES with A128GCM!');
    });

    test('ECDH-ES with A256GCM', () async {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A256GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'Hello ECDH-ES with A256GCM!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES with A256GCM!');
    });

    test('ECDH-ES with A128CBC-HS256', () async {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128CBC-HS256'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'Hello ECDH-ES with A128CBC-HS256!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES with A128CBC-HS256!');
    });

    test('ECDH-ES with A256CBC-HS512', () async {
      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A256CBC-HS512'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'Hello ECDH-ES with A256CBC-HS512!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES with A256CBC-HS512!');
    });
  });

  group('ECDH-ES+A*KW roundtrip', () {
    test('ECDH-ES+A128KW with A128GCM', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES+A128KW');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES+A128KW')
        ..stringContent = 'Hello ECDH-ES+A128KW!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES+A128KW!');
    });

    test('ECDH-ES+A192KW with A192GCM', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES+A192KW');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A192GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES+A192KW')
        ..stringContent = 'Hello ECDH-ES+A192KW!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES+A192KW!');
    });

    test('ECDH-ES+A256KW with A256CBC-HS512', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES+A256KW');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A256CBC-HS512'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES+A256KW')
        ..stringContent = 'Hello ECDH-ES+A256KW!';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'Hello ECDH-ES+A256KW!');
    });
  });

  group('ECDH-ES with different curves', () {
    for (var entry in {
      'P-256': 'ES256',
      'P-384': 'ES384',
      'P-521': 'ES512',
    }.entries) {
      test('ECDH-ES with ${entry.key} and A128GCM', () async {
        // Generate an EC key pair using the signature algorithm
        final sigKey = JsonWebKey.generate(entry.value);
        final keyJson = Map<String, dynamic>.from(sigKey.toJson());
        keyJson.remove('alg');
        keyJson.remove('use');
        keyJson.remove('key_ops');
        final ecKey = JsonWebKey.fromJson(keyJson)!;

        final builder = JsonWebEncryptionBuilder()
          ..encryptionAlgorithm = 'A128GCM'
          ..addRecipient(ecKey, algorithm: 'ECDH-ES')
          ..stringContent = 'Test with ${entry.key}';

        final jwe = builder.build();
        final compact = jwe.toCompactSerialization();

        final parsed = JsonWebEncryption.fromCompactSerialization(compact);
        final keyStore = JsonWebKeyStore()..addKey(ecKey);
        final payload = await parsed.getPayload(keyStore);
        expect(payload.stringContent, 'Test with ${entry.key}');
      });
    }
  });

  group('ECDH-ES header verification', () {
    test('compact serialization contains epk in header', () {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'test';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final headerPart = compact.split('.')[0];
      final headerJson = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(headerPart))));

      expect(headerJson['alg'], 'ECDH-ES');
      expect(headerJson['enc'], 'A128GCM');
      expect(headerJson['epk'], isNotNull);
      expect(headerJson['epk']['kty'], 'EC');
      expect(headerJson['epk']['crv'], isNotNull);
      expect(headerJson['epk']['x'], isNotNull);
      expect(headerJson['epk']['y'], isNotNull);
      // Ephemeral public key should NOT contain private key
      expect(headerJson['epk']['d'], isNull);
    });

    test('ECDH-ES direct has empty encrypted key', () {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'test';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parts = compact.split('.');
      expect(parts[1], isEmpty);
    });

    test('ECDH-ES+A128KW has non-empty encrypted key', () {
      final ecKey = JsonWebKey.generate('ECDH-ES+A128KW');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES+A128KW')
        ..stringContent = 'test';

      final jwe = builder.build();
      final compact = jwe.toCompactSerialization();

      final parts = compact.split('.');
      expect(parts[1], isNotEmpty);
    });
  });

  group('ECDH-ES with JSON serialization', () {
    test('JWE JSON roundtrip with ECDH-ES', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'JSON serialization test';

      final jwe = builder.build();
      final jsonSerialization = jwe.toJson();

      final parsed = JsonWebEncryption.fromJson(jsonSerialization);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'JSON serialization test');
    });
  });

  group('ECDH-ES in JWT', () {
    test('Encrypted JWT with ECDH-ES', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final claims = JsonWebTokenClaims.fromJson({
        'sub': '1234567890',
        'name': 'John Doe',
        'admin': true,
        'iat': 1516239022,
      });

      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims.toJson()
        ..addRecipient(JsonWebKey.fromJson({'kty': 'oct', 'k': ''})!,
            algorithm: 'none');
      final innerJws = builder.build();

      final jweBuilder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = innerJws.toCompactSerialization();

      final jwe = jweBuilder.build();
      final compact = jwe.toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      final innerContent = payload.stringContent;
      // The decrypted content is the inner JWS compact serialization
      // which contains the base64url-encoded claims
      final jwsParts = innerContent.split('.');
      final claimsJson =
          utf8.decode(base64Url.decode(base64Url.normalize(jwsParts[1])));
      expect(claimsJson, contains('John Doe'));
    });
  });

  group('ECDH-ES with apu/apv (RFC 7518 4.6.1.2/4.6.1.3)', () {
    // `apu`/`apv` are OPTIONAL, but when present in the header they are part
    // of the Concat KDF OtherInfo (PartyUInfo/PartyVInfo, RFC 7518 4.6.2).
    String b64(String s) =>
        base64Url.encode(utf8.encode(s)).replaceAll('=', '');

    Map<String, dynamic> protectedHeaderOf(String compact) => json.decode(utf8
        .decode(base64Url.decode(base64Url.normalize(compact.split('.')[0]))));

    for (final enc in ['A128GCM', 'A256GCM', 'A128CBC-HS256']) {
      test('ECDH-ES roundtrip with apu and apv ($enc)', () async {
        final ecKey = JsonWebKey.generate('ECDH-ES');

        final builder = JsonWebEncryptionBuilder()
          ..encryptionAlgorithm = enc
          ..setProtectedHeader('apu', b64('Alice'))
          ..setProtectedHeader('apv', b64('Bob'))
          ..addRecipient(ecKey, algorithm: 'ECDH-ES')
          ..stringContent = 'agreement info matters';

        final compact = builder.build().toCompactSerialization();

        final parsed = JsonWebEncryption.fromCompactSerialization(compact);
        final keyStore = JsonWebKeyStore()..addKey(ecKey);
        final payload = await parsed.getPayload(keyStore);
        expect(payload.stringContent, 'agreement info matters');
      });
    }

    test('ECDH-ES+A128KW roundtrip with apu and apv', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES+A128KW');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..setProtectedHeader('apu', b64('Alice'))
        ..setProtectedHeader('apv', b64('Bob'))
        ..addRecipient(ecKey, algorithm: 'ECDH-ES+A128KW')
        ..stringContent = 'key wrapping with agreement info';

      final compact = builder.build().toCompactSerialization();

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final keyStore = JsonWebKeyStore()..addKey(ecKey);
      final payload = await parsed.getPayload(keyStore);
      expect(payload.stringContent, 'key wrapping with agreement info');
    });

    test('roundtrip with only apu', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..setProtectedHeader('apu', b64('Alice'))
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'only apu';

      final compact = builder.build().toCompactSerialization();
      final header = protectedHeaderOf(compact);
      expect(header['apu'], b64('Alice'));
      expect(header.containsKey('apv'), isFalse);

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final payload = await parsed.getPayload(JsonWebKeyStore()..addKey(ecKey));
      expect(payload.stringContent, 'only apu');
    });

    test('roundtrip with only apv', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..setProtectedHeader('apv', b64('Bob'))
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'only apv';

      final compact = builder.build().toCompactSerialization();
      final header = protectedHeaderOf(compact);
      expect(header['apv'], b64('Bob'));
      expect(header.containsKey('apu'), isFalse);

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final payload = await parsed.getPayload(JsonWebKeyStore()..addKey(ecKey));
      expect(payload.stringContent, 'only apv');
    });

    test('apu and apv survive into the protected header unchanged', () {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..setProtectedHeader('apu', b64('Alice'))
        ..setProtectedHeader('apv', b64('Bob'))
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'test';

      final compact = builder.build().toCompactSerialization();
      final header = protectedHeaderOf(compact);

      expect(header['apu'], b64('Alice'));
      expect(header['apv'], b64('Bob'));
      expect(utf8.decode(base64Url.decode(base64Url.normalize(header['apu']))),
          'Alice');
      expect(utf8.decode(base64Url.decode(base64Url.normalize(header['apv']))),
          'Bob');
      // apu/apv are integrity protected, never in an unprotected header
      expect(builder.build().toJson().containsKey('unprotected'), isFalse);
    });

    test('apu/apv are honoured on the non-compact path too', () async {
      // Setting `aad` forces the JSON serialization branch, where the
      // protected header is not merged with the per-recipient parameters.
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..additionalAuthenticatedData = utf8.encode('extra aad')
        ..setProtectedHeader('apu', b64('Alice'))
        ..setProtectedHeader('apv', b64('Bob'))
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'non-compact with agreement info';

      final parsed = JsonWebEncryption.fromJson(builder.build().toJson());
      final payload = await parsed.getPayload(JsonWebKeyStore()..addKey(ecKey));
      expect(payload.stringContent, 'non-compact with agreement info');
    });

    test('absent apu/apv keep the previous behaviour', () async {
      final ecKey = JsonWebKey.generate('ECDH-ES');

      final builder = JsonWebEncryptionBuilder()
        ..encryptionAlgorithm = 'A128GCM'
        ..addRecipient(ecKey, algorithm: 'ECDH-ES')
        ..stringContent = 'no agreement info';

      final compact = builder.build().toCompactSerialization();
      final header = protectedHeaderOf(compact);
      expect(header.containsKey('apu'), isFalse);
      expect(header.containsKey('apv'), isFalse);

      final parsed = JsonWebEncryption.fromCompactSerialization(compact);
      final payload = await parsed.getPayload(JsonWebKeyStore()..addKey(ecKey));
      expect(payload.stringContent, 'no agreement info');
    });
  });
}
