import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// A single OpenID Connect Discovery 1.0 §2.1 Identifier Normalization vector.
class _Vector {
  const _Vector(this.input, this.resource, this.host, {required this.source});

  /// The raw End-User input Identifier (§2.1.1).
  final String input;

  /// The expected §2.1.2 normalized URI (the RFC 7033 §4.1 `resource`).
  final String resource;

  /// The expected §2.1.2 WebFinger Host.
  final String host;

  /// Whether the row is quoted from the specification or derived from the
  /// normative rule text — kept in the test name so a reviewer can tell at a
  /// glance which assertions are spec-literal.
  final String source;
}

/// The four rows the specification itself publishes, in §2.2.1-§2.2.4
/// ("Non-Normative Examples"). These are the only authoritative outputs in the
/// document; everything in [_derivedVectors] is derived from the rule prose.
const _specTableVectors = <_Vector>[
  // §2.2.1 Joe User of example.com — rule 2 (acct: assumed).
  _Vector(
    'joe@example.com',
    'acct:joe@example.com',
    'example.com',
    source: 'spec-table §2.2.1',
  ),
  // §2.2.2 Joe User using a URL — rule 4 (explicit scheme, verbatim).
  _Vector(
    'https://example.com/joe',
    'https://example.com/joe',
    'example.com',
    source: 'spec-table §2.2.2',
  ),
  // §2.2.3 Joe User using a URL with a port — rule 3 (https:// assumed).
  _Vector(
    'example.com:8080',
    'https://example.com:8080/',
    'example.com:8080',
    source: 'spec-table §2.2.3',
  ),
  // §2.2.4 Joe User at an external OP — rule 4, with an already percent-encoded
  // userinfo that MUST survive untouched.
  _Vector(
    'acct:juliet%40capulet.example@shopping.example.com',
    'acct:juliet%40capulet.example@shopping.example.com',
    'shopping.example.com',
    source: 'spec-table §2.2.4',
  ),
];

const _derivedVectors = <_Vector>[
  // Rule 3 with no port and no path: RFC 3986 §6.2.3 empty-path normalization
  // supplies the trailing slash, exactly as §2.2.3's table does.
  _Vector(
    'example.com',
    'https://example.com/',
    'example.com',
    source: 'derived rule 3',
  ),
  _Vector(
    'example.com/joe',
    'https://example.com/joe',
    'example.com',
    source: 'derived rule 3',
  ),
  // Rule 2's precondition requires the port to be ABSENT, so a userinfo plus a
  // port falls through to rule 3 — §2.1.2 rule 3 lists this very example.
  _Vector(
    'joe@example.com:8080',
    'https://joe@example.com:8080/',
    'example.com:8080',
    source: 'derived rule 3',
  ),
  _Vector(
    'alice@example.com:8080',
    'https://alice@example.com:8080/',
    'example.com:8080',
    source: 'derived rule 3',
  ),
  // Rule 2 is a string operation: the userinfo's case is preserved verbatim.
  _Vector(
    'Jane.Doe@example.com',
    'acct:Jane.Doe@example.com',
    'example.com',
    source: 'derived rule 2',
  ),
  // Rule 4 performs NO normalization, so no trailing slash is added here even
  // though the rule-3 branch would have added one.
  _Vector(
    'https://example.com',
    'https://example.com',
    'example.com',
    source: 'derived rule 4',
  ),
  _Vector(
    'https://joe@example.com:8080',
    'https://joe@example.com:8080',
    'example.com:8080',
    source: 'derived rule 4',
  ),
  _Vector(
    'acct:joe@example.com',
    'acct:joe@example.com',
    'example.com',
    source: 'derived rule 4',
  ),
  // §2.2.4's NOTE: "End-Users MAY input values like joe@example.com@example.org".
  // RFC 7565 requires the '@' inside the userinfo to be percent-encoded.
  _Vector(
    'joe@example.com@example.org',
    'acct:joe%40example.com@example.org',
    'example.org',
    source: 'derived rule 2 + RFC 7565',
  ),
  // Already an acct: URI — rule 4, verbatim, so encoding is never doubled.
  _Vector(
    'acct:joe%40example.com@example.org',
    'acct:joe%40example.com@example.org',
    'example.org',
    source: 'derived rule 4',
  ),
  // Rule 2 on an already-encoded userinfo: encoding ONLY the literal '@' keeps
  // the operation idempotent (%40 must NOT become %2540).
  _Vector(
    'juliet%40capulet.example@shopping.example.com',
    'acct:juliet%40capulet.example@shopping.example.com',
    'shopping.example.com',
    source: 'derived rule 2, idempotent encoding',
  ),
  // Rule 5 strips the fragment after rules 1-4 have run.
  _Vector(
    'https://example.com/joe#fragment',
    'https://example.com/joe',
    'example.com',
    source: 'derived rule 5',
  ),
  _Vector(
    'acct:joe@example.com#frag',
    'acct:joe@example.com',
    'example.com',
    source: 'derived rule 5',
  ),
  // ORDERING IS LOAD-BEARING: rule 2 requires the fragment to be absent and
  // rule 5 (strip it) only runs afterwards, so this is rule 3, not rule 2.
  // pyoidc/panva strip the fragment first and answer acct:joe@example.com.
  _Vector(
    'joe@example.com#frag',
    'https://joe@example.com/',
    'example.com',
    source: 'derived rules 2+5 ordering',
  ),
  // A query component likewise defeats rule 2's precondition.
  _Vector(
    'joe@example.com?foo=bar',
    'https://joe@example.com/?foo=bar',
    'example.com',
    source: 'derived rule 3',
  ),
  // A non-empty path means RFC 3986 §6.2.3 has nothing to add.
  _Vector(
    'example.com:8080/joe',
    'https://example.com:8080/joe',
    'example.com:8080',
    source: 'derived rule 3',
  ),
  // The resource keeps the input's case; only the Host is case-folded
  // (RFC 3986 §6.2.2.1).
  _Vector(
    'Example.COM:8080',
    'https://Example.COM:8080/',
    'example.com:8080',
    source: 'derived rules 3/5 case handling',
  ),
  // Rule 4 does not "upgrade" the scheme: the resource is an identifier, not a
  // fetch target.
  _Vector(
    'http://example.com/joe',
    'http://example.com/joe',
    'example.com',
    source: 'derived rule 4',
  ),
];

void main() {
  group('OidcUtils.normalizeWebFingerIdentifier', () {
    for (final vector in [..._specTableVectors, ..._derivedVectors]) {
      test('${vector.input} [${vector.source}]', () {
        final result = OidcUtils.normalizeWebFingerIdentifier(vector.input);
        expect(result.resource, vector.resource, reason: 'resource');
        expect(result.host, vector.host, reason: 'host');
      });
    }

    group('rejected input', () {
      // §2.1.1 item 1: the XRI global context symbols are RESERVED and their
      // processing is out of scope for the specification.
      for (final xri in const ['=joe', '@joe', '!joe']) {
        test('XRI identifier $xri throws', () {
          expect(
            () => OidcUtils.normalizeWebFingerIdentifier(xri),
            throwsA(isA<OidcException>()),
          );
        });
      }

      test('a blank identifier throws', () {
        expect(
          () => OidcUtils.normalizeWebFingerIdentifier('   '),
          throwsA(isA<OidcException>()),
        );
        expect(
          () => OidcUtils.normalizeWebFingerIdentifier(''),
          throwsA(isA<OidcException>()),
        );
      });

      test('a syntactically invalid URI throws OidcException, not '
          'FormatException', () {
        expect(
          () => OidcUtils.normalizeWebFingerIdentifier(
            'https://joe@example.com:foo',
          ),
          throwsA(
            isA<OidcException>().having(
              (e) => e.internalException,
              'internalException',
              isA<FormatException>(),
            ),
          ),
        );
      });

      test('a URI with no derivable WebFinger Host throws', () {
        // urn:example:resource has neither an authority nor an '@' in its
        // path-rootless, so §2.1.2's "the WebFinger Host is the authority
        // component" cannot be satisfied.
        expect(
          () => OidcUtils.normalizeWebFingerIdentifier('urn:example:resource'),
          throwsA(isA<OidcException>()),
        );
      });
    });

    group('whitespace and idempotence', () {
      test('surrounding whitespace is trimmed before normalization', () {
        final result = OidcUtils.normalizeWebFingerIdentifier(
          '  joe@example.com  ',
        );
        expect(result.resource, 'acct:joe@example.com');
        expect(result.host, 'example.com');
      });

      test('normalizing an already-normalized resource is a no-op', () {
        for (final vector in [..._specTableVectors, ..._derivedVectors]) {
          final once = OidcUtils.normalizeWebFingerIdentifier(vector.input);
          final twice = OidcUtils.normalizeWebFingerIdentifier(once.resource);
          expect(
            twice.resource,
            once.resource,
            reason: 'normalization must be idempotent for ${vector.input}',
          );
          expect(twice.host, once.host, reason: 'host for ${vector.input}');
        }
      });
    });

    group('OidcWebFingerIdentifier value semantics', () {
      test('equal resource+host compare equal and share a hashCode', () {
        const a = OidcWebFingerIdentifier(
          resource: 'acct:joe@example.com',
          host: 'example.com',
        );
        const b = OidcWebFingerIdentifier(
          resource: 'acct:joe@example.com',
          host: 'example.com',
        );
        const c = OidcWebFingerIdentifier(
          resource: 'acct:joe@example.org',
          host: 'example.org',
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
        expect(a.toString(), contains('acct:joe@example.com'));
      });
    });
  });
}
