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
  group('oidc discovery', () {
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
      pubUpdater = _MockPubUpdater();
      runner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );
      tempDir = Directory.systemTemp.createTempSync(
        'oidc_cli_discovery_command_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'requires --issuer/--well-known when neither is given and no config '
      'is saved',
      () async {
        final result = await runner.run([
          '--store',
          storePath,
          'discovery',
        ]);

        expect(result, ExitCode.usage.code);
        expect(
          errMessages,
          contains('Error: --issuer (or --well-known) is required.'),
        );
      },
    );

    test('fetches and prints the discovery document for --issuer', () async {
      late final TestOidcServer server;
      server = await TestOidcServer.start(
        onToken: (form, callCount) => server.tokenResponseJson(sub: 'u1'),
      );
      addTearDown(server.close);

      final result = await runner.run([
        '--store',
        storePath,
        'discovery',
        '--issuer',
        server.issuer.toString(),
      ]);

      expect(result, ExitCode.success.code);
      expect(infoMessages, hasLength(1));
      expect(infoMessages.single, contains(server.issuer.toString()));
      expect(infoMessages.single, contains('"token_endpoint"'));
    });

    test(
      'falls back to the issuer saved in config when --issuer is omitted',
      () async {
        late final TestOidcServer server;
        server = await TestOidcServer.start(
          onToken: (form, callCount) => server.tokenResponseJson(sub: 'u1'),
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
          'discovery',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages.single, contains(server.issuer.toString()));
      },
    );

    test('--well-known takes precedence over --issuer', () async {
      late final TestOidcServer server;
      server = await TestOidcServer.start(
        onToken: (form, callCount) => server.tokenResponseJson(sub: 'u1'),
      );
      addTearDown(server.close);

      final wellKnown = server.issuer.replace(
        path: '/.well-known/openid-configuration',
      );

      final result = await runner.run([
        '--store',
        storePath,
        'discovery',
        '--issuer',
        'https://ignored.example.com',
        '--well-known',
        wellKnown.toString(),
      ]);

      expect(result, ExitCode.success.code);
      expect(infoMessages.single, contains(server.issuer.toString()));
      expect(infoMessages.single, isNot(contains('ignored.example.com')));
    });

    test('reports an error when the discovery fetch fails', () async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close(force: true);

      final result = await runner.run([
        '--store',
        storePath,
        'discovery',
        '--issuer',
        'http://127.0.0.1:$deadPort',
      ]);

      expect(result, ExitCode.software.code);
      expect(
        errMessages.any(
          (m) => m.startsWith('Error fetching discovery document: '),
        ),
        isTrue,
      );
    });
  });
}
