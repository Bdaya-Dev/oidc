import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JoseHeader', () {
    test('exposes header parameters', () {
      final header = JoseHeader.fromJson({
        'alg': 'RS256',
        'jku': 'https://example.com/keys.json',
        'kid': 'key-1',
        'typ': 'JWT',
        'cty': 'example',
        'enc': 'A128GCM',
        'zip': 'DEF',
        'apu': 'dGVzdA',
        'apv': 'dGVzdA',
      });

      expect(header.algorithm, 'RS256');
      expect(header.jwkSetUrl, Uri.parse('https://example.com/keys.json'));
      expect(header.keyId, 'key-1');
      expect(header.type, 'JWT');
      expect(header.contentType, 'example');
      expect(header.encryptionAlgorithm, 'A128GCM');
      expect(header.compressionAlgorithm, 'DEF');
      expect(header.agreementPartyUInfo, 'dGVzdA');
      expect(header.agreementPartyVInfo, 'dGVzdA');
    });

    test('parses an embedded jwk header parameter', () {
      final header = JoseHeader.fromJson({
        'alg': 'ES256',
        'jwk': {
          'kty': 'EC',
          'crv': 'P-256',
          'x': 'f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU',
          'y': 'x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0',
        },
      });

      final jwk = header.jsonWebKey;
      expect(jwk, isNotNull);
      expect(jwk!.keyType, 'EC');
    });

    test('fromBase64EncodedString decodes an encoded header', () {
      final encoded = base64Url
          .encode(utf8.encode(json.encode({'alg': 'HS256'})))
          .replaceAll('=', '');
      final header = JoseHeader.fromBase64EncodedString(encoded);
      expect(header.algorithm, 'HS256');
    });
  });

  group('JoseObject.fromJson', () {
    test('builds a JsonWebSignature from a payload-bearing map', () {
      final obj = JoseObject.fromJson({
        'payload': 'eyJpc3MiOiJqb2UifQ',
        'protected': 'eyJhbGciOiJub25lIn0',
        'signature': '',
      });
      expect(obj, isA<JsonWebSignature>());
    });

    test('builds a JsonWebEncryption from a ciphertext-bearing map', () {
      final obj = JoseObject.fromJson({
        'protected': 'eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4R0NNIn0',
        'iv': 'AAAAAAAAAAAAAAAA',
        'ciphertext': 'AAAA',
        'tag': 'AAAAAAAAAAAAAAAAAAAAAA',
      });
      expect(obj, isA<JsonWebEncryption>());
    });

    test('throws for a map that is neither JWS nor JWE', () {
      expect(
        () => JoseObject.fromJson({'foo': 'bar'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JoseObject.fromCompactSerialization', () {
    test('dispatches to JWS for 3-part serializations', () {
      const jws = 'eyJhbGciOiJub25lIn0.eyJpc3MiOiJqb2UifQ.';
      expect(JoseObject.fromCompactSerialization(jws), isA<JsonWebSignature>());
    });

    test('throws for an invalid number of parts', () {
      expect(
        () => JoseObject.fromCompactSerialization('only.two'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => JoseObject.fromCompactSerialization('a.b.c.d'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JoseObject.commonProtectedHeader', () {
    test('contains protected parameters shared across signatures', () {
      // A general JSON serialization with two signatures both protecting
      // the same `alg`.
      final jws = JsonWebSignature.fromJson({
        'payload': 'eyJpc3MiOiJqb2UifQ',
        'signatures': [
          {'protected': 'eyJhbGciOiJSUzI1NiJ9', 'signature': 'AAAA'},
          {'protected': 'eyJhbGciOiJSUzI1NiJ9', 'signature': 'BBBB'},
        ],
      });

      expect(jws.commonProtectedHeader.algorithm, 'RS256');
    });
  });

  group('JoseObjectBuilder', () {
    test('content setter accepts a byte list payload', () {
      final builder = JsonWebSignatureBuilder()..content = <int>[1, 2, 3];
      expect(builder.payload!.data, [1, 2, 3]);
    });

    test('content setter accepts a String payload', () {
      final builder = JsonWebSignatureBuilder()..content = 'hi';
      expect(utf8.decode(builder.payload!.data), 'hi');
    });

    test('content setter accepts a JSON payload', () {
      final builder = JsonWebSignatureBuilder()..content = {'a': 1};
      expect(json.decode(utf8.decode(builder.payload!.data)), {'a': 1});
    });

    test('mediaType getter and setter round-trip through the cty header', () {
      final builder = JsonWebSignatureBuilder()..mediaType = 'JWT';
      expect(builder.mediaType, 'JWT');
      expect(builder.protectedHeader['cty'], 'JWT');
    });

    test('payload is null until content is set', () {
      expect(JsonWebSignatureBuilder().payload, isNull);
    });
  });

  group('JoseException', () {
    test('toString includes the message', () {
      final e = JoseException('something went wrong');
      expect(e.message, 'something went wrong');
      expect(e.toString(), 'JoseException: something went wrong');
    });
  });
}
