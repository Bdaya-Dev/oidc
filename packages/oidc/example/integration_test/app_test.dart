// integration_test entrypoint (testWidgets) — used by the linux/windows CI
// jobs. android/iOS/macOS/web run the same flow via Patrol; see
// patrol_test/app_test.dart. The actual logic lives in shared_e2e.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'shared_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ensureLoggingConfigured();
  _testLog('token provided: ${oidcConformanceToken.isNotEmpty}');

  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
        await runManagerSmokeTest(() => tester.pumpAndSettle());
      });
    } else {
      testWidgets('OIDC Conformance Test', (tester) async {
        await runOidcConformanceTest(() => tester.pumpAndSettle());
      });
    }
  });
}

void _testLog(String message) {
  // ignore: avoid_print
  print('[oidc.conformance] $message');
}
