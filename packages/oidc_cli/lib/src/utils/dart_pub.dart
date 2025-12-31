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
