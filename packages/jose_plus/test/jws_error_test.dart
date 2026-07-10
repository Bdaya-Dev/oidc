import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  final octKey = JsonWebKey.fromJson({
    'kty': 'oct',
    'k':
        'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
  })!;

  group('JsonWebSignature.fromCompactSerialization', () {
    test('throws when the serialization does not have three parts', () {
      expect(
        () => JsonWebSignature.fromCompactSerialization('only.two'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => JsonWebSignature.fromCompactSerialization('a.b.c.d'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JsonWebSignature.toCompactSerialization', () {
    test('throws for a JWS with multiple signatures', () {
      final jws = JsonWebSignature.fromJson({
        'payload': 'eyJpc3MiOiJqb2UifQ',
        'signatures': [
          {'protected': 'eyJhbGciOiJSUzI1NiJ9', 'signature': 'AAAA'},
          {'protected': 'eyJhbGciOiJFUzI1NiJ9', 'signature': 'BBBB'},
        ],
      });
      expect(() => jws.toCompactSerialization(), throwsStateError);
    });

    test('throws when a recipient has an unprotected header', () {
      final jws = JsonWebSignature.fromJson({
        'payload': 'eyJpc3MiOiJqb2UifQ',
        'protected': 'eyJhbGciOiJFUzI1NiJ9',
        'header': {'kid': 'key-1'},
        'signature': 'AAAA',
      });
      expect(() => jws.toCompactSerialization(), throwsStateError);
    });
  });

  group('JsonWebSignatureBuilder.build', () {
    test('throws when there are no recipients', () {
      final builder = JsonWebSignatureBuilder()..content = 'hello';
      expect(() => builder.build(), throwsStateError);
    });

    test('throws when no payload has been set', () {
      final builder = JsonWebSignatureBuilder()
        ..addRecipient(null, algorithm: 'none');
      expect(() => builder.build(), throwsStateError);
    });

    test(
        'throws when a protected header alg conflicts with the recipient '
        'algorithm', () {
      final builder = JsonWebSignatureBuilder()
        ..content = 'hello'
        ..setProtectedHeader('alg', 'HS512')
        ..addRecipient(octKey, algorithm: 'HS256');
      expect(() => builder.build(), throwsA(isA<ArgumentError>()));
    });

    test(
        'succeeds and produces a verifiable JWS when protected header alg '
        'matches the recipient algorithm', () async {
      final builder = JsonWebSignatureBuilder()
        ..content = 'hello'
        ..setProtectedHeader('alg', 'HS256')
        ..addRecipient(octKey, algorithm: 'HS256');
      final jws = builder.build();

      final keyStore = JsonWebKeyStore()..addKey(octKey);
      final payload = await jws.getPayload(keyStore);
      expect(payload.stringContent, 'hello');
    });
  });

  group('JsonWebSignature.getPayloadFor with alg none', () {
    test('returns the payload only when no key and empty signature', () async {
      final builder = JsonWebSignatureBuilder()
        ..content = 'unsecured'
        ..addRecipient(null, algorithm: 'none');
      final jws = JsonWebSignature.fromCompactSerialization(
          builder.build().toCompactSerialization());

      final keyStore = JsonWebKeyStore();
      final payload =
          await jws.getPayload(keyStore, allowedAlgorithms: ['none']);
      expect(payload.stringContent, 'unsecured');
    });
  });
}
