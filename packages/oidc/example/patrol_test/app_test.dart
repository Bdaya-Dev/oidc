// Patrol entrypoint (patrolTest) — used by the android/iOS/macOS/web CI jobs.
// On web, Patrol drives Chromium via Playwright (no flutter-drive/DWDS), which
// avoids Flutter's DWDS startup race (flutter/flutter#181357).
//
// linux/windows still run the same flow via integration_test/app_test.dart
// until the Patrol fork gains desktop backends. The logic is shared in
// ../integration_test/shared_e2e.dart, so both harnesses run identical tests.

import 'package:patrol/patrol.dart';

import '../integration_test/shared_e2e.dart';

void main() {
  ensureLoggingConfigured();

  if (oidcConformanceToken.isEmpty) {
    patrolTest('Simple manager initializes correctly', ($) async {
      await runManagerSmokeTest(() => $.pumpAndSettle());
    });
  } else {
    patrolTest('OIDC Conformance Test', ($) async {
      await runOidcConformanceTest(() => $.pumpAndSettle());
    });
  }
}
