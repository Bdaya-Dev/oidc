import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_android/oidc_android.dart';
import 'package:oidc_core/oidc_core.dart';

// `oidc_android_test.dart` exercises `getAuthorizationResponse` /
// `getEndSessionResponse` / `registerWith` extensively over the Pigeon
// channel, but never touches `prepareForRedirectFlow`,
// `listenToFrontChannelLogoutRequests`, or `monitorSessionStatus` -- these
// three lines are never executed by any existing test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('oidc_android library surface', () {
    test(
      'prepareForRedirectFlow is a no-op that returns an empty preparation '
      'map (Chrome Custom Tabs are launched directly, no pre-navigation '
      'step)',
      () {
        final result = OidcAndroid().prepareForRedirectFlow(
          const OidcPlatformSpecificOptions(),
        );
        expect(result, isEmpty);
      },
    );

    test(
      'listenToFrontChannelLogoutRequests returns an empty stream '
      '(front-channel logout listening is not implemented on Android)',
      () async {
        final events = await OidcAndroid()
            .listenToFrontChannelLogoutRequests(
              Uri.parse('com.example.app://logout'),
              const OidcFrontChannelRequestListeningOptions(),
            )
            .toList();
        expect(events, isEmpty);
      },
    );

    test(
      'monitorSessionStatus returns an empty stream '
      '(session-status polling is not supported on Android)',
      () async {
        final events = await OidcAndroid()
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
