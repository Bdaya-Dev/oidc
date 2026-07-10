import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/cli_user_manager.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  // NOTE: `getAuthorizationResponse`/`getEndSessionResponse`'s success paths
  // call an internal `printFunction` that unconditionally shells out to the
  // OS's default browser opener (`rundll32`/`open`/`xdg-open`) via
  // `Process.run`, exactly like `CliUserManager.getAuthorizationResponse`'s
  // production implementation. The rest of this package's test suite
  // (see login_interactive_command_test.dart and pub_proxy_command_test.dart)
  // deliberately avoids ever triggering that side effect from an automated
  // test, so this file follows the same convention: it exercises
  // `startListenerAndGetUri` directly with a test-supplied `printFunction`
  // (covering the generic loopback-listener wiring), and it exercises
  // `getAuthorizationResponse`/`getEndSessionResponse` only up to the point
  // where they would need to invoke the real OS browser opener.
  late Directory tempDir;
  late FileOidcStore store;
  late Logger logger;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cli_user_manager_test_');
    store = FileOidcStore.fromPath('${tempDir.path}/store.json');
    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CliUserManager buildLazyManager() => CliUserManager.lazy(
    cliLogger: logger,
    discoveryDocumentUri: Uri.parse('https://op.example.com/.well-known/x'),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: store,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('http://127.0.0.1:0'),
    ),
  );

  group('construction', () {
    test('the eager constructor can be instantiated', () {
      final metadata = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
      });
      final manager = CliUserManager(
        cliLogger: logger,
        discoveryDocument: metadata,
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'c1',
        ),
        store: store,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('http://127.0.0.1:0'),
        ),
      );
      expect(manager, isNotNull);
      expect(manager.isWeb, isFalse);
    });

    test('the lazy constructor can be instantiated', () {
      final manager = buildLazyManager();
      expect(manager, isNotNull);
      expect(manager.isWeb, isFalse);
    });
  });

  group('startListenerAndGetUri', () {
    test(
      'replaces the port in the redirect URI when the requested port '
      '(0 = any) differs from the bound one, and resolves with the '
      'callback URI once a matching GET arrives',
      () async {
        final manager = buildLazyManager();
        final actualRedirectUriCompleter = Completer<Uri>();
        Uri? printedUri;

        final result = await manager.startListenerAndGetUri(
          originalRedirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 0,
            path: '/callback',
          ),
          redirectUriKey: 'redirect_uri',
          endpoint: Uri.parse('https://op.example.com/authorize'),
          requestParameters: {'response_type': 'code', 'client_id': 'c1'},
          logRequestDesc: 'authorization',
          actualRedirectUriCompleter: actualRedirectUriCompleter,
          printFunction: (uri) async {
            printedUri = uri;
            final redirectUriString = uri.queryParameters['redirect_uri'];
            final redirectUri = Uri.parse(redirectUriString!);
            final client = HttpClient();
            try {
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-xyz',
                },
              );
              final request = await client.getUrl(callbackUri);
              await (await request.close()).drain<void>();
            } finally {
              client.close(force: true);
            }
          },
        );

        expect(result, isNotNull);
        expect(result!.queryParameters['code'], 'auth-code-xyz');

        // The endpoint's own query parameters and the serialized request
        // parameters were merged into the printed authorize URI.
        expect(printedUri, isNotNull);
        expect(printedUri!.queryParameters['response_type'], 'code');
        expect(printedUri!.queryParameters['client_id'], 'c1');

        final actualRedirectUri = await actualRedirectUriCompleter.future;
        // Port 0 means "any free port": the bound port can never actually be
        // 0, so the port-replacement branch is always exercised here.
        expect(actualRedirectUri.port, isNot(0));
        expect(actualRedirectUri.path, '/callback');
      },
    );

    test(
      'keeps the original port untouched when the loopback listener binds '
      'to exactly the requested (non-zero) port',
      () async {
        // Find a free port, then release it immediately so the listener
        // below can bind to that exact same port.
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final freePort = probe.port;
        await probe.close(force: true);

        final manager = buildLazyManager();
        final actualRedirectUriCompleter = Completer<Uri>();

        final result = await manager.startListenerAndGetUri(
          originalRedirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: freePort,
            path: '/callback',
          ),
          redirectUriKey: 'redirect_uri',
          endpoint: Uri.parse('https://op.example.com/authorize'),
          requestParameters: const {},
          logRequestDesc: 'authorization',
          actualRedirectUriCompleter: actualRedirectUriCompleter,
          printFunction: (uri) async {
            final redirectUriString = uri.queryParameters['redirect_uri'];
            final redirectUri = Uri.parse(redirectUriString!);
            final client = HttpClient();
            try {
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-same-port',
                },
              );
              final request = await client.getUrl(callbackUri);
              await (await request.close()).drain<void>();
            } finally {
              client.close(force: true);
            }
          },
        );

        expect(result, isNotNull);
        expect(result!.queryParameters['code'], 'auth-code-same-port');

        final actualRedirectUri = await actualRedirectUriCompleter.future;
        expect(actualRedirectUri.port, freePort);
      },
    );
  });

  group('getAuthorizationResponse', () {
    test(
      'throws an OidcException when the provider has no '
      'authorizationEndpoint',
      () async {
        final manager = buildLazyManager();
        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          redirectUri: Uri(scheme: 'http', host: '127.0.0.1', port: 0),
          scope: const ['openid'],
        );

        await expectLater(
          manager.getAuthorizationResponse(
            metadata,
            request,
            const OidcPlatformSpecificOptions(),
            const {},
          ),
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

  group('getEndSessionResponse', () {
    test(
      'throws an OidcException when the provider has no endSessionEndpoint',
      () async {
        final manager = buildLazyManager();
        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
        });
        const request = OidcEndSessionRequest();

        await expectLater(
          manager.getEndSessionResponse(
            metadata,
            request,
            const OidcPlatformSpecificOptions(),
            const {},
          ),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('endSessionEndpoint'),
            ),
          ),
        );
      },
    );

    test(
      'returns null without starting a listener when there is no '
      'postLogoutRedirectUri',
      () async {
        final manager = buildLazyManager();
        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'end_session_endpoint': 'https://op.example.com/end-session',
        });
        const request = OidcEndSessionRequest();

        final result = await manager.getEndSessionResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        );

        expect(result, isNull);
      },
    );
  });

  group('platform hooks not applicable to a CLI', () {
    test('listenToFrontChannelLogoutRequests is an empty stream', () async {
      final manager = buildLazyManager();
      final stream = manager.listenToFrontChannelLogoutRequests(
        Uri.parse('http://127.0.0.1:0/front-channel'),
        const OidcFrontChannelRequestListeningOptions(),
      );
      expect(await stream.isEmpty, isTrue);
    });

    test('monitorSessionStatus is an empty stream', () async {
      final manager = buildLazyManager();
      final stream = manager.monitorSessionStatus(
        checkSessionIframe: Uri.parse('https://op.example.com/check-session'),
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-1',
          sessionState: 'session-state-1',
          interval: Duration(seconds: 2),
        ),
      );
      expect(await stream.isEmpty, isTrue);
    });

    test('prepareForRedirectFlow returns an empty map', () {
      final manager = buildLazyManager();
      final result = manager.prepareForRedirectFlow(
        const OidcPlatformSpecificOptions(),
      );
      expect(result, isEmpty);
    });
  });
}
