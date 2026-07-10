import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../support/oidc_test_server.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  group('oidc logout', () {
    late Logger logger;
    late List<String> infoMessages;
    late PubUpdater pubUpdater;
    late OidcCliCommandRunner runner;
    late Directory tempDir;
    late String storePath;

    setUp(() {
      infoMessages = [];
      logger = _MockLogger();
      when(() => logger.info(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) infoMessages.add(message);
      });
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.warn(any())).thenReturn(null);
      when(() => logger.success(any())).thenAnswer((invocation) {
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
        'oidc_cli_logout_command_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('succeeds trivially when there is no saved config', () async {
      final result = await runner.run(['--store', storePath, 'logout']);

      expect(result, ExitCode.success.code);
      expect(infoMessages, contains('Logged out successfully.'));
    });

    test(
      'clears the session and reports success for an active login',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) =>
              server.tokenResponseJson(sub: 'user-1', expiresIn: 3600),
        );
        addTearDown(server.close);

        final loginResult = await runner.run([
          '--store',
          storePath,
          'login',
          'password',
          '--username',
          'alice',
          '--password',
          'secret',
          '--issuer',
          server.issuer.toString(),
          '--client-id',
          'my-client',
        ]);
        expect(loginResult, ExitCode.success.code);
        infoMessages.clear();

        final result = await runner.run(['--store', storePath, 'logout']);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Revoking refresh token...'));
        expect(infoMessages, contains('Revoking access token...'));
        expect(infoMessages, contains('Logged out successfully.'));

        // The user was forgotten: the manager should no longer report a
        // `currentUser` on the next command that loads the same store.
        final statusResult = await runner.run([
          '--store',
          storePath,
          'status',
        ]);
        expect(statusResult, ExitCode.success.code);
        expect(infoMessages, contains('Not logged in.'));
      },
    );

    test(
      'reports config present but no active session as a trivial success',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) => server.tokenResponseJson(sub: 'user-1'),
        );
        addTearDown(server.close);

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': server.issuer.toString(),
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
          'port': 3000,
        });

        final result = await runner.run(['--store', storePath, 'logout']);

        // The manager is created (config is non-empty), so it still logs
        // its revoke-attempt messages; `revokeRefreshToken`/
        // `revokeAccessToken` themselves are no-ops when there is no
        // `currentUser`.
        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Logged out successfully.'));
      },
    );
  });
}
