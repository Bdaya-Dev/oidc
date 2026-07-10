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
  group('oidc login password', () {
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
        'oidc_cli_login_password_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('requires --username', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'password',
        '--password',
        'secret',
        '--issuer',
        'https://example.com',
        '--client-id',
        'my-client',
      ]);

      expect(result, ExitCode.usage.code);
      expect(errMessages, contains('Error: --username is required.'));
    });

    test('rejects a blank --username', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'password',
        '--username',
        '   ',
        '--password',
        'secret',
      ]);

      expect(result, ExitCode.usage.code);
      expect(errMessages, contains('Error: --username is required.'));
    });

    test('requires --password', () async {
      final result = await runner.run([
        '--store',
        storePath,
        'login',
        'password',
        '--username',
        'alice',
        '--issuer',
        'https://example.com',
        '--client-id',
        'my-client',
      ]);

      expect(result, ExitCode.usage.code);
      expect(errMessages, contains('Error: --password is required.'));
    });

    test(
      'requires --issuer/--client-id when no config is saved',
      () async {
        final result = await runner.run([
          '--store',
          storePath,
          'login',
          'password',
          '--username',
          'alice',
          '--password',
          'secret',
        ]);

        expect(result, ExitCode.usage.code);
        expect(
          errMessages,
          contains(
            'Error: --issuer and --client-id are required '
            '(or must exist in the saved config).',
          ),
        );
      },
    );

    test('logs in successfully and persists config + token', () async {
      late final TestOidcServer server;
      server = await TestOidcServer.start(
        onToken: (form, callCount) {
          expect(form['grant_type'], 'password');
          expect(form['username'], 'alice');
          expect(form['password'], 'secret');
          return server.tokenResponseJson(sub: 'user-1', expiresIn: 3600);
        },
      );
      addTearDown(server.close);

      final result = await runner.run([
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
        '--scopes',
        'openid profile',
      ]);

      expect(result, ExitCode.success.code);
      expect(infoMessages, contains('Authentication successful!'));
      expect(
        infoMessages,
        contains('Access Token: access-token-abc'),
      );

      final store = FileOidcStore.fromPath(storePath, logger: logger);
      final config = await store.getConfig();
      expect(config['issuer'], server.issuer.toString());
      expect(config['clientId'], 'my-client');
      expect(config['scopes'], ['openid', 'profile']);
      expect(config['port'], 3000);
    });

    test(
      'reuses --issuer/--client-id from previously saved config',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) =>
              server.tokenResponseJson(sub: 'user-1', expiresIn: 3600),
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
          'login',
          'password',
          '--username',
          'alice',
          '--password',
          'secret',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Authentication successful!'));
      },
    );

    test(
      'auto-refreshes when the returned token is expiring soon',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            if (callCount == 1) {
              expect(form['grant_type'], 'password');
              // Expires in 10s: below the 1-minute auto-refresh threshold.
              return server.tokenResponseJson(sub: 'user-1', expiresIn: 10);
            }
            expect(form['grant_type'], 'refresh_token');
            expect(form['refresh_token'], 'refresh-token-1');
            return server.tokenResponseJson(
              sub: 'user-1',
              expiresIn: 3600,
              accessToken: 'refreshed-access-token',
            );
          },
        );
        addTearDown(server.close);

        final result = await runner.run([
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

        expect(result, ExitCode.success.code);
        expect(
          infoMessages,
          contains('Token expired or expiring soon. Refreshing...'),
        );
        expect(
          infoMessages,
          contains('Access Token: refreshed-access-token'),
        );
      },
    );

    test(
      '--no-auto-refresh keeps the near-expiry token as-is',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            expect(callCount, 1, reason: 'refresh must not be attempted');
            return server.tokenResponseJson(sub: 'user-1', expiresIn: 10);
          },
        );
        addTearDown(server.close);

        final result = await runner.run([
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

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Access Token: access-token-abc'));
        expect(
          infoMessages,
          isNot(
            contains('Token expired or expiring soon. Refreshing...'),
          ),
        );
      },
    );

    test(
      'authenticates with a confidential client (--client-secret) using '
      'client_secret_post',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            expect(form['client_secret'], 'shh-its-a-secret');
            return server.tokenResponseJson(sub: 'user-1', expiresIn: 3600);
          },
        );
        addTearDown(server.close);

        final result = await runner.run([
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
          '--client-secret',
          'shh-its-a-secret',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('Authentication successful!'));
      },
    );

    test(
      'persists --add-to-dart-pub as hostedUrl even when the subsequent '
      'login attempt fails (so `dart pub token add` is never invoked)',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            // Fail the password grant with a network-level error so
            // `loginPassword` throws before ever reaching hostedUrl/pub
            // logic; the config write (including hostedUrl) already
            // happened earlier in `run()`.
            throw Exception('simulated token endpoint outage');
          },
        );
        addTearDown(server.close);

        await expectLater(
          runner.run([
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
            '--add-to-dart-pub',
            'https://pub.example.com',
          ]),
          throwsA(anything),
        );

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        final config = await store.getConfig();
        expect(config['hostedUrl'], 'https://pub.example.com');
      },
    );

    // NOTE: there is intentionally no test for the "Login failed." /
    // `user == null` branch below: `OidcUserManagerBase.loginPassword`
    // never returns `null` in this SDK -- on any failure (network error,
    // missing id_token, invalid signature, ...) `createUserFromToken` /
    // `OidcUser.fromIdToken` throw rather than returning `null` (verified
    // empirically: a token response with no id_token throws
    // `OidcException: Server didn't return the id_token.` instead of
    // resolving to `null`). The `if (user == null)` check is defensive
    // dead code given the current SDK behavior; see `bugsFound` in this
    // package's coverage report.

    test(
      'reports "Refresh failed." when the initial token has no '
      'refresh_token and the access token is expiring soon',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) => server.tokenResponseJson(
            sub: 'user-1',
            expiresIn: 10,
            refreshToken: null,
          ),
        );
        addTearDown(server.close);

        final result = await runner.run([
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

        expect(result, ExitCode.software.code);
        expect(
          infoMessages,
          contains('Token expired or expiring soon. Refreshing...'),
        );
        expect(errMessages, contains('Refresh failed.'));
      },
    );
  });
}
