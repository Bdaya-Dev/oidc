import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../../support/oidc_test_server.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  group('oidc token get / oidc token refresh', () {
    late Logger logger;
    late List<String> infoMessages;
    late List<String> errMessages;
    late PubUpdater pubUpdater;
    late OidcCliCommandRunner runner;
    late Directory tempDir;
    late String storePath;

    setUp(() {
      infoMessages = [];
      errMessages = [];
      logger = _MockLogger();
      when(() => logger.info(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) infoMessages.add(message);
      });
      when(() => logger.err(any())).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) errMessages.add(message);
      });
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
        'oidc_cli_token_command_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('get: no config at all -> no active session', () async {
      final result = await runner.run(['--store', storePath, 'token', 'get']);

      expect(result, ExitCode.software.code);
      expect(
        errMessages,
        contains('No active session. Please login first.'),
      );
    });

    test('refresh: no config at all -> no active session', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'token',
        'refresh',
      ]);

      expect(result, ExitCode.software.code);
      expect(
        errMessages,
        contains('No active session. Please login first.'),
      );
    });

    test(
      'get: config present but never logged in -> no active session',
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
          'token',
          'get',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains('No active session. Please login first.'),
        );
      },
    );

    test(
      'get: network failure resolving discovery is reported as an error',
      () async {
        // Bind then immediately close a loopback port, guaranteeing that
        // subsequent connections to it are refused.
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final deadPort = probe.port;
        await probe.close(force: true);

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': 'http://127.0.0.1:$deadPort',
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
          'port': 3000,
        });

        final result = await runner.run([
          '--store',
          storePath,
          'token',
          'get',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages.any((m) => m.startsWith('Error retrieving token: ')),
          isTrue,
        );
      },
    );

    test(
      'refresh: network failure resolving discovery is reported as an error',
      () async {
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final deadPort = probe.port;
        await probe.close(force: true);

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': 'http://127.0.0.1:$deadPort',
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
          'port': 3000,
        });

        final result = await runner.run([
          '--store',
          storePath,
          'token',
          'refresh',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages.any((m) => m.startsWith('Error refreshing token: ')),
          isTrue,
        );
      },
    );

    group('with an existing session', () {
      late TestOidcServer server;

      setUp(() async {
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            if (form['grant_type'] == 'refresh_token') {
              return server.tokenResponseJson(
                sub: 'user-1',
                expiresIn: 3600,
                accessToken: 'refreshed-access-token',
              );
            }
            // Login always issues a near-expiry token; individual tests
            // control whether auto-refresh kicks in on top of it.
            return server.tokenResponseJson(sub: 'user-1', expiresIn: 10);
          },
        );

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
      });

      tearDown(() => server.close());

      test('get: auto-refreshes an expiring token by default', () async {
        final result = await runner.run([
          '--store',
          storePath,
          'token',
          'get',
        ]);

        expect(result, ExitCode.success.code);
        expect(
          infoMessages,
          contains('Token expired or expiring soon. Refreshing...'),
        );
        expect(infoMessages, contains('refreshed-access-token'));
      });

      test(
        'get --no-auto-refresh prints the stored token unchanged',
        () async {
          final result = await runner.run([
            '--store',
            storePath,
            'token',
            'get',
            '--no-auto-refresh',
          ]);

          expect(result, ExitCode.success.code);
          expect(infoMessages, contains('access-token-abc'));
          expect(
            infoMessages,
            isNot(
              contains('Token expired or expiring soon. Refreshing...'),
            ),
          );
        },
      );

      test('refresh: unconditionally refreshes and prints new token', () async {
        final result = await runner.run([
          '--store',
          storePath,
          'token',
          'refresh',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Refreshing token...'));
        expect(infoMessages, contains('refreshed-access-token'));
      });
    });

    test(
      'refresh: config present but never logged in -> no active session',
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
          'token',
          'refresh',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains('No active session. Please login first.'),
        );
      },
    );

    group('with a session that has no refresh_token', () {
      late TestOidcServer server;

      setUp(() async {
        server = await TestOidcServer.start(
          onToken: (form, callCount) => server.tokenResponseJson(
            sub: 'user-1',
            expiresIn: 10,
            refreshToken: null,
          ),
        );

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
        errMessages.clear();
      });

      tearDown(() => server.close());

      test(
        'get: reports "No access token available." when auto-refresh '
        'cannot find a refresh_token',
        () async {
          final result = await runner.run([
            '--store',
            storePath,
            'token',
            'get',
          ]);

          expect(result, ExitCode.software.code);
          expect(
            infoMessages,
            contains('Token expired or expiring soon. Refreshing...'),
          );
          expect(errMessages, contains('No access token available.'));
        },
      );

      test(
        'refresh: reports "No access token available." when there is no '
        'refresh_token to use',
        () async {
          final result = await runner.run([
            '--store',
            storePath,
            'token',
            'refresh',
          ]);

          expect(result, ExitCode.software.code);
          expect(errMessages, contains('No access token available.'));
        },
      );
    });
  });
}
