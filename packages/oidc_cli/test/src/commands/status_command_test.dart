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
  group('oidc status', () {
    late Logger logger;
    late List<String> infoMessages;
    late List<String> warnMessages;
    late PubUpdater pubUpdater;
    late OidcCliCommandRunner runner;
    late Directory tempDir;
    late String storePath;

    setUp(() {
      infoMessages = [];
      warnMessages = [];
      logger = _MockLogger();
      when(() => logger.info(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) infoMessages.add(message);
      });
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.success(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) infoMessages.add(message);
      });
      when(() => logger.warn(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) warnMessages.add(message);
      });
      pubUpdater = _MockPubUpdater();
      runner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );
      tempDir = Directory.systemTemp.createTempSync(
        'oidc_cli_status_command_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('reports no configuration found when store is empty', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'status',
      ]);

      expect(result, ExitCode.success.code);
      expect(
        infoMessages,
        contains('Not logged in (no configuration found).'),
      );
    });

    test(
      'reports not logged in when config exists but no session',
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

        final result = await runner.run([
          '--store',
          storePath,
          'status',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Not logged in.'));
      },
    );

    test(
      'reports logged in with email claim and expiry for an active session',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            final nowSeconds =
                DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
            final idToken = server.signIdToken({
              'iss': server.issuer.toString(),
              'aud': 'my-client',
              'sub': 'user-1',
              'email': 'alice@example.com',
              'iat': nowSeconds,
              'exp': nowSeconds + 300,
            });
            return {
              'access_token': 'access-token-abc',
              'id_token': idToken,
              'token_type': 'Bearer',
              'expires_in': 3600,
              'refresh_token': 'refresh-token-1',
            };
          },
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

        final result = await runner.run([
          '--store',
          storePath,
          'status',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Logged in.'));
        expect(infoMessages, contains('User: alice@example.com'));
        expect(
          infoMessages.any((m) => m.startsWith('Token expires at: ')),
          isTrue,
        );
        expect(warnMessages, isNot(contains('(Expired)')));
      },
    );

    test(
      'warns when the session token is already expired',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) =>
              server.tokenResponseJson(sub: 'user-1', expiresIn: -3600),
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
          '--no-auto-refresh',
        ]);
        expect(loginResult, ExitCode.success.code);
        infoMessages.clear();
        warnMessages.clear();

        final result = await runner.run([
          '--store',
          storePath,
          'status',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Logged in.'));
        expect(warnMessages, contains('(Expired)'));
      },
    );
  });
}
