// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

// `oidc_desktop_test.dart` exercises `OidcDesktop`'s redirect-flow methods
// (`getAuthorizationResponse` / `getEndSessionResponse`) extensively, but
// never touches `prepareForRedirectFlow`, `listenToFrontChannelLogoutRequests`,
// or `monitorSessionStatus` -- these three lines are never executed by any
// existing test, even though the barrel that declares them is already
// loaded. This test closes that gap with real assertions against their
// documented (empty/no-op) desktop behavior.
class _MinimalDesktopImpl extends OidcPlatform with OidcDesktop {
  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) =>
      const OidcPlatformSpecificOptions_Native();

  @override
  Logger get logger => Logger('Oidc.MinimalDesktop');
}

void main() {
  group('oidc_desktop library surface', () {
    late _MinimalDesktopImpl oidc;

    setUp(() {
      oidc = _MinimalDesktopImpl();
    });

    test(
      'prepareForRedirectFlow is a no-op that returns an empty preparation '
      'map (desktop launches the browser directly, no pre-navigation step)',
      () {
        final result =
            oidc.prepareForRedirectFlow(const OidcPlatformSpecificOptions());
        expect(result, isEmpty);
      },
    );

    test(
      'listenToFrontChannelLogoutRequests returns an empty stream '
      '(not yet implemented on desktop)',
      () async {
        final events = await oidc
            .listenToFrontChannelLogoutRequests(
              Uri.parse('http://localhost:0'),
              const OidcFrontChannelRequestListeningOptions(),
            )
            .toList();
        expect(events, isEmpty);
      },
    );

    test(
      'monitorSessionStatus returns an empty stream '
      '(session-status polling is not supported on desktop)',
      () async {
        final events = await oidc
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
