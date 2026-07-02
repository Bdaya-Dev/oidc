@TestOn('vm')
library;

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcUtils.getOpenIdConfigWellKnownUri (OIDC §4.1 append)', () {
    test('bare authority', () {
      expect(
        OidcUtils.getOpenIdConfigWellKnownUri(
          Uri.parse('https://example.com'),
        ).toString(),
        'https://example.com/.well-known/openid-configuration',
      );
    });

    test('bare authority with trailing slash → no double slash', () {
      expect(
        OidcUtils.getOpenIdConfigWellKnownUri(
          Uri.parse('https://example.com/'),
        ).toString(),
        'https://example.com/.well-known/openid-configuration',
      );
    });

    test('path issuer', () {
      expect(
        OidcUtils.getOpenIdConfigWellKnownUri(
          Uri.parse('https://example.com/issuer1'),
        ).toString(),
        'https://example.com/issuer1/.well-known/openid-configuration',
      );
    });

    test(
      'path issuer WITH trailing slash → identical, no `//` (regression)',
      () {
        expect(
          OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://example.com/issuer1/'),
          ).toString(),
          'https://example.com/issuer1/.well-known/openid-configuration',
        );
      },
    );
  });

  group('OidcUtils.getOAuthAuthServerWellKnownUri (RFC 8414 §3.1 insert)', () {
    test('inserts before the path', () {
      expect(
        OidcUtils.getOAuthAuthServerWellKnownUri(
          Uri.parse('https://example.com/issuer1'),
        ).toString(),
        'https://example.com/.well-known/oauth-authorization-server/issuer1',
      );
    });
  });

  group('OidcUtils.issuersAreIdentical (OIDC §4.3 / RFC 8414 §3.3)', () {
    test('identical → true', () {
      expect(
        OidcUtils.issuersAreIdentical(
          Uri.parse('https://op.example.com'),
          Uri.parse('https://op.example.com'),
        ),
        isTrue,
      );
    });

    test('scheme/host case differences fold → true', () {
      expect(
        OidcUtils.issuersAreIdentical(
          Uri.parse('https://OP.Example.com'),
          Uri.parse('https://op.example.com'),
        ),
        isTrue,
      );
    });

    test('a trailing-slash path difference is significant → false', () {
      expect(
        OidcUtils.issuersAreIdentical(
          Uri.parse('https://op.example.com/realm'),
          Uri.parse('https://op.example.com/realm/'),
        ),
        isFalse,
      );
    });

    test('different host → false', () {
      expect(
        OidcUtils.issuersAreIdentical(
          Uri.parse('https://op.example.com'),
          Uri.parse('https://attacker.example'),
        ),
        isFalse,
      );
    });
  });
}
