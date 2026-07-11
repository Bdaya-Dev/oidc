import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcInternalUtilities.joinSpaceDelimitedList', () {
    test('joins a non-empty list with spaces', () {
      expect(
        OidcInternalUtilities.joinSpaceDelimitedList(['a', 'b', 'c']),
        'a b c',
      );
    });

    test('null and empty list both yield null', () {
      expect(OidcInternalUtilities.joinSpaceDelimitedList(null), isNull);
      expect(OidcInternalUtilities.joinSpaceDelimitedList([]), isNull);
    });
  });

  group('OidcInternalUtilities.splitSpaceDelimitedString', () {
    test('splits a space-delimited string', () {
      expect(
        OidcInternalUtilities.splitSpaceDelimitedString('openid profile email'),
        ['openid', 'profile', 'email'],
      );
    });

    test('an empty string yields an empty list', () {
      expect(OidcInternalUtilities.splitSpaceDelimitedString(''), isEmpty);
    });

    test('null yields an empty list', () {
      expect(OidcInternalUtilities.splitSpaceDelimitedString(null), isEmpty);
    });

    test('a List filters to its String elements', () {
      expect(
        OidcInternalUtilities.splitSpaceDelimitedString(['a', 1, 'b', null]),
        ['a', 'b'],
      );
    });

    test('an unsupported type throws ArgumentError', () {
      expect(
        () => OidcInternalUtilities.splitSpaceDelimitedString(42),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('OidcInternalUtilities.splitSpaceDelimitedStringNullable', () {
    test('null input stays null (not an empty list)', () {
      expect(
        OidcInternalUtilities.splitSpaceDelimitedStringNullable(null),
        isNull,
      );
    });

    test('a value is delegated to the non-nullable splitter', () {
      expect(
        OidcInternalUtilities.splitSpaceDelimitedStringNullable('a b'),
        ['a', 'b'],
      );
    });
  });

  group('OidcInternalUtilities.readDurationSeconds', () {
    test('returns null for an absent key', () {
      expect(OidcInternalUtilities.readDurationSeconds({}, 'x'), isNull);
    });

    test('returns an int value verbatim', () {
      expect(OidcInternalUtilities.readDurationSeconds({'x': 30}, 'x'), 30);
    });

    test('parses a numeric string', () {
      expect(OidcInternalUtilities.readDurationSeconds({'x': '45'}, 'x'), 45);
    });

    test('a non-numeric string parses to null', () {
      expect(
        OidcInternalUtilities.readDurationSeconds({'x': 'abc'}, 'x'),
        isNull,
      );
    });
  });

  group('OidcInternalUtilities.durationFromJson / durationToJson', () {
    test('null decodes to null', () {
      expect(OidcInternalUtilities.durationFromJson(null), isNull);
    });

    test('an int is interpreted as seconds', () {
      expect(
        OidcInternalUtilities.durationFromJson(60),
        const Duration(minutes: 1),
      );
    });

    test('a numeric string is interpreted as seconds', () {
      expect(
        OidcInternalUtilities.durationFromJson('90'),
        const Duration(seconds: 90),
      );
    });

    test('a non-numeric string decodes to null', () {
      expect(OidcInternalUtilities.durationFromJson('nope'), isNull);
    });

    test('durationToJson emits whole seconds; null stays null', () {
      expect(
        OidcInternalUtilities.durationToJson(const Duration(minutes: 2)),
        120,
      );
      expect(OidcInternalUtilities.durationToJson(null), isNull);
    });
  });

  group('OidcInternalUtilities date helpers', () {
    test('dateTimeToJson emits ISO-8601; null stays null', () {
      final dt = DateTime.utc(2023, 1, 1, 12);
      expect(
        OidcInternalUtilities.dateTimeToJson(dt),
        dt.toIso8601String(),
      );
      expect(OidcInternalUtilities.dateTimeToJson(null), isNull);
    });

    test('dateTimeFromJsonRequired parses an ISO string', () {
      expect(
        OidcInternalUtilities.dateTimeFromJsonRequired('2023-01-01T12:00:00Z'),
        DateTime.utc(2023, 1, 1, 12),
      );
    });

    test('dateTimeFromJsonRequired reads epoch millis for an int', () {
      expect(
        OidcInternalUtilities.dateTimeFromJsonRequired(1000),
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    });

    test('dateTimeFromJsonRequired passes a DateTime through', () {
      final dt = DateTime.utc(2020);
      expect(OidcInternalUtilities.dateTimeFromJsonRequired(dt), dt);
    });

    test('dateTimeFromJsonRequired throws on an unsupported type', () {
      expect(
        () => OidcInternalUtilities.dateTimeFromJsonRequired(1.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('dateTimeFromJson tolerates null', () {
      expect(OidcInternalUtilities.dateTimeFromJson(null), isNull);
      expect(
        OidcInternalUtilities.dateTimeFromJson('2023-01-01T00:00:00Z'),
        DateTime.utc(2023),
      );
    });
  });

  group('OidcInternalUtilities.tryParseUri', () {
    test('a valid string becomes a Uri', () {
      expect(
        OidcInternalUtilities.tryParseUri('https://a.example.com/x'),
        Uri.parse('https://a.example.com/x'),
      );
    });

    test('null and non-string values become null', () {
      expect(OidcInternalUtilities.tryParseUri(null), isNull);
      expect(OidcInternalUtilities.tryParseUri(42), isNull);
      expect(OidcInternalUtilities.tryParseUri({'a': 'b'}), isNull);
    });
  });

  group('OidcInternalUtilities.serializeQueryParameters', () {
    test('drops nulls, stringifies scalars, and maps iterables', () {
      final result = OidcInternalUtilities.serializeQueryParameters({
        'scope': 'openid',
        'count': 3,
        'skip': null,
        'ids': [1, 2, 3],
      });
      expect(result, {
        'scope': 'openid',
        'count': '3',
        'ids': ['1', '2', '3'],
      });
      expect(result.containsKey('skip'), isFalse);
    });
  });

  group('OidcDateTime extension', () {
    test('secondsSinceEpoch truncates millis', () {
      final dt = DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true);
      expect(dt.secondsSinceEpoch, 1);
    });

    test('fromSecondsSinceEpoch is the inverse for whole seconds', () {
      final dt = OidcDateTime.fromSecondsSinceEpoch(120);
      expect(dt.millisecondsSinceEpoch, 120000);
    });
  });

  group('OidcUtils.getIssuerFromOpenIdConfigWellKnownUri (inverse of §4.1)', () {
    test('recovers the issuer from a standard well-known URL', () {
      final issuer = OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
        Uri.parse(
          'https://op.example.com/realm/.well-known/openid-configuration',
        ),
      );
      expect(issuer, Uri.parse('https://op.example.com/realm'));
    });

    test('recovers a root issuer', () {
      final issuer = OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
        Uri.parse('https://op.example.com/.well-known/openid-configuration'),
      );
      expect(issuer, Uri.parse('https://op.example.com'));
    });

    test('returns null when the URL does not end with the two segments', () {
      // RFC 8414 insert-layout URL cannot be inverted.
      expect(
        OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
          Uri.parse(
            'https://op.example.com/.well-known/oauth-authorization-server/realm',
          ),
        ),
        isNull,
      );
      expect(
        OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
          Uri.parse('https://op.example.com/foo'),
        ),
        isNull,
      );
    });

    test(
      'strips a query and fragment from the well-known URL '
      '(doc contract: "and clearing query/fragment")',
      () {
        final issuer = OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
          Uri.parse(
            'https://op.example.com/.well-known/openid-configuration'
            '?x=1#y',
          ),
        );
        expect(issuer, isNotNull);
        expect(issuer!.hasQuery, isFalse);
        expect(issuer.hasFragment, isFalse);
        expect(issuer, Uri.parse('https://op.example.com'));
        // Also assert byte-identical serialization: no leftover `?`/`#`
        // (a naive `Uri.replace(query: '')` fix would leave a dangling `?`).
        expect(issuer.toString(), 'https://op.example.com');
      },
    );

    test(
      'recovers a tenant issuer from an Entra-style `?appid=` well-known URL '
      'with the query cleared',
      () {
        final issuer = OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
          Uri.parse(
            'https://login.microsoftonline.com/common/v2.0'
            '/.well-known/openid-configuration'
            '?appid=6731de76-14a6-49ae-97bc-6eba6914391e',
          ),
        );
        expect(
          issuer,
          Uri.parse('https://login.microsoftonline.com/common/v2.0'),
        );
        expect(issuer!.hasQuery, isFalse);
      },
    );

    test('preserves userInfo and a non-default port', () {
      final issuer = OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(
        Uri.parse(
          'https://user:pass@op.example.com:8443/realm'
          '/.well-known/openid-configuration?x=1',
        ),
      );
      expect(
        issuer,
        Uri.parse('https://user:pass@op.example.com:8443/realm'),
      );
      expect(issuer!.hasQuery, isFalse);
    });
  });
}
