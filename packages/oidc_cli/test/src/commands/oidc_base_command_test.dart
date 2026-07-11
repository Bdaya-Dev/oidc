import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:test/test.dart';

import '../support/oidc_test_server.dart';

class _MockLogger extends Mock implements Logger {}

/// A minimal concrete [OidcBaseCommand] used to directly exercise its
/// protected helper methods without going through a full CLI invocation
/// (and, in particular, without going through any command that would call
/// `addToDartPub`, which shells out to the real `dart` executable).
class _TestCommand extends OidcBaseCommand {
  _TestCommand({super.logger});

  @override
  final String name = 'test';

  @override
  final String description = 'test command';

  @override
  Future<int> run() async => 0;
}

void main() {
  late Logger logger;
  late Directory tempDir;
  late String storePath;

  setUp(() {
    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    tempDir = Directory.systemTemp.createTempSync('oidc_base_command_test_');
    storePath = File('${tempDir.path}/store.json').path;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('getStore', () {
    test(
      'falls back to the user-home store path when there is no --store '
      'override and no OIDC_CLI_STORE env var set',
      () async {
        // This test only passes when OIDC_CLI_STORE happens to be unset in
        // the environment `dart test` runs under (the common case, and true
        // for this repo's CI/local setup); `Platform.environment` has no
        // `IOOverrides` test seam in dart:io, so the env-var branch
        // (`OIDC_CLI_STORE` set) cannot be exercised in the same test run
        // as this one without cross-contaminating other tests that assume
        // the default (unset) environment.
        final envOverride = Platform.environment['OIDC_CLI_STORE'];

        final command = _TestCommand(logger: logger);
        final store = await command.getStore();

        if (envOverride != null && envOverride.trim().isNotEmpty) {
          expect(store.file.path, envOverride);
        } else {
          final expectedHome =
              Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'] ??
              '.';
          expect(
            store.file.path,
            FileOidcStore.userHome(logger: logger).file.path,
          );
          expect(store.file.path, contains(expectedHome));
          expect(store.file.path, contains('.oidc_cli'));
          expect(store.file.path, endsWith('store.json'));
        }
      },
    );
  });

  group('getManager', () {
    test('returns null when the config is empty', () async {
      final command = _TestCommand(logger: logger);
      final store = FileOidcStore.fromPath(storePath, logger: logger);

      final manager = await command.getManager(store: store);

      expect(manager, isNull);
    });

    test(
      'builds a confidential (client_secret_post) manager when clientSecret '
      'is present in the config',
      () async {
        final command = _TestCommand(logger: logger);
        final store = FileOidcStore.fromPath(storePath, logger: logger);

        final manager = await command.getManager(
          store: store,
          configOverride: {
            'issuer': 'https://op.example.com',
            'clientId': 'confidential-client',
            'clientSecret': 'shh-its-a-secret',
            'scopes': ['openid'],
            'port': 3000,
          },
        );

        expect(manager, isNotNull);
        expect(manager!.isWeb, isFalse);
      },
    );
  });

  group('getAccessTokenFromStoredSession', () {
    test('returns null when there is no saved config', () async {
      final command = _TestCommand(logger: logger);
      final store = FileOidcStore.fromPath(storePath, logger: logger);

      final token = await command.getAccessTokenFromStoredSession(
        store: store,
      );

      expect(token, isNull);
    });

    test(
      'auto-refreshes an expiring stored token and returns the refreshed '
      'access token',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) {
            if (form['grant_type'] == 'refresh_token') {
              return server.tokenResponseJson(
                sub: 'user-1',
                expiresIn: 3600,
                accessToken: 'refreshed-via-base-command',
              );
            }
            return server.tokenResponseJson(sub: 'user-1', expiresIn: 10);
          },
        );
        addTearDown(server.close);

        final command = _TestCommand(logger: logger);
        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': server.issuer.toString(),
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
          'port': 3000,
        });

        // Log in directly through the manager (bypassing any CLI command)
        // so a `currentUser` with a near-expiry token exists in the store.
        final loginManager = await command.getManager(store: store);
        await loginManager!.init();
        await loginManager.loginPassword(username: 'alice', password: 'x');
        await loginManager.dispose();

        final token = await command.getAccessTokenFromStoredSession(
          store: store,
        );

        expect(token, 'refreshed-via-base-command');
      },
    );
  });
}
