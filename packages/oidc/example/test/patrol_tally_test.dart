@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/patrol_tally.dart';

// patrol_log_plus counts a test into `Total` the moment it announces `start`
// (patrol_log_reader.dart:69 -- `totalTests => _singleEntries.length`), and the
// three result buckets are independent filters over that same list:
//
//   successfulTests -> status == success   (:72)
//   failedTests     -> status == failure   (:76)
//   skippedTests    -> status == skip      (:83)
//
// A test whose closing entry never arrives keeps `openingTestEntry.status`,
// which is `TestEntryStatus.start` (patrol_single_test_entry.dart:33), and
// `start` is matched by NONE of the three. So a vanished test is counted in
// Total and nowhere else, and `failedTestsCount == 0` sends
// web_test_backend.dart:649 down the "Playwright process exited unexpectedly"
// branch instead of "Some tests failed."
//
// That is how the web job printed `Total: 13, Successful: 11, Failed: 0,
// Skipped: 0` and exited 1 without naming either lost test (run 90178636000).
// The invariant `successful + failed + skipped == total` is exactly the
// assertion patrol does not make, so make it here, over patrol's own output.

/// The Hybrid/Implicit loss as it actually appeared in the web job, trimmed to
/// the lines the reconciler reads. Both markers are adjacent in the raw log --
/// no `✅`, no `❌`, no exception banner between them.
const _webJobLoss = '''
🧪 app_test OIDC Conformance: Basic RP
✅ OIDC Conformance: Basic RP [90m(patrol_test/app_test.dart)[0m [90m(26s)[0m
🧪 app_test OIDC Conformance: Hybrid RP
🧪 app_test OIDC Conformance: Implicit RP
🧪 app_test OIDC Conformance: RP-Initiated Logout
✅ OIDC Conformance: RP-Initiated Logout [90m(patrol_test/app_test.dart)[0m [90m(42s)[0m

Test summary:
📝 Total: 13
✅ Successful: 11
❌ Failed: 0
⏩ Skipped: 0
📊 Report: /home/runner/work/oidc/oidc/packages/oidc/example/report.xml
⏱️  Duration: 25m 30s
''';

/// A healthy run: every started test reported, and the buckets add up.
const _healthyRun = '''
🧪 app_test OIDC Conformance: Basic RP
✅ OIDC Conformance: Basic RP [90m(patrol_test/app_test.dart)[0m [90m(26s)[0m
🧪 app_test OIDC Conformance: Hybrid RP
❌ OIDC Conformance: Hybrid RP [90m(patrol_test/app_test.dart)[0m [90m(31s)[0m
⏩ app_test OIDC Conformance: Dynamic RP

Test summary:
📝 Total: 3
✅ Successful: 1
❌ Failed: 1
  - OIDC Conformance: Hybrid RP
⏩ Skipped: 1
📊 Report: /home/runner/work/oidc/oidc/packages/oidc/example/report.xml
⏱️  Duration: 2m 30s
''';

void main() {
  group('reconcilePatrolTally', () {
    test('accepts a run whose buckets add up to Total', () {
      final result = reconcilePatrolTally(_healthyRun, minimumTests: 3);
      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      expect(result.total, 3);
      expect(result.unreported, isEmpty);
    });

    test('rejects the web job run, and NAMES both tests that vanished', () {
      final result = reconcilePatrolTally(_webJobLoss, minimumTests: 13);

      // The bug this exists to catch: 11 + 0 + 0 != 13.
      expect(result.total, 13);
      expect(result.successful, 11);
      expect(result.failed, 0);
      expect(result.skipped, 0);
      expect(result.accountedFor, 11);
      expect(result.unaccountedFor, 2);

      expect(result.errors, isNotEmpty);
      final joined = result.errors.join('\n');
      // Naming the lost tests is the whole point: `Failed: 0` with exit 1 is
      // unreadable, and re-running CI to find out which profile broke costs a
      // 26-minute job.
      expect(joined, contains('OIDC Conformance: Hybrid RP'));
      expect(joined, contains('OIDC Conformance: Implicit RP'));
      // A test that DID report must not be blamed.
      expect(joined, isNot(contains('Basic RP')));
      expect(joined, isNot(contains('RP-Initiated Logout')));

      expect(
        result.unreported,
        containsAll(<String>[
          'OIDC Conformance: Hybrid RP',
          'OIDC Conformance: Implicit RP',
        ]),
      );
    });

    test('fails the count even when the lifecycle markers are absent, so a '
        'sharded or lifecycle-hidden run cannot pass silently', () {
      // patrol hides the 🧪/✅ lines when `hideTestLifecycle` is on
      // (web_test_backend.dart:608-626). The arithmetic must still hold; only
      // the NAMING degrades.
      const summaryOnly = '''
Test summary:
📝 Total: 13
✅ Successful: 11
❌ Failed: 0
⏩ Skipped: 0
''';
      final result = reconcilePatrolTally(summaryOnly, minimumTests: 13);
      expect(result.unaccountedFor, 2);
      expect(result.errors, isNotEmpty);
      expect(result.unreported, isEmpty);
      expect(
        result.errors.join('\n'),
        contains('2'),
        reason: 'the count must survive even when no name can be attached',
      );
    });

    test('rejects a run that printed no summary at all -- a job killed mid-run '
        'must not read as success', () {
      final result = reconcilePatrolTally(
        '🧪 app_test OIDC Conformance: Basic RP\n',
        minimumTests: 13,
      );
      expect(result.errors, isNotEmpty);
      expect(result.errors.join('\n'), contains('summary'));
    });

    test('enforces a minimum test count, so a run that executed nothing cannot '
        'pass', () {
      const ranOne = '''
🧪 app_test OIDC Conformance: Basic RP
✅ OIDC Conformance: Basic RP [90m(patrol_test/app_test.dart)[0m [90m(26s)[0m

Test summary:
📝 Total: 1
✅ Successful: 1
❌ Failed: 0
⏩ Skipped: 0
''';
      final result = reconcilePatrolTally(ranOne, minimumTests: 13);
      expect(result.unaccountedFor, 0);
      expect(result.errors, isNotEmpty);
      expect(
        result.errors.join('\n'),
        contains('13'),
        reason: 'the message must state the count that was expected',
      );
    });

    test('reads the last summary when a log contains more than one', () {
      // patrol prints its summary once per invocation; a re-run inside the same
      // step would append a second. The final one is the run being judged.
      const twoSummaries = '''
Test summary:
📝 Total: 1
✅ Successful: 1
❌ Failed: 0
⏩ Skipped: 0

Test summary:
📝 Total: 13
✅ Successful: 11
❌ Failed: 0
⏩ Skipped: 0
''';
      final result = reconcilePatrolTally(twoSummaries, minimumTests: 13);
      expect(result.total, 13);
      expect(result.unaccountedFor, 2);
    });
  });

  group('formatFindings', () {
    test('emits a GitHub Actions error annotation per finding', () {
      final result = reconcilePatrolTally(_webJobLoss, minimumTests: 13);
      final rendered = formatFindings(result);
      expect(rendered, contains('::error::'));
      expect(rendered, contains('OIDC Conformance: Hybrid RP'));
    });

    test('renders nothing for a healthy run', () {
      final result = reconcilePatrolTally(_healthyRun, minimumTests: 3);
      expect(formatFindings(result), isEmpty);
    });
  });
}
