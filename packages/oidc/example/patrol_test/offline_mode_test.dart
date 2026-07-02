// Patrol entrypoint (patrolTest) for the offline-mode e2e flow — used by the
// android/iOS/linux/windows CI jobs (`patrol test --coverage`). The macOS job
// runs the same assertions through integration_test via
// ../integration_test/offline_mode_test.dart. Shared logic lives in
// ../integration_test/shared_offline.dart, so both harnesses run identical
// tests.
//
// IMPORTANT: Patrol already bootstraps the app (runs `main` via
// `$dartRunMain`), so we must NOT call the example's main()/runApp here. The
// offline-mode flow is programmatic (it drives OidcUserManager directly with an
// in-memory store), so pumping a minimal placeholder widget is sufficient.
//
// This entrypoint is intentionally NOT run on web: shared_offline.dart imports
// `dart:io`, and the web Patrol job targets only patrol_test/app_test.dart.

import 'package:flutter/material.dart';
import 'package:patrol_plus/patrol.dart';

import '../integration_test/shared_offline.dart';

Future<void> _launch(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('OIDC offline-mode harness'))),
    ),
  );
}

void main() {
  patrolTest('enters offline mode after refresh failure', ($) async {
    await runOfflineEntersOfflineMode(() => _launch($), $.pump);
  });

  patrolTest('exits offline mode after subsequent success', ($) async {
    await runOfflineExitsAfterSuccess(() => _launch($), $.pump);
  });

  patrolTest('emits warning after repeated refresh failures', ($) async {
    await runOfflineEmitsWarning(() => _launch($), $.pump);
  });
}
