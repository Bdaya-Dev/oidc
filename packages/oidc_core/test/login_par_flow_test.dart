@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// A minimal concrete manager that captures the front-channel authorization URL
/// instead of launching a browser, so the PAR wiring inside
/// loginAuthorizationCodeFlow can be exercised end-to-end.
class _CapturingManager extends OidcUserManagerBase {
  _CapturingManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  final launchedUrls = <Uri>[];

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    launchedUrls.add(request.generateUri(metadata.authorizationEndpoint!));
    // Short-circuit: we only assert PAR ran + the front-channel URL shape.
    return null;
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) => const {};

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) => const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) => const Stream.empty();
}

OidcProviderMetadata _metadata({
  bool withParEndpoint = true,
  bool requirePar = false,
}) => OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
  if (withParEndpoint)
    'pushed_authorization_request_endpoint': 'https://op.example.com/par',
  'require_pushed_authorization_requests': requirePar,
});

void main() {
  group('OidcAuthorizeRequest.generateUri', () {
    OidcAuthorizeRequest req() => OidcAuthorizeRequest(
      clientId: 'client-1',
      redirectUri: Uri.parse('com.example.app://cb'),
      responseType: const [
        OidcConstants_AuthorizationEndpoint_ResponseType.code,
      ],
      scope: const ['openid'],
      state: 'state-1',
    );

    test('without requestUri emits the full parameter set (regression)', () {
      final uri = req().generateUri(
        Uri.parse('https://op.example.com/authorize'),
      );
      final qp = uri.queryParameters;
      expect(qp['client_id'], 'client-1');
      expect(qp['response_type'], 'code');
      expect(qp['redirect_uri'], 'com.example.app://cb');
      expect(qp['scope'], 'openid');
      expect(qp['state'], 'state-1');
      expect(qp.containsKey('request_uri'), isFalse);
    });

    test(
      'with requestUri emits ONLY client_id + request_uri (RFC 9126 §4)',
      () {
        final r = req()
          ..requestUri = Uri.parse('urn:ietf:params:oauth:request_uri:abc');
        final uri = r.generateUri(
          Uri.parse('https://op.example.com/authorize'),
        );
        final qp = uri.queryParameters;
        expect(qp.keys.toSet(), {'client_id', 'request_uri'});
        expect(qp['client_id'], 'client-1');
        expect(qp['request_uri'], 'urn:ietf:params:oauth:request_uri:abc');
      },
    );
  });

  group('loginAuthorizationCodeFlow PAR wiring', () {
    late OidcMemoryStore store;
    setUp(() => store = OidcMemoryStore());

    Future<_CapturingManager> build({
      required OidcPushedAuthorizationRequestsMode mode,
      required OidcProviderMetadata metadata,
      required List<http.Request> parPosts,
    }) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/par')) {
          parPosts.add(req);
          return http.Response(
            jsonEncode({
              'request_uri': 'urn:ietf:params:oauth:request_uri:xyz',
              'expires_in': 60,
            }),
            201,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _CapturingManager(
        discoveryDocument: metadata,
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'client-1',
        ),
        store: store,
        httpClient: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          pushedAuthorizationRequestsMode: mode,
        ),
      );
      await manager.init();
      return manager;
    }

    test(
      'always: posts PAR (no request_uri in body) and launches a '
      'request_uri-only URL',
      () async {
        final parPosts = <http.Request>[];
        final manager = await build(
          mode: OidcPushedAuthorizationRequestsMode.always,
          metadata: _metadata(),
          parPosts: parPosts,
        );
        await manager.loginAuthorizationCodeFlow();

        expect(parPosts, hasLength(1));
        final body = Uri.splitQueryString(parPosts.single.body);
        expect(body['client_id'], 'client-1');
        expect(body['response_type'], 'code');
        expect(body['scope'], 'openid');
        // RFC 9126 §2.1: request_uri MUST NOT be in the PAR request body.
        expect(body.containsKey('request_uri'), isFalse);

        expect(manager.launchedUrls, hasLength(1));
        final qp = manager.launchedUrls.single.queryParameters;
        expect(qp.keys.toSet(), {'client_id', 'request_uri'});
        expect(qp['request_uri'], 'urn:ietf:params:oauth:request_uri:xyz');
      },
    );

    test(
      'PAR body carries extra authorization parameters (back channel)',
      () async {
        final parPosts = <http.Request>[];
        final manager = await build(
          mode: OidcPushedAuthorizationRequestsMode.always,
          metadata: _metadata(),
          parPosts: parPosts,
        );
        await manager.loginAuthorizationCodeFlow(
          extraParameters: const {'custom_param': 'value-1'},
        );
        final body = Uri.splitQueryString(parPosts.single.body);
        // The whole point of PAR: parameters move to the authenticated back
        // channel instead of the front-channel URL.
        expect(body['custom_param'], 'value-1');
      },
    );

    test(
      'a stray request_uri in extra params is stripped from the PAR body '
      '(RFC 9126 §2.1)',
      () async {
        final parPosts = <http.Request>[];
        final manager = await build(
          mode: OidcPushedAuthorizationRequestsMode.always,
          metadata: _metadata(),
          parPosts: parPosts,
        );
        await manager.loginAuthorizationCodeFlow(
          extraParameters: const {'request_uri': 'urn:caller:bogus'},
        );
        final body = Uri.splitQueryString(parPosts.single.body);
        expect(body.containsKey('request_uri'), isFalse);
        // The front channel still uses the server-issued request_uri.
        expect(
          manager.launchedUrls.single.queryParameters['request_uri'],
          'urn:ietf:params:oauth:request_uri:xyz',
        );
      },
    );

    test('auto + server requires PAR: posts PAR', () async {
      final parPosts = <http.Request>[];
      final manager = await build(
        mode: OidcPushedAuthorizationRequestsMode.auto,
        metadata: _metadata(requirePar: true),
        parPosts: parPosts,
      );
      await manager.loginAuthorizationCodeFlow();
      expect(parPosts, hasLength(1));
    });

    test(
      'auto + server does not require PAR: no PAR (non-breaking default)',
      () async {
        final parPosts = <http.Request>[];
        final manager = await build(
          mode: OidcPushedAuthorizationRequestsMode.auto,
          metadata: _metadata(),
          parPosts: parPosts,
        );
        await manager.loginAuthorizationCodeFlow();
        expect(parPosts, isEmpty);
        final qp = manager.launchedUrls.single.queryParameters;
        expect(qp['response_type'], 'code');
        expect(qp.containsKey('request_uri'), isFalse);
      },
    );

    test('never: does not post PAR even when the server requires it', () async {
      final parPosts = <http.Request>[];
      final manager = await build(
        mode: OidcPushedAuthorizationRequestsMode.never,
        metadata: _metadata(requirePar: true),
        parPosts: parPosts,
      );
      await manager.loginAuthorizationCodeFlow();
      expect(parPosts, isEmpty);
    });

    test(
      'always but no PAR endpoint advertised: throws OidcException',
      () async {
        final parPosts = <http.Request>[];
        final manager = await build(
          mode: OidcPushedAuthorizationRequestsMode.always,
          metadata: _metadata(withParEndpoint: false),
          parPosts: parPosts,
        );
        await expectLater(
          manager.loginAuthorizationCodeFlow(),
          throwsA(isA<OidcException>()),
        );
        expect(parPosts, isEmpty);
      },
    );

    test('PAR endpoint error response propagates as OidcException', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/par')) {
          return http.Response(
            jsonEncode({'error': 'invalid_request'}),
            400,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _CapturingManager(
        discoveryDocument: _metadata(),
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'client-1',
        ),
        store: store,
        httpClient: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          pushedAuthorizationRequestsMode:
              OidcPushedAuthorizationRequestsMode.always,
        ),
      );
      await manager.init();
      await expectLater(
        manager.loginAuthorizationCodeFlow(),
        throwsA(isA<OidcException>()),
      );
    });
  });
}
