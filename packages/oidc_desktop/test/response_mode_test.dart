import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_desktop/src/oidc_desktop.dart';

// A fragment never reaches the loopback server, so hybrid and implicit
// responses are lost on desktop unless the listener runs its JavaScript relay.
// The relay costs a round trip and requires a real browser, so it must be
// enabled for exactly the flows that cannot work without it -- no more.
//
// OAuth 2.0 Multiple Response Type Encoding Practices, section 2: `code` alone
// defaults to the query encoding; every other response type defaults to the
// fragment encoding. An explicit `response_mode` overrides the default.
void main() {
  group('responseArrivesInFragment', () {
    test('code alone stays on the query encoding', () {
      expect(responseArrivesInFragment({'response_type': 'code'}), isFalse);
    });

    test('hybrid response types use the fragment encoding', () {
      for (final t in ['code id_token', 'code token', 'code id_token token']) {
        expect(
          responseArrivesInFragment({'response_type': t}),
          isTrue,
          reason: '$t is a hybrid flow and defaults to fragment',
        );
      }
    });

    test('implicit response types use the fragment encoding', () {
      for (final t in ['id_token', 'id_token token', 'token']) {
        expect(
          responseArrivesInFragment({'response_type': t}),
          isTrue,
          reason: '$t is an implicit flow and defaults to fragment',
        );
      }
    });

    test('an explicit response_mode overrides the response_type default', () {
      // form_post on a hybrid type: the body carries it, not the fragment.
      expect(
        responseArrivesInFragment({
          'response_type': 'code id_token',
          'response_mode': 'form_post',
        }),
        isFalse,
      );
      // query on a hybrid type: unusual, but the mode wins.
      expect(
        responseArrivesInFragment({
          'response_type': 'code id_token',
          'response_mode': 'query',
        }),
        isFalse,
      );
      // fragment on a plain code flow: the mode wins here too.
      expect(
        responseArrivesInFragment({
          'response_type': 'code',
          'response_mode': 'fragment',
        }),
        isTrue,
      );
    });

    test('token ordering and extra whitespace do not change the answer', () {
      // response_type is a space-delimited SET, so order is not significant.
      expect(
        responseArrivesInFragment({'response_type': 'id_token code'}),
        isTrue,
      );
      expect(
        responseArrivesInFragment({'response_type': '  code   id_token  '}),
        isTrue,
      );
    });

    test('a list-valued response_type is handled', () {
      expect(
        responseArrivesInFragment({
          'response_type': ['code', 'id_token'],
        }),
        isTrue,
      );
      expect(
        responseArrivesInFragment({
          'response_type': ['code'],
        }),
        isFalse,
      );
    });

    test('none and a missing response_type do not enable the relay', () {
      // Nothing is returned to capture, so paying for the relay is pointless.
      expect(responseArrivesInFragment({'response_type': 'none'}), isFalse);
      expect(responseArrivesInFragment({}), isFalse);
      expect(responseArrivesInFragment({'response_type': ''}), isFalse);
    });
  });
}
