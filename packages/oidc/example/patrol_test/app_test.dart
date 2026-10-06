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
//
// CONFORMANCE_SHARD (CI sharding): the android/iOS/linux/windows CI jobs run
// every `patrol_test/*_test.dart` file in one `patrol test` invocation, so the
// 13 conformance plans below used to run sequentially in a single job -- the
// Hybrid RP plan alone takes ~262s, and all 13 together take ~13-14 minutes.
// `--dart-define=CONFORMANCE_SHARD=<name>` lets a CI matrix split them across
// parallel jobs instead. Every call below goes through [_registerPlan], which
// tags the plan with one of [_knownShards]; a job that doesn't shard passes
// nothing and gets the 'all' default, which registers every plan exactly as
// before sharding existed. A skipped/absent plan must never look like a pass,
// so an unknown shard tag or an unknown --dart-define value throws
// immediately, and a shard that selects zero plans fails loudly at the end of
// main() instead of letting `patrol test` report a quiet, empty green.

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

/// Which slice of the conformance plans this process should register. Read
/// once from `--dart-define=CONFORMANCE_SHARD=<name>`. See the file doc
/// comment above for why this exists.
const String _requestedShard = String.fromEnvironment(
  'CONFORMANCE_SHARD',
  defaultValue: 'all',
);

/// Every shard id a CI matrix is allowed to request, besides the 'all'
/// (unsharded) default.
const Set<String> _knownShards = {'basic', 'implicit', 'hybrid', 'rest'};

/// How many plans [_requestedShard] selected so far. Checked at the end of
/// [main] -- see [_registerPlan].
int _selectedPlanCount = 0;

/// Registers conformance plan [name] (tagged with [shard]) as a patrolTest.
///
/// Every conformance patrolTest call in [main] MUST go through this function
/// instead of calling `patrolTest` directly, so a plan can never silently end
/// up assigned to no shard. An unrecognized [shard] throws immediately (a
/// typo at the call site), which fails the whole process loudly rather than
/// quietly dropping a plan from every CI job that shards.
void _registerPlan(
  String shard,
  String name,
  Future<void> Function(PatrolIntegrationTester $) body,
) {
  if (!_knownShards.contains(shard)) {
    throw StateError(
      'Conformance plan "$name" is tagged with unknown shard "$shard" - '
      'expected one of $_knownShards.',
    );
  }
  if (_requestedShard != 'all' && _requestedShard != shard) {
    return;
  }
  _selectedPlanCount++;
  patrolTest(name, body);
}

void main() {
  ensureLoggingConfigured();

  if (_requestedShard != 'all' && !_knownShards.contains(_requestedShard)) {
    throw StateError(
      'Unknown CONFORMANCE_SHARD "$_requestedShard" - expected "all" or one '
      'of $_knownShards.',
    );
  }

  if (oidcConformanceToken.isEmpty) {
    // Unaffected by CONFORMANCE_SHARD: every shard job still proves it can
    // start the app when no live conformance run is possible (e.g. a
    // dependabot PR, which gets a secret store without
    // OIDC_CONFORMANCE_TOKEN). Running this in every shard is cheap (it is a
    // single smoke test) and keeps that guarantee regardless of which shard
    // a given job was assigned.
    patrolTest('Simple manager initializes correctly', ($) async {
      await runManagerSmokeTest(() => _launch($));
    });
  } else {
    _registerPlan('basic', 'OIDC Conformance: Basic RP', ($) async {
      await runOidcConformanceTest(() => _launch($));
    });

    // Config RP exercises the OP configuration the README lists as implemented
    // (OpenID Connect Discovery). Only the Basic plan was ever run, so that
    // claim has never been verified by the suite. A separate test so a Config
    // failure names itself instead of surfacing as a Basic regression.
    // Hybrid and Implicit exercise response types the Basic/Config plans never
    // request. The flow is chosen per-module from the suite's own variant, so
    // these need no special driving -- only the plan id.
    _registerPlan('hybrid', 'OIDC Conformance: Hybrid RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-hybrid-certification-test-plan',
      );
    });

    _registerPlan('implicit', 'OIDC Conformance: Implicit RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-implicit-certification-test-plan',
      );
    });

    // The four logout profiles, discovered from the suite's own api/plan/available
    // rather than guessed. Note the shape: they do NOT use the
    // `-certification-test-plan` suffix the other profiles use, which is why no
    // amount of searching produced them and why every guessed id would have
    // 400ed. Each is pinned to the `-rp-basic` variant, matching the profile
    // this library is certified against.
    _registerPlan('rest', 'OIDC Conformance: RP-Initiated Logout', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-rp-initiated-logout-rp-basic',
        clientAuthType: 'client_secret_basic',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Front-Channel Logout', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-front-channel-logout-rp-basic',
        clientAuthType: 'client_secret_basic',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Back-Channel Logout', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-back-channel-logout-rp-basic',
        clientAuthType: 'client_secret_basic',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Session Management', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-rp-session-management-rp-basic',
        clientAuthType: 'client_secret_basic',
      );
    });

    // Form Post and 3rd-party-init, from the suite's published list. Variant
    // rules are unknown for these; they omit clientAuthType, matching the
    // plans they most resemble. A wrong choice is named by the plan-creation
    // diagnostic and pinned in api.dart, not rediscovered.
    _registerPlan('rest', 'OIDC Conformance: Form Post Basic RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-formpost-basic-certification-test-plan',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Form Post Hybrid RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-formpost-hybrid-certification-test-plan',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Form Post Implicit RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-formpost-implicit-certification-test-plan',
      );
    });

    _registerPlan('rest', 'OIDC Conformance: 3rd Party-Init Login RP', (
      $,
    ) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-test-3rd-party-init-login-test-plan',
        extraPlanVariant: {'response_type': 'code'},
        clientAuthType: 'client_secret_basic',
      );
    });

    // Dynamic RP: the client registers itself at the OP rather than being
    // pre-provisioned, so this is the one plan that does NOT take
    // static_client. `dynamic_client` is the documented counterpart already
    // named in the harness's own variant comment, not a guess at a new value.
    _registerPlan('rest', 'OIDC Conformance: Dynamic RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-dynamic-certification-test-plan',
        clientRegistration: null,
        clientAuthType: 'client_secret_basic',
        requestType: null,
      );
    });

    _registerPlan('rest', 'OIDC Conformance: Config RP', ($) async {
      await runOidcConformanceTest(
        () => _launch($),
        planName: 'oidcc-client-config-certification-test-plan',
        // The discovery module rejects the plan outright without this; the
        // Basic plan defaults it, this one does not.
        clientAuthType: 'client_secret_basic',
      );
    });

    if (_requestedShard != 'all' && _selectedPlanCount == 0) {
      throw StateError(
        'CONFORMANCE_SHARD "$_requestedShard" selected zero conformance '
        'plans out of 13 known plans - check the shard tag on each '
        '_registerPlan call above. A skipped/absent plan must never look '
        'like a pass.',
      );
    }
  }
}
