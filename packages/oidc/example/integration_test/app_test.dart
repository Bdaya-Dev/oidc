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
      testWidgets('OIDC Conformance: Basic RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        });
      });

      // See the Patrol harness for why each plan is a separate case.
      testWidgets('OIDC Conformance: Hybrid RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-hybrid-certification-test-plan',
          clientAuthType: 'client_secret_basic',
        );
      });

      testWidgets('OIDC Conformance: Implicit RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-implicit-certification-test-plan',
          clientAuthType: 'client_secret_basic',
        );
      });

      // See the Patrol harness for why Config RP is a separate case.
      testWidgets('OIDC Conformance: Config RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-config-certification-test-plan',
          // The discovery module rejects the plan outright without this; the
          // Basic plan defaults it, this one does not.
          clientAuthType: 'client_secret_basic',
        );
      });
    }
  });
}
