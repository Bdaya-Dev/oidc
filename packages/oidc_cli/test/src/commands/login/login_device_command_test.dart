import 'dart:convert';
import 'dart:io';

import 'package:jose_plus/jose.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

Future<void> _writeJson(HttpResponse response, Object json) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(json));
  await response.close();
}

/// A minimal local OIDC provider that supports the device_authorization
/// grant, so tests can drive `oidc login device` end to end without any
/// mocking of the SDK's HTTP layer.
class _DeviceTestServer {
  _DeviceTestServer._(this.server);

  final HttpServer server;
  int tokenPollCount = 0;

  /// When true, the token endpoint immediately succeeds. When false, it
  /// keeps returning `access_denied` until the poll gives up, so
  /// `loginDeviceCodeFlow` resolves to `null` (device auth never completed).
  bool succeeds = true;

  /// When false, the device endpoint omits `verification_uri_complete`.
  bool includeVerificationUriComplete = true;

  Uri get issuer => Uri.parse('http://127.0.0.1:${server.port}');

  static Future<_DeviceTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final signingKey = JsonWebKey.generate('RS256');
    final testServer = _DeviceTestServer._(server);

    server.listen((request) async {
      try {
        final path = request.uri.path;
        if (request.method == 'GET' &&
            path == '/.well-known/openid-configuration') {
          await _writeJson(request.response, {
            'issuer': testServer.issuer.toString(),
            'token_endpoint': testServer.issuer
                .replace(path: '/token')
                .toString(),
            'device_authorization_endpoint': testServer.issuer
                .replace(path: '/device')
                .toString(),
            'jwks_uri': testServer.issuer.replace(path: '/jwks').toString(),
            'id_token_signing_alg_values_supported': ['RS256'],
          });
          return;
        }
        if (request.method == 'GET' && path == '/jwks') {
          await _writeJson(request.response, {
            'keys': [
              {
                'kty': signingKey['kty'],
                'n': signingKey['n'],
                'e': signingKey['e'],
                'alg': 'RS256',
                'use': 'sig',
              },
            ],
          });
          return;
        }
        if (request.method == 'POST' && path == '/device') {
          final verification = testServer.issuer
              .replace(path: '/verify')
              .toString();
          await _writeJson(request.response, {
            'device_code': 'device-code-123',
            'user_code': 'USER-CODE',
            'verification_uri': verification,
            if (testServer.includeVerificationUriComplete)
              'verification_uri_complete': '$verification?user_code=USER-CODE',
            'expires_in': testServer.succeeds ? 30 : 1,
            'interval': 0,
          });
          return;
        }
        if (request.method == 'POST' && path == '/token') {
          testServer.tokenPollCount += 1;
          if (!testServer.succeeds) {
            request.response.statusCode = HttpStatus.badRequest;
            await _writeJson(request.response, {'error': 'access_denied'});
            return;
          }
          final nowSeconds =
              DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          final idToken =
              (JsonWebSignatureBuilder()
                    ..jsonContent = {
                      'iss': testServer.issuer.toString(),
                      'aud': 'my-client',
                      'sub': 'user-1',
                      'iat': nowSeconds,
                      'exp': nowSeconds + 300,
                    }
                    ..addRecipient(signingKey, algorithm: 'RS256'))
                  .build()
                  .toCompactSerialization();
          await _writeJson(request.response, {
            'access_token': 'device-access-token',
            'id_token': idToken,
            'token_type': 'Bearer',
            'expires_in': 300,
          });
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } on Object {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });

    return testServer;
  }

  Future<void> close() => server.close(force: true);
}

void main() {
  group('oidc login device', () {
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
        'oidc_cli_login_device_test_',
      );
      storePath = File('${tempDir.path}/store.json').path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'requires --issuer and --client-id when neither is given and no '
      'config is saved',
      () async {
        final result = await runner.run([
          '--store',
          storePath,
          'login',
          'device',
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

    test(
      'falls back to --issuer/--client-id from a previously saved config',
      () async {
        final server = await _DeviceTestServer.start();
        addTearDown(server.close);

        final store = FileOidcStore.fromPath(storePath, logger: logger);
        await store.setConfig({
          'issuer': server.issuer.toString(),
          'clientId': 'my-client',
          'clientSecret': null,
          'scopes': ['openid'],
        });

        final result = await runner.run([
          '--store',
          storePath,
          'login',
          'device',
        ]);

        expect(result, ExitCode.success.code);
        expect(infoMessages, contains('device-access-token'));
      },
    );

    test(
      'reports an incomplete device authorization without invoking '
      '`dart pub token add`, even when --add-to-dart-pub is set',
      () async {
        final server = await _DeviceTestServer.start()
          ..succeeds = false;
        addTearDown(server.close);

        final result = await runner.run([
          '--store',
          storePath,
          'login',
          'device',
          '--issuer',
          server.issuer.toString(),
          '--client-id',
          'my-client',
          '--add-to-dart-pub',
          'https://pub.example.com',
        ]);

        expect(result, ExitCode.software.code);
        expect(
          errMessages,
          contains('Device authorization did not complete.'),
        );

        // The hostedUrl was still persisted to config (built before the
        // login attempt), even though the login itself failed.
        final store = FileOidcStore.fromPath(storePath, logger: logger);
        final config = await store.getConfig();
        expect(config['hostedUrl'], 'https://pub.example.com');
      },
    );

    test(
      'prints the user code when the provider does not supply a '
      'verification_uri_complete',
      () async {
        final server = await _DeviceTestServer.start()
          ..includeVerificationUriComplete = false;
        addTearDown(server.close);

        final result = await runner.run([
          '--store',
          storePath,
          'login',
          'device',
          '--issuer',
          server.issuer.toString(),
          '--client-id',
          'my-client',
        ]);

        expect(result, ExitCode.success.code);
        expect(
          infoMessages.any(
            (m) => m.startsWith('Open this URL to authenticate: '),
          ),
          isTrue,
        );
        expect(infoMessages, contains('User code: USER-CODE'));
        expect(infoMessages, contains('device-access-token'));
      },
    );
  });
}
