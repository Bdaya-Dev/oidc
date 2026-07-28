// Reconciles a patrol test run against patrol's OWN printed summary, and fails
// the job when the two disagree.
//
// WHY THIS EXISTS
//
// `patrol_log_plus` counts a test into `Total` as soon as it announces `start`
// (`patrol_log_reader.dart:69` -- `int get totalTests => _singleEntries.length`,
// appended on `TestEntryStatus.start`). The three result buckets are
// independent filters over that same list, matching `success`, `failure` and
// `skip` respectively (`:72`, `:76`, `:83`). A test whose closing entry never
// arrives keeps `openingTestEntry.status`
// (`patrol_single_test_entry.dart:33-34`), which is `start` -- and `start`
// matches NONE of the three buckets. The vanished test is therefore counted in
// `Total` and nowhere else.
//
// The consequence is not merely cosmetic. `failedTestsCount == 0` makes
// `web_test_backend.dart:649-654` take the `else if (exitCode != 0)` branch, so
// the run ends with the misleading "Playwright process exited unexpectedly with
// code 1" instead of "Some tests failed." -- and no test is ever named.
//
// Observed in the web job (run 90178636000): `Total: 13, Successful: 11,
// Failed: 0, Skipped: 0`, exit 1, and the only trace of the two lost profiles
// was that their `🧪` start markers were adjacent lines with nothing between
// them. Naming them cost a re-run of a 26-minute job.
//
// No code in patrol compares `total` against `successful + failed + skipped`.
// This does, over patrol's own stdout, so a test that starts and never reports
// counts as a FAILURE and says which one it was.
//
// Usage (CI):
//   dart run tool/patrol_tally.dart <log-file> --minimum-tests <n>
// Exits 1 and prints `::error::` annotations when the run does not reconcile.

import 'dart:io';

/// Strips SGR escape sequences. patrol colours the file path and the duration
/// on every closing line (`AnsiCodes.gray`), and writes cursor-clearing codes
/// when `clearTestSteps` is on, so raw CI stdout is not plain text.
final _ansi = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');

/// patrol's own lifecycle markers (`patrol_log_plus/lib/src/emojis.dart`).
const _startMarker = '🧪';
const _successMarker = '✅';
const _failureMarker = '❌';
const _skipMarker = '⏩';

/// The outcome of reconciling one patrol run.
class PatrolTallyResult {
  PatrolTallyResult({
    required this.total,
    required this.successful,
    required this.failed,
    required this.skipped,
    required this.started,
    required this.reported,
    required this.errors,
  });

  /// The four numbers patrol printed, or null when it printed no summary.
  final int? total;
  final int? successful;
  final int? failed;
  final int? skipped;

  /// Test names seen on a `🧪` line.
  final List<String> started;

  /// Test names seen on a `✅` / `❌` / `⏩` line.
  final List<String> reported;

  /// Human-readable reasons this run must not be treated as green. Empty means
  /// the run reconciles.
  final List<String> errors;

  /// `successful + failed + skipped` -- the tests patrol actually placed in a
  /// bucket.
  int? get accountedFor =>
      (successful == null || failed == null || skipped == null)
      ? null
      : successful! + failed! + skipped!;

  /// Tests counted in `Total` that landed in no bucket. Anything above zero is
  /// a test that started and never reported.
  int? get unaccountedFor {
    final counted = accountedFor;
    return (total == null || counted == null) ? null : total! - counted;
  }

  /// The names of the tests that started and never reported.
  ///
  /// Best effort: it is empty when patrol was run with the lifecycle lines
  /// hidden. [unaccountedFor] is the authoritative signal; this only attaches
  /// names to it.
  List<String> get unreported {
    final closed = reported.toSet();
    return started.where((name) => !closed.contains(name)).toList();
  }
}

/// Normalizes a test name so a `🧪` line and its matching `✅`/`❌` line
/// compare equal.
///
/// They are NOT printed the same way, and which shape applies is decided by the
/// marker, not by the text. `TestEntry.pretty()` branches on `isFinished`,
/// which is true for `success` and `failure` ONLY:
///
///   🧪 / ⏩  -> '<emoji> <name>'         -- keeps the leading file token
///   ✅ / ❌  -> '<emoji> <nameWithPath>'  -- `nameWithPath` DROPS the first
///                                          whitespace-delimited token and
///                                          appends `(<dir>/<file>.dart)`
///
/// and the closing line additionally carries a `(<n>s)` duration. So the file
/// token is stripped from the first shape and never from the second; guessing
/// from the text instead would eat the real first word of any test name whose
/// second word carries the punctuation the guess keyed on.
String _normalizeName(String raw, {required bool hasFileToken}) {
  var name = raw.replaceAll(_ansi, '').trim();
  // Drop the trailing `(...)` groups the closing line appends: the source path
  // and the execution time. Only parenthesised groups at the very end are
  // removed, so a test whose own name contains parentheses survives.
  final trailingGroup = RegExp(r'\s*\([^()]*\)$');
  while (trailingGroup.hasMatch(name)) {
    name = name.replaceFirst(trailingGroup, '').trim();
  }
  if (hasFileToken) {
    final firstSpace = name.indexOf(' ');
    // Only when something is left afterwards: a bare, unprefixed name must not
    // be normalized down to the empty string.
    if (firstSpace > 0 && firstSpace + 1 < name.length) {
      name = name.substring(firstSpace + 1).trim();
    }
  }
  return name;
}

int? _lastCount(List<String> lines, String label) {
  final pattern = RegExp('$label:\\s*([0-9]+)');
  int? found;
  for (final line in lines) {
    final match = pattern.firstMatch(line);
    if (match != null) {
      found = int.parse(match.group(1)!);
    }
  }
  return found;
}

/// Reconciles [log] -- the captured stdout of one `patrol_plus test` run.
///
/// [minimumTests] is a ratchet: patrol reports a run that executed nothing as a
/// clean pass, so a floor is the only way a green result can mean "the tests
/// ran". It mirrors the Android job's existing `Total:` gate.
PatrolTallyResult reconcilePatrolTally(
  String log, {
  required int minimumTests,
}) {
  final lines = log.split('\n');

  final started = <String>[];
  final reported = <String>[];
  for (final rawLine in lines) {
    final line = rawLine.replaceAll(_ansi, '').trim();
    // The summary block reuses the same emojis as prefixes for its counters
    // ("✅ Successful: 11"), so a line that carries a `<Label>: <n>` counter is
    // a summary line, not a lifecycle line.
    if (RegExp(r'^\S+\s+(Total|Successful|Failed|Skipped):').hasMatch(line)) {
      continue;
    }
    if (line.startsWith(_startMarker)) {
      started.add(
        _normalizeName(line.substring(_startMarker.length), hasFileToken: true),
      );
    } else if (line.startsWith(_successMarker)) {
      reported.add(
        _normalizeName(
          line.substring(_successMarker.length),
          hasFileToken: false,
        ),
      );
    } else if (line.startsWith(_failureMarker)) {
      reported.add(
        _normalizeName(
          line.substring(_failureMarker.length),
          hasFileToken: false,
        ),
      );
    } else if (line.startsWith(_skipMarker)) {
      // `skip` is not `isFinished`, so patrol prints the unmodified name.
      reported.add(
        _normalizeName(line.substring(_skipMarker.length), hasFileToken: true),
      );
    }
  }

  final total = _lastCount(lines, 'Total');
  final successful = _lastCount(lines, 'Successful');
  final failed = _lastCount(lines, 'Failed');
  final skipped = _lastCount(lines, 'Skipped');

  final result = PatrolTallyResult(
    total: total,
    successful: successful,
    failed: failed,
    skipped: skipped,
    started: started,
    reported: reported,
    errors: [],
  );

  if (total == null ||
      successful == null ||
      failed == null ||
      skipped == null) {
    result.errors.add(
      'patrol printed no complete test summary '
      '(Total/Successful/Failed/Skipped). A run killed before it could report '
      'must not be read as success.',
    );
    return result;
  }

  if (total < minimumTests) {
    result.errors.add(
      'patrol executed $total test(s), expected at least $minimumTests. '
      'patrol reports a run that executed nothing as a clean pass, so a '
      'green result without this floor does not mean the tests ran.',
    );
  }

  final residue = result.unaccountedFor!;
  if (residue > 0) {
    final names = result.unreported;
    result.errors.add(
      '$residue test(s) started and never reported: '
      '$successful successful + $failed failed + $skipped skipped = '
      '${result.accountedFor}, but Total is $total. patrol leaves such a test '
      'in `start` status, which none of its three counters match '
      '(patrol_single_test_entry.dart:33), so it is invisible in the summary '
      'and `Failed: 0` masks it. Treated as a FAILURE here.'
      '${names.isEmpty ? ' patrol printed no lifecycle markers, so the '
                'name(s) could not be recovered; re-run with the test '
                'lifecycle visible.' : '\n  Lost: ${names.join('\n  Lost: ')}'}',
    );
  } else if (residue < 0) {
    result.errors.add(
      'patrol reported more results ($successful + $failed + $skipped) than '
      'tests it started ($total); the summary is inconsistent.',
    );
  }

  return result;
}

/// Renders [result] as GitHub Actions error annotations. Empty when the run
/// reconciles.
String formatFindings(PatrolTallyResult result) {
  if (result.errors.isEmpty) {
    return '';
  }
  return result.errors
      // An annotation is one line: GitHub drops everything after the first
      // newline, so fold the detail into it.
      .map((e) => '::error::${e.replaceAll('\n', '%0A')}')
      .join('\n');
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/patrol_tally.dart <log-file> '
      '[--minimum-tests <n>]',
    );
    exit(64);
  }
  final logPath = args.first;
  var minimumTests = 1;
  final minIndex = args.indexOf('--minimum-tests');
  if (minIndex != -1 && minIndex + 1 < args.length) {
    minimumTests = int.parse(args[minIndex + 1]);
  }

  final file = File(logPath);
  if (!file.existsSync()) {
    stdout.writeln(
      '::error::patrol produced no log at $logPath, so the run cannot be '
      'reconciled.',
    );
    exit(1);
  }

  final result = reconcilePatrolTally(
    file.readAsStringSync(),
    minimumTests: minimumTests,
  );

  stdout.writeln(
    'patrol tally: Total=${result.total} Successful=${result.successful} '
    'Failed=${result.failed} Skipped=${result.skipped} '
    '(accounted for: ${result.accountedFor})',
  );

  if (result.errors.isEmpty) {
    stdout.writeln('patrol tally reconciles: every started test reported.');
    return;
  }
  stdout.writeln(formatFindings(result));
  exit(1);
}
