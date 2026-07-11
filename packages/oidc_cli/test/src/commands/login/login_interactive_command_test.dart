import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../../support/oidc_test_server.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

void main() {
  // NOTE: the happy path of `login interactive` opens a real browser window
  // (via `rundll32`/`open`/`xdg-open`) and starts a real loopback HTTP
  // listener via `CliUserManager`, so it is intentionally not exercised
  // here; only the argument-validation paths (which run before any of that)
  // are covered, plus the config-persistence/`getStore`/`getManager` wiring
  // that runs *before* `manager.init()` would ever reach the browser-opening
  // code (exercised below via an unreachable issuer, so `manager.init()`
  // itself fails fast on a connection error instead).
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

    test(
      'persists config (including hostedUrl) before attempting to reach '
      'the provider, even when the provider is unreachable',
      () async {
        // Bind then immediately close a loopback port, guaranteeing that
        // subsequent connections to it are refused: this fails inside
        // `manager.init()`, which happens *after* the config has already
        // been persisted, but *before* the interactive (browser-opening)
        // flow would ever be reached.
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final deadPort = probe.port;
        await probe.close(force: true);

        await expectLater(
          runner.run([
            '--store',
            storePath,
            'login',
            'interactive',
            '--issuer',
            'http://127.0.0.1:$deadPort',
            '--client-id',
            'my-client',
            '--add-to-dart-pub',
            'https://pub.example.com',
          ]),
          throwsA(anything),
        );

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        final config = await store.getConfig();
        expect(config['issuer'], 'http://127.0.0.1:$deadPort');
        expect(config['clientId'], 'my-client');
        expect(config['hostedUrl'], 'https://pub.example.com');
      },
    );

    test(
      'starts logging in (past a successful manager.init()) and fails fast '
      'without opening a browser when the provider does not advertise an '
      'authorizationEndpoint',
      () async {
        // `TestOidcServer`'s discovery document never advertises an
        // `authorization_endpoint`, so `manager.init()` succeeds (a real,
        // reachable provider), but `loginAuthorizationCodeFlow()` fails
        // fast with an `OidcException` *before* it would ever reach the
        // browser-opening code in `CliUserManager.getAuthorizationResponse`.
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) => server.tokenResponseJson(sub: 'user-1'),
        );
        addTearDown(server.close);

        await expectLater(
          runner.run([
            '--store',
            storePath,
            'login',
            'interactive',
            '--issuer',
            server.issuer.toString(),
            '--client-id',
            'my-client',
          ]),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('authorizationEndpoint'),
            ),
          ),
        );
      },
    );
  });
}
