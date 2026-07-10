import 'package:jose_plus/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('JsonObject', () {
    test('equality and hashCode are based on encoded content', () {
      final a = JsonObject.from({'a': 1, 'b': 'two'});
      final b = JsonObject.from({'a': 1, 'b': 'two'});
      final c = JsonObject.from({'a': 2, 'b': 'two'});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      // Comparing against a non-JsonObject value returns false.
      final Object other = 'not a json object';
      expect(a == other, isFalse);
    });

    test('toString reflects the underlying map', () {
      final o = JsonObject.from({'x': 1});
      expect(o.toString(), '{x: 1}');
    });

    test('toBytes round-trips through the base64 encoding', () {
      final o = JsonObject.from({'hello': 'world'});
      final decoded = JsonObject.fromBytes(o.toBytes());
      expect(decoded, equals(o));
      expect(decoded['hello'], 'world');
    });

    test('from() rejects values that are not valid JSON', () {
      expect(
        () => JsonObject.from({'bad': DateTime.now()}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getTyped converts Uri values', () {
      final o = JsonObject.from({'u': 'https://example.com/path'});
      expect(o.getTyped<Uri>('u'), Uri.parse('https://example.com/path'));
    });

    test('getTyped converts Duration values from seconds', () {
      final o = JsonObject.from({'d': 90});
      expect(o.getTyped<Duration>('d'), const Duration(seconds: 90));
    });

    test('getTyped converts DateTime values from unix seconds', () {
      final o = JsonObject.from({'t': 1300819380});
      expect(
        o.getTyped<DateTime>('t'),
        DateTime.fromMillisecondsSinceEpoch(1300819380000),
      );
    });

    test('getTyped returns null for absent keys', () {
      final o = JsonObject.from({'a': 1});
      expect(o.getTyped<Uri>('missing'), isNull);
    });

    test('getTypedList wraps a single scalar value into a list', () {
      final o = JsonObject.from({'aud': 'only-one'});
      expect(o.getTypedList<String>('aud'), ['only-one']);
    });

    test('getTypedList returns each element of a list', () {
      final o = JsonObject.from({
        'aud': ['a', 'b', 'c']
      });
      expect(o.getTypedList<String>('aud'), ['a', 'b', 'c']);
    });

    test('getTypedList returns null for absent keys', () {
      final o = JsonObject.from({'a': 1});
      expect(o.getTypedList<String>('missing'), isNull);
    });
  });

  group('safeUnion', () {
    test('merges disjoint maps', () {
      expect(
        safeUnion([
          {'a': 1},
          {'b': 2},
          null,
        ]),
        {'a': 1, 'b': 2},
      );
    });

    test('allows duplicate keys with equal values', () {
      expect(
        safeUnion([
          {'a': 1},
          {'a': 1, 'b': 2},
        ]),
        {'a': 1, 'b': 2},
      );
    });

    test('throws on conflicting duplicate keys', () {
      expect(
        () => safeUnion([
          {'a': 1},
          {'a': 2},
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('commonUnion', () {
    test('returns empty for an empty iterable', () {
      expect(commonUnion([]), isEmpty);
    });

    test('keeps only the parameters common (and equal) to all maps', () {
      expect(
        commonUnion([
          {'a': 1, 'b': 2, 'c': 3},
          {'a': 1, 'b': 9, 'c': 3},
          {'a': 1, 'c': 3},
        ]),
        {'a': 1, 'c': 3},
      );
    });

    test('returns empty when nothing is shared', () {
      expect(
        commonUnion([
          {'a': 1},
          {'b': 2},
        ]),
        isEmpty,
      );
    });
  });

  group('encodeBigInt', () {
    test('encodes a positive BigInt to unpadded base64url', () {
      // 0x010203 -> bytes [1,2,3]
      final encoded = encodeBigInt(BigInt.parse('010203', radix: 16));
      final decoded = decodeBase64EncodedBytes(encoded);
      expect(decoded, [1, 2, 3]);
    });

    test('encodes zero to an empty byte sequence', () {
      expect(encodeBigInt(BigInt.zero), isEmpty);
    });
  });

  group('base64 helpers', () {
    test('encode/decode round-trips arbitrary bytes without padding', () {
      final data = [0, 1, 2, 250, 255];
      final encoded = encodeBase64EncodedBytes(data);
      expect(encoded, isNot(contains('=')));
      expect(decodeBase64EncodedBytes(encoded), data);
    });
  });
}
