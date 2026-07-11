import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_windows/oidc_windows.dart';

// `oidc_windows_test.dart`'s only test overrides `options.windows`
// explicitly and never touches `monitorSessionStatus` -- `OidcWindows`
// overrides the `OidcDesktop` mixin's default with its own empty-stream
// implementation, and that override's body is never executed by any
// existing test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('oidc_windows library surface', () {
    test(
        'OidcWindows mixes in OidcDesktop (shares the desktop redirect-flow '
        'implementation)', () {
      expect(OidcWindows(), isA<OidcDesktop>());
    });

    test(
      'getNativeOptions reads options.windows specifically (default, '
      'un-overridden options)',
      () {
        final result = OidcWindows().getNativeOptions(
          const OidcPlatformSpecificOptions(),
        );
        expect(result, const OidcPlatformSpecificOptions_Native());
      },
    );

    test(
      "monitorSessionStatus's own override returns an empty stream "
      '(session-status polling is not supported on Windows)',
      () async {
        final events = await OidcWindows()
            .monitorSessionStatus(
              checkSessionIframe: Uri.parse('https://op.example.com/check'),
              request: const OidcMonitorSessionStatusRequest(
                clientId: 'client-1',
                sessionState: 'state-1',
                interval: Duration(seconds: 1),
              ),
            )
            .toList();
        expect(events, isEmpty);
      },
    );
  });
}
