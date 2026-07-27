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
}
