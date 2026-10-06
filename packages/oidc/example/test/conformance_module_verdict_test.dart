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

  // A module is run again on a fresh instance only when the suite itself
  // proves it never saw the browser: anything else could replace a real
  // verdict with a luckier one.
  group('shouldRerunModuleOnFreshInstance', () {
    final noAuthorize = <Map<String, dynamic>>[
      {'msg': 'Setup Done', 'time': 1},
      {'msg': 'Discovery endpoint', 'startBlock': true, 'time': 2},
    ];
    final withAuthorize = <Map<String, dynamic>>[
      ...noAuthorize,
      {'msg': 'Authorization endpoint', 'startBlock': true, 'time': 3},
    ];

    test('reruns once when the suite received no authorization request', () {
      expect(
        shouldRerunModuleOnFreshInstance(
          loggedIn: false,
          attempt: 1,
          suiteLog: noAuthorize,
        ),
        isTrue,
      );
    });

    test('never reruns once an authorization request reached the suite '
        '(every negative module ends like this)', () {
      expect(
        shouldRerunModuleOnFreshInstance(
          loggedIn: false,
          attempt: 1,
          suiteLog: withAuthorize,
        ),
        isFalse,
      );
    });

    test('never reruns a rerun', () {
      expect(maxModuleReruns, 1);
      expect(
        shouldRerunModuleOnFreshInstance(
          loggedIn: false,
          attempt: 2,
          suiteLog: noAuthorize,
        ),
        isFalse,
      );
    });

    test('never reruns a login that succeeded', () {
      expect(
        shouldRerunModuleOnFreshInstance(
          loggedIn: true,
          attempt: 1,
          suiteLog: noAuthorize,
        ),
        isFalse,
      );
    });

    test('an unreadable (empty) log proves nothing, so no rerun', () {
      expect(
        shouldRerunModuleOnFreshInstance(
          loggedIn: false,
          attempt: 1,
          suiteLog: const [],
        ),
        isFalse,
      );
    });

    test('a log line that merely mentions authorization is not a request '
        'block', () {
      expect(
        suiteLogShowsAuthorizationRequest([
          {'msg': 'Authorization endpoint response params', 'time': 1},
        ]),
        isFalse,
      );
    });
  });

  // #469: on iOS the per-module failure line is the only harness output in
  // the job log, so it has to say by itself whether the suite ever received
  // the authorization request -- the question a stuck `status=WAITING`
  // negative module could not answer.
  group('describeSuiteLogForFailure', () {
    Map<String, dynamic> block(String msg, int time) => {
      'msg': msg,
      'startBlock': true,
      'time': time,
    };

    test('says so when the suite never received an authorization '
        'request', () {
      final digest = describeSuiteLogForFailure([
        {'msg': 'Setup Done', 'time': 1000},
        block('Discovery endpoint', 2000),
        block('Jwks endpoint', 2500),
      ]);
      expect(digest, contains('NO authorization request received'));
      expect(digest, contains('Discovery endpoint'));
      expect(digest, contains('Jwks endpoint'));
    });

    test('times every request block from the first authorization '
        'request', () {
      final digest = describeSuiteLogForFailure([
        block('Discovery endpoint', 9000),
        block('Authorization endpoint', 10000),
        {'msg': 'Created authorization code', 'time': 10100},
        block('Jwks endpoint', 15020),
      ]);
      expect(digest, isNot(contains('NO authorization request')));
      expect(digest, contains('Discovery endpoint@-1.00s'));
      expect(digest, contains('Authorization endpoint@+0.00s'));
      expect(digest, contains('Jwks endpoint@+5.02s'));
    });

    test('ends with the last entries, error included', () {
      final digest = describeSuiteLogForFailure([
        block('Authorization endpoint', 0),
        {'msg': 'one', 'time': 1},
        {'msg': 'two', 'time': 2},
        {
          'msg': 'Got unexpected HTTP call',
          'result': 'FAILURE',
          'error': 'boom',
          'time': 3,
        },
      ], tailLength: 2);
      expect(digest, contains('last 2:'));
      expect(digest, isNot(contains('one')));
      expect(digest, contains('two'));
      expect(digest, contains('[FAILURE]@+0.00s Got unexpected HTTP call'));
      expect(digest, contains('error: boom'));
    });

    test('places the first authorization request against the client login '
        'start when that is known', () {
      final entries = [
        block('Discovery endpoint', 100000),
        block('Authorization endpoint', 150000),
      ];
      expect(
        describeSuiteLogForFailure(entries, clientLoginStartedAtMs: 100250),
        contains(
          'first authorization request arrived 49.75s after the client '
          'started the login',
        ),
      );
      expect(
        describeSuiteLogForFailure(entries),
        isNot(contains('after the client started the login')),
      );
    });

    test('an empty log is reported, not hidden', () {
      expect(
        describeSuiteLogForFailure(const []),
        'suite log: empty or unreadable',
      );
    });
  });
}
