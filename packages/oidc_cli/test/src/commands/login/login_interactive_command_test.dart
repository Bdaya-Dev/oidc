import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  // NOTE: the happy path of `login interactive` opens a real browser window
  // (via `rundll32`/`open`/`xdg-open`) and starts a real loopback HTTP
  // listener via `CliUserManager`, so it is intentionally not exercised
  // here; only the argument-validation paths (which run before any of that)
  // are covered.
  group('oidc login interactive', () {
    late Logger logger;
    late List<String> errMessages;
    late PubUpdater pubUpdater;
    late OidcCliCommandRunner runner;
    late Directory tempDir;
    late String storePath;

    setUp(() {
      errMessages = [];
      logger = _MockLogger();
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.err(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) errMessages.add(message);
      });
      pubUpdater = _MockPubUpdater();
      runner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );
      tempDir = Directory.systemTemp.createTempSync(
        'oidc_cli_login_interactive_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('requires --issuer and --client-id when both are missing', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'interactive',
      ]);

      expect(result, ExitCode.usage.code);
      expect(
        errMessages,
        contains('Error: --issuer and --client-id are required.'),
      );
    });

    test('requires --client-id when only --issuer is given', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'interactive',
        '--issuer',
        'https://example.com',
      ]);

      expect(result, ExitCode.usage.code);
      expect(
        errMessages,
        contains('Error: --issuer and --client-id are required.'),
      );
    });

    test('requires --issuer when only --client-id is given', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'interactive',
        '--client-id',
        'my-client',
      ]);

      expect(result, ExitCode.usage.code);
      expect(
        errMessages,
        contains('Error: --issuer and --client-id are required.'),
      );
    });
  });
}
