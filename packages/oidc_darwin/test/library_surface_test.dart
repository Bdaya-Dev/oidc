import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_darwin/oidc_darwin.dart';

// `oidc_darwin_test.dart` exercises `getAuthorizationResponse` /
// `getEndSessionResponse` / `registerWith` extensively over the Pigeon
// channel, but never touches `prepareForRedirectFlow`,
// `listenToFrontChannelLogoutRequests`, or `monitorSessionStatus` -- these
// three lines are never executed by any existing test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('oidc_darwin library surface', () {
    test('prepareForRedirectFlow is a no-op that returns an empty preparation '
        'map (ASWebAuthenticationSession is launched directly, no '
        'pre-navigation step)', () {
      final result = OidcDarwin().prepareForRedirectFlow(
        const OidcPlatformSpecificOptions(),
      );
      expect(result, isEmpty);
    });

    test(
      'listenToFrontChannelLogoutRequests returns an empty stream '
      '(front-channel logout listening is not implemented on iOS/macOS)',
      () async {
        final events = await OidcDarwin()
            .listenToFrontChannelLogoutRequests(
              Uri.parse('com.example.app://logout'),
              const OidcFrontChannelRequestListeningOptions(),
            )
            .toList();
        expect(events, isEmpty);
      },
    );

    test('monitorSessionStatus returns an empty stream '
        '(session-status polling is not supported on iOS/macOS)', () async {
      final events = await OidcDarwin()
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
    });
  });
}
