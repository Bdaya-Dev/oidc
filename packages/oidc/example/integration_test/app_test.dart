// integration_test entrypoint (testWidgets) — used by the linux/windows CI
// jobs. It launches the real example app via its main()/runApp, which is fine
// under IntegrationTestWidgetsFlutterBinding. android/iOS/macOS/web run the
// same flow via Patrol (patrol_test/app_test.dart). Logic lives in
// shared_e2e.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/main.dart' as example;

import 'shared_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ensureLoggingConfigured();

  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
        await runManagerSmokeTest(() async {
          example.main();
          await tester.pumpAndSettle();
        });
      });
    } else {
      testWidgets('OIDC Conformance Test', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        });
      });
    }
  });
}
