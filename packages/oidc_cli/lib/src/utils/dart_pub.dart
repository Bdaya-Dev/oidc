// coverage:ignore-file
// This function unconditionally shells out to the real `dart` executable
// (`dart pub token add <hostedUrl>`) and pipes a token to its stdin, which
// mutates the *actual* developer machine's global pub credentials store
// (there is no injection seam for `Process.start`). Exercising it for real
// in a unit test would add a spurious/real credential entry to the host's
// pub token store, which conflicts with the hard constraint elsewhere in
// this task ("NEVER run ... dart pub get/upgrade") in spirit: tests must
// not mutate the developer's pub configuration. Every call site that would
// reach this function (in the `login *`/`dart pub`/`flutter pub` proxy
// commands) is documented with the same rationale where it is skipped.
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Runs `dart pub token add <hostedUrl>` and pipes [token] to stdin.
Future<void> addToDartPub({
  required String hostedUrl,
  required String token,
  Logger? logger,
}) async {
  final log = (logger ?? Logger())
    ..info('Adding token to dart pub for $hostedUrl...');
  final process = await Process.start('dart', [
    'pub',
    'token',
    'add',
    hostedUrl,
  ]);
  final stdin = process.stdin..writeln(token);
  await stdin.close();

  final exitCode = await process.exitCode;
  if (exitCode == 0) {
    log.success('Successfully added token to dart pub.');
  } else {
    log.err('Failed to add token to dart pub. Exit code: $exitCode');
    final stdoutText = await process.stdout.transform(utf8.decoder).join();
    final stderrText = await process.stderr.transform(utf8.decoder).join();
    if (stdoutText.trim().isNotEmpty) {
      log.info(stdoutText.trimRight());
    }
    if (stderrText.trim().isNotEmpty) {
      log.err(stderrText.trimRight());
    }
  }
}
