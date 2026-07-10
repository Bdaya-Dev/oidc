@TestOn('chrome')
library;

// `oidc_web.dart` (the real `OidcWeb` plugin class, the KNOWN gap this test
// closes) imports `oidc_web_core`, which unconditionally depends on
// `package:web` (`dart:js_interop`) -- so this suite only compiles for a
// browser compile target and must be run with `flutter test -d chrome`
// (equivalent to `dart test -p chrome` for a pure-Dart package). This
// package's other "test" file is only a placeholder pointing at
// `integration_test`, so `oidc_web.dart` was never loaded by any unit test
// before this file.
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_web/oidc_web.dart';

void main() {
  group('oidc_web library surface', () {
    test(
      'registerWith installs OidcWeb as the OidcPlatform.instance singleton',
      () {
        OidcWeb.registerWith();
        expect(OidcPlatform.instance, isA<OidcWeb>());
        // restore the default for any other suite sharing this isolate.
        OidcPlatform.instance = NoOpOidcPlatform();
      },
    );

    test(
      'prepareForRedirectFlow delegates to OidcWebCore: samePage navigation '
      'mode produces an empty preparation map (no popup/new-tab opened)',
      () {
        final web = OidcWeb();
        final result = web.prepareForRedirectFlow(
          const OidcPlatformSpecificOptions(
            web: OidcPlatformSpecificOptions_Web(
              navigationMode:
                  OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
            ),
          ),
        );
        expect(result, isEmpty);
      },
    );

    test(
      'monitorSessionStatus delegates to OidcWebCore, which documents that '
      'it "creates a hidden iframe every time you listen to it" -- i.e. the '
      'returned stream must be single-subscription, not broadcast',
      () {
        final web = OidcWeb();
        final stream = web.monitorSessionStatus(
          checkSessionIframe: Uri.parse('https://op.example.com/checksession'),
          request: const OidcMonitorSessionStatusRequest(
            clientId: 'client-1',
            sessionState: 'state-1',
            interval: Duration(seconds: 30),
          ),
        );
        expect(stream.isBroadcast, isFalse);
      },
    );
  });
}
