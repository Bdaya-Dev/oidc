// Patrol entrypoint (patrolTest) — used by the android/iOS/macOS/web CI jobs.
// On web, Patrol drives Chromium via Playwright (no flutter-drive/DWDS), which
// avoids Flutter's DWDS startup race (flutter/flutter#181357).
//
// IMPORTANT: Patrol already bootstraps the app (runs `main` via `$dartRunMain`),
// so we must NOT call the example's main()/runApp here (that double-initializes
// the Flutter engine -> "engine has already started initialization"). Instead we
// pump a minimal widget via the PatrolTester. The OIDC conformance flow is
// programmatic (HTTP + OidcUserManager, whose web redirect rides on the engine's
// browser plugins, not the widget tree), so a placeholder widget is sufficient.
//
// linux/windows still run the same flow via integration_test/app_test.dart
// until the Patrol fork gains desktop backends. Logic is shared in
// ../integration_test/shared_e2e.dart, so both harnesses run identical tests.

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:patrol/patrol.dart';

import '../integration_test/shared_e2e.dart';

Future<void> _launch(PatrolIntegrationTester $) async {
  // Mirror the part of example main() the OIDC web redirect relies on, without
  // re-running runApp.
  usePathUrlStrategy();
  await $.pumpWidgetAndSettle(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('OIDC conformance harness'))),
    ),
  );
}

void main() {
  ensureLoggingConfigured();

  if (oidcConformanceToken.isEmpty) {
    patrolTest('Simple manager initializes correctly', ($) async {
      await runManagerSmokeTest(() => _launch($));
    });
  } else {
    patrolTest('OIDC Conformance Test', ($) async {
      await runOidcConformanceTest(() => _launch($));
    });
  }
}
