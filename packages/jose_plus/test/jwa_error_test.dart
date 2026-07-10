import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JsonWebAlgorithm.getByName', () {
    test('returns the algorithm for a known name', () {
      expect(JsonWebAlgorithm.getByName('HS256'), JsonWebAlgorithm.hs256);
      expect(JsonWebAlgorithm.getByName('RS256').type, 'RSA');
    });

    test('throws UnsupportedError for an unknown name', () {
      expect(
        () => JsonWebAlgorithm.getByName('NOPE-999'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonWebAlgorithm.find', () {
    test('filters by operation', () {
      final signers = JsonWebAlgorithm.find(operation: 'sign').toList();
      expect(signers, isNotEmpty);
      expect(signers.every((a) => a.keyOperations.contains('sign')), isTrue);
    });

    test('filters by key type', () {
      final ecAlgs = JsonWebAlgorithm.find(keyType: 'EC').toList();
      expect(ecAlgs, isNotEmpty);
      expect(ecAlgs.every((a) => a.type == 'EC'), isTrue);
    });

    test('filters by both operation and key type', () {
      final result =
          JsonWebAlgorithm.find(operation: 'sign', keyType: 'RSA').toList();
      expect(result, contains(JsonWebAlgorithm.rs256));
      expect(result, isNot(contains(JsonWebAlgorithm.es256)));
    });
  });

  group('JsonWebAlgorithm.keyOperations', () {
    test('maps each supported use to its operations', () {
      expect(JsonWebAlgorithm.hs256.keyOperations, ['sign', 'verify']);
      expect(JsonWebAlgorithm.a128kw.keyOperations, ['wrapKey', 'unwrapKey']);
      expect(JsonWebAlgorithm.a128gcm.keyOperations, ['encrypt', 'decrypt']);
    });

    test('throws for an unsupported use', () {
      const bogus = JsonWebAlgorithm('X', type: 'oct', use: 'mystery');
      expect(() => bogus.keyOperations, throwsA(isA<UnsupportedError>()));
    });
  });

  group('JsonWebAlgorithm.generateCryptoKeyPair', () {
    test('throws for an unsupported key type', () {
      const bogus = JsonWebAlgorithm('X', type: 'weird-type', use: 'sig');
      expect(
        () => bogus.generateCryptoKeyPair(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonWebAlgorithm key length validation', () {
    test('rejects a key length below the algorithm minimum', () {
      expect(
        () => JsonWebKey.generate('HS256', keyBitLength: 8),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts a key length at or above the minimum', () {
      final key = JsonWebKey.generate('HS256', keyBitLength: 256);
      expect(key.keyType, 'oct');
    });
  });
}
