@TestOn('vm')
library;

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcStepUpChallenge.parse (RFC 9470)', () {
    test('parses an insufficient_user_authentication challenge', () {
      final c = OidcStepUpChallenge.parse(
        'Bearer error="insufficient_user_authentication", '
        'error_description="need acr", '
        'acr_values="urn:mace:incommon:iap:silver phr", max_age=0',
      );
      expect(c, isNotNull);
      expect(c!.scheme, 'Bearer');
      expect(c.isInsufficientUserAuthentication, isTrue);
      expect(c.errorDescription, 'need acr');
      expect(c.acrValues, ['urn:mace:incommon:iap:silver', 'phr']);
      expect(c.maxAge, Duration.zero);
    });

    test('parses unquoted params alongside a realm', () {
      final c = OidcStepUpChallenge.parse(
        'Bearer realm="example", '
        'error=insufficient_user_authentication, max_age=300',
      );
      expect(c!.isInsufficientUserAuthentication, isTrue);
      expect(c.maxAge, const Duration(seconds: 300));
      expect(c.parameters['realm'], 'example');
    });

    test('returns null for null / blank / scheme-only headers', () {
      expect(OidcStepUpChallenge.parse(null), isNull);
      expect(OidcStepUpChallenge.parse('   '), isNull);
      expect(OidcStepUpChallenge.parse('Bearer'), isNull);
    });

    test('a non-step-up error still parses, flagged false', () {
      final c = OidcStepUpChallenge.parse('Bearer error="invalid_token"');
      expect(c, isNotNull);
      expect(c!.error, 'invalid_token');
      expect(c.isInsufficientUserAuthentication, isFalse);
    });
  });
}
