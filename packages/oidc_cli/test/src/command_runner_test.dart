import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/version.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  group('OidcCliCommandRunner', () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late OidcCliCommandRunner commandRunner;

    setUp(() {
      pubUpdater = _MockPubUpdater();

      logger = _MockLogger();

      commandRunner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );
    });

    test(
      'does not check for updates when not attached to a terminal',
      () async {
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verifyNever(() => pubUpdater.getLatestVersion(any()));
      },
    );

    test(
      'can be instantiated without an explicit analytics/logger instance',
      () {
        final commandRunner = OidcCliCommandRunner();
        expect(commandRunner, isNotNull);
        expect(commandRunner, isA<CompletionCommandRunner<int>>());
      },
    );

    test('handles FormatException', () async {
      const exception = FormatException('oops!');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info(commandRunner.usage)).called(1);
    });

    test('handles UsageException', () async {
      final exception = UsageException('oops!', 'exception usage');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info('exception usage')).called(1);
    });

    group('--version', () {
      test('outputs current version', () async {
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(packageVersion)).called(1);
      });
    });

    group('--verbose', () {
      test('enables verbose logging', () async {
        final result = await commandRunner.run(['--verbose']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verifyNever(() => logger.detail('    Command options:'));
      });

      test('enables verbose logging for sub commands', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'oidc_cli_command_runner_test_',
        );
        try {
          final storePath = '${tempDir.path}/store.json';
          final result = await commandRunner.run([
            '--verbose',
            '--store',
            storePath,
            'discovery',
            '--issuer',
            '',
          ]);
          expect(result, equals(ExitCode.usage.code));

          verify(() => logger.detail('Argument information:')).called(1);
          verify(() => logger.detail('  Top level options:')).called(1);
          verify(() => logger.detail('  - verbose: true')).called(1);
          verify(() => logger.detail('  - store: $storePath')).called(1);
          verify(() => logger.detail('  Command: discovery')).called(1);
          verify(() => logger.detail('    Command options:')).called(1);
          verify(() => logger.detail('    - issuer: ')).called(1);
        } finally {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        }
      });
    });
  });
}
