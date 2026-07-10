@TestOn('vm')
library;

// `MockOidcLoopbackListener` (`lib/src/mock.dart`) is marked
// `@visibleForTesting` and is deliberately NOT re-exported by the public
// barrel (`oidc_loopback_listener.dart`) -- it is meant to be imported
// directly by consumers' test code, the same way this test imports it. No
// other test in this package ever imports `src/mock.dart`, so without this
// test the file is never loaded and stays invisible to coverage tooling.
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';
import 'package:oidc_loopback_listener/src/mock.dart';
import 'package:test/test.dart';

void main() {
  group('oidc_loopback_listener library surface', () {
    test('MockOidcLoopbackListener is a real subtype of OidcLoopbackListener '
        'that inherits the documented defaults', () {
      final mock = MockOidcLoopbackListener();
      expect(mock, isA<OidcLoopbackListener>());
      // `MockOidcLoopbackListener` adds no fields of its own; it must
      // inherit the base class's documented defaults verbatim.
      expect(mock.port, 0);
      expect(mock.path, isNull);
    });

    test('oidcDefaultHtmlPage documents the redirect-back message', () {
      expect(oidcDefaultHtmlPage, contains('Please return to the app.'));
    });
  });
}
