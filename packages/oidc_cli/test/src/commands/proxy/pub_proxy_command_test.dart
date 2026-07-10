import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/commands/proxy/pub_proxy_command.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../../support/oidc_test_server.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  // NOTE: none of these tests result in a stored access token being found,
  // so the command never reaches `addToDartPub` (which shells out to the
  // real `dart pub token add` and would mutate the machine's actual pub
  // credentials). `cache list` forwarded to the real `dart` binary below is
  // read-only (deliberately NOT `--version`: that string collides with the
  // CLI's own global `-v, --version` flag, which short-circuits the whole
  // command runner before the subcommand even runs). The issuer always
  // points at a local fake OIDC server rather than a real host, so
  // discovery resolution is deterministic and offline-safe.
  group('oidc dart pub (proxy)', () {
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
        'oidc_cli_pub_proxy_command_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('description explains what the command proxies', () {
      final command = PubProxyCommand(executable: 'dart', logger: logger);
      expect(command.description, contains('Proxy commands to `<tool> pub'));
    });

    test(
      'forwards to `dart pub` and returns its exit code when no '
      'hostedUrl is configured',
      () async {
        final result = await runner.run([
          '--store',
          storePath,
          'dart',
          'pub',
          'cache',
          'list',
        ]);

        expect(result, ExitCode.success.code);
      },
    );

    test(
      'errors when a hostedUrl is configured but there is no active '
      'session',
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
          'hostedUrl': 'https://pub.example.com',
        });

        final result = await runner.run([
          '--store',
          storePath,
          'dart',
          'pub',
          'cache',
          'list',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains(
            'No active session/token found for pub. '
            'Run `oidc login --add-to-dart-pub <hostedUrl>` first.',
          ),
        );
      },
    );

    test(
      '--hosted-url overrides the saved config (missing) hostedUrl for '
      'the check',
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
          'dart',
          'pub',
          '--hosted-url',
          'https://override.example.com',
          'cache',
          'list',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains(
            'No active session/token found for pub. '
            'Run `oidc login --add-to-dart-pub <hostedUrl>` first.',
          ),
        );
      },
    );

    test(
      'errors when the stored session has a blank (non-null) access token',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) =>
              server.tokenResponseJson(sub: 'user-1', accessToken: ''),
        );
        addTearDown(server.close);

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': server.issuer.toString(),
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
          'port': 3000,
          'hostedUrl': 'https://pub.example.com',
        });

        // Log in directly through the CLI's manager wiring so a
        // `currentUser` with a blank access token exists in the store.
        final loginResult = await runner.run([
          '--store',
          storePath,
          'login',
          'password',
          '--username',
          'alice',
          '--password',
          'secret',
        ]);
        expect(loginResult, ExitCode.success.code);
        errMessages.clear();

        final result = await runner.run([
          '--store',
          storePath,
          'dart',
          'pub',
          'cache',
          'list',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains(
            'No active session/token found for pub. '
            'Run `oidc login --add-to-dart-pub <hostedUrl>` first.',
          ),
        );
      },
    );
  });
}
