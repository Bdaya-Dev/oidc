@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/manager.dart';

// The conformance harness runs unattended: no user can dismiss a browser or
// complete a login. `flowTimeoutSeconds` is what makes a redirect that never
// arrives fail fast instead of waiting forever, and its dartdoc says so
// outright -- "otherwise loginAuthorizationCodeFlow() and logout hang
// indefinitely and leak the bound loopback socket".
//
// It was set for android/ios/macos and left null for linux/windows. Those are
// exactly the platforms where the Config RP plan hung until GitHub Actions
// killed the job ten minutes later, taking a pile of orphan chrome processes
// with it. The three platforms that had a timeout passed.
//
// A hang is a bad failure mode to test with: it produces no assertion, no
// message, and no stack -- just a dead job and a bill for the runner minutes.
// So assert the configuration instead, where it is cheap and immediate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = conformanceManager(
    'https://www.certification.openid.net/test/abc',
    clientId: 'my_client',
    clientSecret: 'my_client_secret',
    redirectUri: Uri.parse('http://localhost:22434'),
  );
  final options = manager.settings.options!;

  test('every platform the conformance suite runs on has a flow timeout', () {
    expect(
      options.linux.flowTimeoutSeconds,
      isNotNull,
      reason:
          'linux drives the loopback listener; without a timeout a redirect '
          'that never arrives hangs the whole job',
    );
    expect(
      options.windows.flowTimeoutSeconds,
      isNotNull,
      reason: 'windows drives the same loopback listener as linux',
    );
    expect(
      options.web.flowTimeoutSeconds,
      isNotNull,
      reason:
          'web hung identically; hiddenIframeTimeout does not cover the popup '
          'the interactive flow uses',
    );
    // Regression: these three were already set, and are the reason
    // macos/ios/android pass while the others hang.
    expect(options.macos.flowTimeoutSeconds, isNotNull);
    expect(options.ios.flowTimeoutSeconds, isNotNull);
    expect(options.android.flowTimeoutSeconds, isNotNull);
  });

  test('the timeout is short enough to fail before the CI job is killed', () {
    // The linux job was killed at ~10 min. A per-module timeout has to leave
    // room for the remaining modules to still run, otherwise the first hang
    // consumes the budget and the rest of the plan never reports.
    for (final (name, seconds) in [
      ('linux', options.linux.flowTimeoutSeconds),
      ('windows', options.windows.flowTimeoutSeconds),
    ]) {
      expect(
        seconds,
        allOf(greaterThan(0), lessThanOrEqualTo(60)),
        reason:
            '$name: a timeout longer than a minute per module cannot '
            'complete a 6-module plan inside the job limit',
      );
    }
  });

  // Web was left out of the budget check above, and web is where the budget is
  // tightest: it runs the LARGEST plans against the SHORTEST per-test cap.
  //
  //   * Hybrid RP is 48 modules and Implicit RP is 27 (shared_e2e.dart:313-322).
  //   * Patrol drives web through Playwright, whose per-test cap defaults to
  //     10 minutes (patrol_plus/web_runner/playwright.config.ts:66 --
  //     `timeout: timeout ?? 10 * 60 * 1000`). The web job pins the same value
  //     explicitly via `--web-timeout`.
  //
  // At 30s per module, one plan in which every module times out needs
  // 48 x 30s = 1440s against a 600s cap. It cannot finish, so Playwright kills
  // the test mid-plan -- and a killed test never emits a closing patrol entry,
  // which is exactly the reporting hole that made the web job print
  // "Total: 13, Successful: 11, Failed: 0" and exit 1 with no name attached
  // (run 90178636000: Hybrid and Implicit each consumed ~629s and emitted
  // nothing at all).
  //
  // The budget is what decides whether a broken plan REPORTS or VANISHES. Sized
  // so the plan runs to completion and fails on its own
  // `successfulLogins > 0` assertion -- which names the plan and dumps the
  // per-module suite status -- instead of being killed with no output.
  group('the web budget lets the largest plan finish inside Playwright cap', () {
    // The cap the web job PASSES, not Playwright's 600s default
    // (patrol_plus/web_runner/playwright.config.ts:66): the job runs
    // `patrol test --web-timeout 900000`. Keep the two in step -- this
    // constant is the only thing tying the arithmetic to that flag.
    const playwrightPerTestCapSeconds = 900;
    // shared_e2e.dart:313-322 lists the module counts; Hybrid is the largest.
    const largestPlanModules = 48;
    // Module-instance creation, the setup poll loop, the suite-status fetch and
    // the per-module log fetch all run OUTSIDE the browser flow, and the
    // harness pays them once PER MODULE -- not once per plan. Charging them
    // once was the first version of this assertion, and it let 48 x 10 + 60 =
    // 540 read as fitting while the real cost was 686s.
    //
    // 4.3s measured on the eight back-channel modules of
    // oidcc-client-back-channel-logout-rp-basic (linux, commit 05b0c84): each
    // took 34-35s wall against flowTimeoutSeconds: 30. Rounded UP, because
    // web pays more than linux for the same work -- its suite traffic goes
    // through a CORS proxy (shared_e2e.dart builds the Dio baseUrl through
    // cors-proxy.bdaya-dev.workers.dev when kIsWeb).
    const perModuleOverheadSeconds = 5;
    // Plan creation and the final aggregate, paid once.
    const perPlanOverheadSeconds = 20;

    test('a plan whose every module times out still fits', () {
      final webTimeout = options.web.flowTimeoutSeconds;
      expect(webTimeout, isNotNull);
      final worstCase =
          largestPlanModules * (webTimeout! + perModuleOverheadSeconds) +
          perPlanOverheadSeconds;
      expect(
        worstCase,
        lessThanOrEqualTo(playwrightPerTestCapSeconds),
        reason:
            'web: $largestPlanModules modules x '
            '(${webTimeout}s flow + ${perModuleOverheadSeconds}s overhead) + '
            '${perPlanOverheadSeconds}s = ${worstCase}s exceeds the '
            '${playwrightPerTestCapSeconds}s Playwright per-test cap, so a '
            'plan in which the redirects do not arrive is KILLED mid-plan '
            'rather than failing. A killed test emits no closing patrol entry, '
            'so it is counted in Total and in none of '
            'successful/failed/skipped, and the job exits 1 naming nothing. '
            'Lower flowTimeoutSeconds for web in '
            'integration_test/conformance/manager.dart, or raise '
            '--web-timeout in the web job.',
      );
    });

    test('but is still generous relative to a healthy web flow', () {
      // A web module that succeeds completes well inside 2s end to end: the
      // Basic RP plan ran all 14 of its modules in 26s of wall clock in the
      // same job. The bound must fail a hang fast without being so tight that
      // a slow-but-working redirect is cut off.
      expect(
        options.web.flowTimeoutSeconds,
        greaterThanOrEqualTo(10),
        reason:
            'anything under 10s is within an order of magnitude of a healthy '
            'flow and would start failing real redirects',
      );
    });
  });
}
