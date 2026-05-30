@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Drives a code -> token exchange so the DPoP proof injected at the token
/// endpoint can be observed. `getAuthorizationResponse` returns a code with the
/// request's own state, so the success handler reaches the token POST. User
/// creation then fails (the minimal token response has no id_token), but the
/// token POST — and its DPoP header — has already happened.
class _CodeFlowManager extends OidcUserManagerBase {
  _CodeFlowManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => OidcAuthorizeResponse.fromJson({
    'code': 'auth-code-1',
    'state': request.state,
  });

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

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

String? _header(http.Request r, String name) {
  for (final e in r.headers.entries) {
    if (e.key.toLowerCase() == name.toLowerCase()) return e.value;
  }
  return null;
}

Map<String, dynamic> _decode(String segment) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segment))))
        as Map<String, dynamic>;

void main() {
  Future<_CodeFlowManager> build(
    List<http.Request> tokenPosts, {
    required OidcDPoPSettings? dpop,
  }) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/token')) {
        tokenPosts.add(req);
        return http.Response(
          jsonEncode({'access_token': 'at', 'token_type': 'DPoP'}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final manager = _CodeFlowManager(
      discoveryDocument: _metadata(),
      clientCredentials: const OidcClientAuthentication.none(
        clientId: 'client-1',
      ),
      store: OidcMemoryStore(),
      httpClient: client,
      settings: OidcUserManagerSettings(
        redirectUri: Uri.parse('com.example.app://cb'),
        // Not testing id_token verification here.
        strictJwtVerification: false,
        dpop: dpop,
      ),
    );
    await manager.init();
    return manager;
  }

  Future<void> login(_CodeFlowManager m) async {
    try {
      await m.loginAuthorizationCodeFlow();
    } on Object {
      // User creation fails (no id_token in the minimal response); irrelevant
      // to the DPoP assertions, which are about the token request itself.
    }
  }

  test(
    'attaches a valid DPoP proof to the token request when enabled',
    () async {
      final posts = <http.Request>[];
      final manager = await build(posts, dpop: const OidcDPoPSettings());
      await login(manager);

      expect(posts, hasLength(1));
      final proof = _header(posts.single, 'DPoP');
      expect(
        proof,
        isNotNull,
        reason: 'token request must carry a DPoP header',
      );
      final parts = proof!.split('.');
      final header = _decode(parts[0]);
      final payload = _decode(parts[1]);
      expect(header['typ'], 'dpop+jwt');
      expect(header['alg'], 'ES256');
      expect((header['jwk']! as Map).containsKey('d'), isFalse);
      expect(payload['htm'], 'POST');
      expect(payload['htu'], 'https://op.example.com/token');
      expect(payload['jti'], isNotNull);
      // No access token at the token endpoint -> no ath.
      expect(payload.containsKey('ath'), isFalse);
    },
  );

  test('sends no DPoP header when DPoP is disabled (the default)', () async {
    final posts = <http.Request>[];
    final manager = await build(posts, dpop: null);
    await login(manager);

    expect(posts, hasLength(1));
    expect(_header(posts.single, 'DPoP'), isNull);
  });

  test(
    'reuses the same proof key across token requests (refresh binding)',
    () async {
      final posts = <http.Request>[];
      final manager = await build(posts, dpop: const OidcDPoPSettings());
      await login(manager);
      await login(manager);

      expect(posts, hasLength(2));
      Map<String, dynamic> jwkOf(http.Request r) =>
          _decode(_header(r, 'DPoP')!.split('.')[0])['jwk']!
              as Map<String, dynamic>;
      // Same session key -> identical embedded public jwk on both requests.
      expect(jwkOf(posts[0]), jwkOf(posts[1]));
    },
  );
}
