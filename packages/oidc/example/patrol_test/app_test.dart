// Patrol entrypoint (patrolTest) — used by the android/iOS/web/linux/windows CI
// jobs. macOS runs the same shared flow via `flutter test integration_test`.
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
// The placeholder MUST be wrapped with SharedValue.wrapApp(): on android/iOS the
// native `$dartRunMain` runs the real main() (which already wraps), but the
// linux/windows desktop backend does NOT run the real main(), so without this
// the conformance flow throws "SharedValue was not initalized" at the first
// app_state.*Rx update (shared_e2e.dart:193). Logic is shared in
// ../integration_test/shared_e2e.dart, so the Patrol and flutter-test harnesses
// run identical tests.

import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:patrol_plus/patrol.dart';

import '../integration_test/shared_e2e.dart';

Future<void> _launch(PatrolIntegrationTester $) async {
  // Mirror the part of example main() the OIDC flow relies on, without
  // re-running runApp (Patrol already bootstrapped the engine). wrapApp() sets
  // the static SharedValue.didWrap flag and installs the StateManagerWidget, so
  // the conformance flow's app_state.managersRx/currentManagerRx updates work on
  // the desktop backend too. Idempotent where the real main() already wrapped.
  usePathUrlStrategy();
  await $.pumpWidgetAndSettle(
    SharedValue.wrapApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('OIDC conformance harness'))),
      ),
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
