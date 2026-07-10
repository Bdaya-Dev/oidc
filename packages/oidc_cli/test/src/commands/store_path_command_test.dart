import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  group('oidc store-path', () {
    late Logger logger;
    late List<String> infoMessages;
    late PubUpdater pubUpdater;
    late OidcCliCommandRunner runner;
    late Directory tempDir;

    setUp(() {
      infoMessages = [];
      logger = _MockLogger();
      when(() => logger.info(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) infoMessages.add(message);
      });
      pubUpdater = _MockPubUpdater();
      runner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );
      tempDir = Directory.systemTemp.createTempSync(
        'oidc_cli_store_path_command_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('prints the absolute path of the --store override', () async {
      final storePath = File('${tempDir.path}/nested/store.json').path;

      final result = await runner.run([
        '--store',
        storePath,
        'store-path',
      ]);

      expect(result, ExitCode.success.code);
      expect(infoMessages, hasLength(1));
      expect(infoMessages.single, File(storePath).absolute.path);
    });

    test('is stable when given an already-absolute path', () async {
      final storePath = File('${tempDir.path}/store.json').absolute.path;

      final result = await runner.run([
        '--store',
        storePath,
        'store-path',
      ]);

      expect(result, ExitCode.success.code);
      expect(infoMessages.single, storePath);
    });
  });
}
