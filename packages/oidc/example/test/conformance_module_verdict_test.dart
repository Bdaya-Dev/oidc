@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/api.dart';

// #467: the harness used to gate an entire RP plan on
// `expect(successfulLogins, greaterThan(0))`, which only proves SOME module
// logged in. A negative module such as oidcc-client-test-missing-athash that
// WRONGLY logs in stays invisible to that aggregate as long as any other
// module in the plan still passes -- which is exactly how the implicit-flow
// at_hash gap shipped green in #447's CI.
//
// The fix asks the suite itself for each module's own verdict
// (`GET api/info/{id}`, TestInfoResponse.status/.result -- confirmed against
// real CI output and the suite's own OpenAPI document, see api.dart). These
// tests cover the pure classification of that verdict: which `status` values
// are terminal and which `result` values this harness accepts. Both are
// plain enums copied from TestModule.Status/TestModule.Result in the suite's
// Java source, so there is no live network call to fake here -- the thing
// worth pinning down offline is "does the mapping match the enum", not
// Dio's plumbing (already exercised, unmocked, by every CI run of
// runOidcConformanceTest).
void main() {
  group('isAcceptableConformanceResult', () {
    for (final result in ['PASSED', 'WARNING', 'REVIEW', 'SKIPPED']) {
      test('accepts $result', () {
        expect(isAcceptableConformanceResult(result), isTrue);
      });
    }

    for (final result in ['FAILED', 'UNKNOWN']) {
      test('rejects $result', () {
        expect(isAcceptableConformanceResult(result), isFalse);
      });
    }

    test('rejects null (never a verdict)', () {
      expect(isAcceptableConformanceResult(null), isFalse);
    });

    test(
      'rejects an unrecognised string rather than accepting it by default',
      () {
        // TestModule.Result is a closed Java enum; a value this harness has
        // never seen is far more likely to be a suite upgrade this code has not
        // been taught about yet than a new kind of success. Fail loud, not
        // open.
        expect(isAcceptableConformanceResult('SOME_FUTURE_RESULT'), isFalse);
      },
    );
  });

  group('isTerminalConformanceStatus', () {
    for (final status in ['FINISHED', 'INTERRUPTED']) {
      test('$status is terminal', () {
        expect(isTerminalConformanceStatus(status), isTrue);
      });
    }

    for (final status in [
      'NOT_YET_CREATED',
      'CREATED',
      'CONFIGURED',
      'RUNNING',
      'WAITING',
    ]) {
      test('$status is not terminal', () {
        expect(isTerminalConformanceStatus(status), isFalse);
      });
    }

    test('null is not terminal', () {
      expect(isTerminalConformanceStatus(null), isFalse);
    });
  });

  group('acceptableConformanceResults / terminalConformanceStatuses', () {
    // Guards the two sets against silently drifting apart from the functions
    // above (e.g. someone adds a value to the set but not the predicate, or
    // vice versa) since the harness's own failure-message text quotes the set
    // directly.
    test('every accepted result is reachable through the predicate', () {
      for (final result in acceptableConformanceResults) {
        expect(isAcceptableConformanceResult(result), isTrue, reason: result);
      }
    });

    test('every terminal status is reachable through the predicate', () {
      for (final status in terminalConformanceStatuses) {
        expect(isTerminalConformanceStatus(status), isTrue, reason: status);
      }
    });

    test("FAILED and INTERRUPTED (the suite's certification blockers) are not "
        'both accepted-as-result and terminal-as-status confused with each '
        'other', () {
      // FAILED is a RESULT value and must never be treated as a STATUS by
      // isTerminalConformanceStatus, nor should INTERRUPTED -- a STATUS --
      // ever be treated as an acceptable RESULT. The two enums share no
      // values today, but a typo'd lookup (passing a result where a status is
      // expected, or back) would otherwise fail silently rather than loudly.
      expect(isTerminalConformanceStatus('FAILED'), isFalse);
      expect(isAcceptableConformanceResult('INTERRUPTED'), isFalse);
    });
  });
}
