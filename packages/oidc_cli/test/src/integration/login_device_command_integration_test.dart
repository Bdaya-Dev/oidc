import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/command_runner.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

String _base64UrlNoPadding(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _jwtNone(Map<String, dynamic> payload) {
  final header = <String, dynamic>{'alg': 'none', 'typ': 'JWT'};
  final headerPart = _base64UrlNoPadding(utf8.encode(jsonEncode(header)));
  final payloadPart = _base64UrlNoPadding(utf8.encode(jsonEncode(payload)));
  // For alg=none, signature is an empty string.
  return '$headerPart.$payloadPart.';
}

Future<void> _writeJson(HttpResponse response, Object json) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(json));
  await response.close();
}

typedef _RequestHandler = Future<void> Function(HttpRequest request);

Future<HttpServer> _startServer(_RequestHandler handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  // Keep the server running in the background for the duration of the test.
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      // Keep test server resilient; surface failures via assertions instead.
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  });
  return server;
}

void main() {
  group('integration-style: oidc login device', () {
    late Logger logger;
    late PubUpdater pubUpdater;

    setUp(() {
      logger = _MockLogger();
      pubUpdater = _MockPubUpdater();
    });

    test('runs device flow and prints access token', () async {
      final infoMessages = <String>[];
      when(() => logger.info(any(), style: null)).thenAnswer((invocation) {
        final message = invocation.positionalArguments.first;
        if (message is String) {
          infoMessages.add(message);
        }
      });

      final tempDir = await Directory.systemTemp.createTemp('oidc_cli_test_');
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final storePath = File('${tempDir.path}/store.json').path;

      var tokenPollCount = 0;
      late final HttpServer server;

      server = await _startServer((request) async {
        final path = request.uri.path;

        if (request.method == 'GET' &&
            path == '/.well-known/openid-configuration') {
          final issuer = Uri.parse('http://127.0.0.1:${server.port}');
          return _writeJson(request.response, {
            'issuer': issuer.toString(),
            'token_endpoint': issuer.replace(path: '/token').toString(),
            'device_authorization_endpoint': issuer
                .replace(path: '/device')
                .toString(),
            // omit userinfo_endpoint to avoid userinfo calls in validation
          });
        }

        if (request.method == 'POST' && path == '/device') {
          final issuer = Uri.parse('http://127.0.0.1:${server.port}');
          return _writeJson(request.response, {
            'device_code': 'device-code-123',
            'user_code': 'USER-CODE',
            'verification_uri': issuer.replace(path: '/verify').toString(),
            'verification_uri_complete': issuer
                .replace(
                  path: '/verify',
                  queryParameters: {
                    'user_code': 'USER-CODE',
                  },
                )
                .toString(),
            'expires_in': 30,
            'interval': 0,
          });
        }

        if (request.method == 'POST' && path == '/token') {
          tokenPollCount += 1;

          if (tokenPollCount == 1) {
            request.response.statusCode = HttpStatus.badRequest;
            return _writeJson(request.response, {
              'error': 'authorization_pending',
            });
          }

          final issuer = Uri.parse('http://127.0.0.1:${server.port}');
          final nowSeconds =
              DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          final idToken = _jwtNone({
            'iss': issuer.toString(),
            'aud': 'my-client',
            'sub': 'user-123',
            'iat': nowSeconds,
            'exp': nowSeconds + 300,
          });

          return _writeJson(request.response, {
            'access_token': 'access-token-abc',
            'id_token': idToken,
            'token_type': 'Bearer',
            'expires_in': 300,
          });
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      addTearDown(() async {
        await server.close(force: true);
      });

      final issuer = Uri.parse('http://127.0.0.1:${server.port}');

      final runner = OidcCliCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
        hasTerminal: () => false,
      );

      final exitCode = await runner.run([
        '--store',
        storePath,
        'login',
        'device',
        '--issuer',
        issuer.toString(),
        '--client-id',
        'my-client',
        '--scopes',
        'openid',
      ]);

      expect(exitCode, ExitCode.success.code);
      expect(tokenPollCount, greaterThanOrEqualTo(2));

      // Verify the command produced the expected user-facing output.
      expect(
        infoMessages.any(
          (m) => m.startsWith('Open this URL to authenticate: '),
        ),
        isTrue,
      );
      expect(infoMessages, contains('access-token-abc'));

      // Verify config is persisted by the command.
      final store = FileOidcStore.fromPath(storePath, logger: logger);
      final config = await store.getConfig();
      expect(config['issuer'], issuer.toString());
      expect(config['clientId'], 'my-client');
      expect(config['scopes'], ['openid']);
    });
  });
}
