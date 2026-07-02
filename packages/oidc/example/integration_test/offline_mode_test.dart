// integration_test (testWidgets) harness for the offline-mode e2e flow.
// Used by the macOS CI job (`flutter test integration_test`). The android/iOS/
// linux/windows jobs run the same assertions through Patrol via
// ../patrol_test/offline_mode_test.dart. Shared logic lives in
// shared_offline.dart, so both harnesses run identical tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/main.dart' as example;

import 'shared_offline.dart';

var _appStarted = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline mode integration', () {
    Future<void> launch(WidgetTester tester) async {
      if (!_appStarted) {
        example.main();
        _appStarted = true;
      }
      await tester.pumpAndSettle();
    }

    testWidgets('enters offline mode after refresh failure', (tester) async {
      await runOfflineEntersOfflineMode(() => launch(tester), tester.pump);
    });

    testWidgets('exits offline mode after subsequent success', (tester) async {
      await runOfflineExitsAfterSuccess(() => launch(tester), tester.pump);
    });

    testWidgets('emits warning after repeated refresh failures', (
      tester,
    ) async {
      await runOfflineEmitsWarning(() => launch(tester), tester.pump);
    });
  });
}
