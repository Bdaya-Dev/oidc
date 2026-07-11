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

class _MockProgress extends Mock implements Progress {}

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

    group('completion', () {
      test('takes the fast track and returns success', () async {
        final result = await commandRunner.run(['completion']);
        expect(result, equals(ExitCode.success.code));
      });
    });

    group('update checks (attached to a terminal)', () {
      late OidcCliCommandRunner runnerWithTerminal;

      setUp(() {
        runnerWithTerminal = OidcCliCommandRunner(
          logger: logger,
          pubUpdater: pubUpdater,
          hasTerminal: () => true,
        );
      });

      test('shows a notice when a newer version is available', () async {
        const latest = '99.0.0';
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenAnswer((_) async => latest);

        final result = await runnerWithTerminal.run(['--version']);

        expect(result, equals(ExitCode.success.code));
        verify(() => pubUpdater.getLatestVersion(packageName)).called(1);
        verify(
          () => logger.info(
            any(that: contains('Update available!')),
          ),
        ).called(1);
      });

      test(
        'does not show a notice when already on the latest version',
        () async {
          when(
            () => pubUpdater.getLatestVersion(any()),
          ).thenAnswer((_) async => packageVersion);

          final result = await runnerWithTerminal.run(['--version']);

          expect(result, equals(ExitCode.success.code));
          verifyNever(
            () => logger.info(any(that: contains('Update available!'))),
          );
        },
      );

      test('reports an error when the update check throws', () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenThrow(Exception('network down'));

        final result = await runnerWithTerminal.run(['--version']);

        expect(result, equals(ExitCode.success.code));
        verify(() => logger.err('Failed to check for updates.')).called(1);
      });

      test('skips the update check when running the update command', () async {
        when(
          () => pubUpdater.getLatestVersion(any()),
        ).thenAnswer((_) async => packageVersion);
        when(
          () => pubUpdater.update(
            packageName: any(named: 'packageName'),
            versionConstraint: any(named: 'versionConstraint'),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, ExitCode.success.code, null, null),
        );
        final progress = _MockProgress();
        when(() => logger.progress(any())).thenReturn(progress);
        when(() => progress.complete(any())).thenReturn(null);
        when(() => progress.fail(any())).thenReturn(null);

        final result = await runnerWithTerminal.run(['update']);

        expect(result, equals(ExitCode.success.code));
        // `getLatestVersion` is called once by `UpdateCommand.run()` itself,
        // but `OidcCliCommandRunner._checkForUpdates` must not call it a
        // second time when the command being run *is* `update`.
        verify(() => pubUpdater.getLatestVersion(packageName)).called(1);
      });
    });
  });
}
