@TestOn('vm')
library;

// Audit #324 item 20: the PKCE `code_verifier` must not be persisted in the
// plaintext `state` namespace. It now lives in the `secureTokens` namespace
// (encrypted at rest on web, secure-storage-backed on mobile/desktop) keyed by
// the state id, with a one-release read fallback to the (legacy) in-payload
// value so flows already in flight across an app upgrade still complete.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Drives a `code` -> token exchange so the `code_verifier` the token request
/// carries can be observed. `getAuthorizationResponse` echoes the request's own
/// state back with a code, so the success handler reaches the token POST. User
/// creation then fails (the minimal token response has no id_token), but the
/// token POST — and its `code_verifier` — has already happened.
class _CodeFlowManager extends OidcUserManagerBase {
  _CodeFlowManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  OidcAuthorizeRequest? lastAuthRequest;

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    lastAuthRequest = request;
    return OidcAuthorizeResponse.fromJson({
      'code': 'auth-code-1',
      'state': request.state,
    });
  }

  /// Exposes the `@protected` success handler so the compatibility test can
  /// drive it against a pre-seeded (legacy-format) state.
  Future<OidcUser?> exposeHandleSuccess(
    OidcAuthorizeResponse response,
    OidcProviderMetadata metadata,
  ) => handleSuccessfulAuthResponse(
    response: response,
    grantType: OidcConstants_GrantType.authorizationCode,
    metadata: metadata,
  );

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
  'scopes_supported': ['openid'],
});

void main() {
  group('prepareAuthorizationCodeFlowRequest (write side)', () {
    late OidcMemoryStore store;
    setUp(() async {
      store = OidcMemoryStore();
      await store.init();
    });

    test(
      'persists the code_verifier in secureTokens, not the state payload',
      () async {
        final container =
            await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
              metadata: _metadata(),
              store: store,
              input: OidcSimpleAuthorizationCodeFlowRequest(
                clientId: 'client-1',
                redirectUri: Uri.parse('com.example.app://cb'),
                scope: const ['openid'],
              ),
            );
        final stateId = container.request.state!;

        // The plaintext state payload must NOT carry the code_verifier.
        final rawState = await store.getStateData(stateId);
        expect(rawState, isNotNull);
        final decodedState = jsonDecode(rawState!) as Map<String, dynamic>;
        expect(decodedState['code_verifier'], isNull);
        // ...but it keeps the (public) code_challenge that went into the URL.
        expect(decodedState['code_challenge'], container.request.codeChallenge);

        // The code_verifier lives in secureTokens, keyed by the state id, and
        // matches the challenge that was sent on the authorization request.
        final storedVerifier = await store.getStateCodeVerifier(stateId);
        expect(storedVerifier, isNotNull);
        expect(
          OidcPkcePair.generateS256Challenge(storedVerifier!),
          container.request.codeChallenge,
        );
      },
    );
  });

  group('authorize -> redirect round-trip (new location)', () {
    Future<_CodeFlowManager> build(List<http.Request> tokenPosts) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          tokenPosts.add(req);
          return http.Response(
            jsonEncode({'access_token': 'at', 'token_type': 'Bearer'}),
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
        ),
      );
      await manager.init();
      return manager;
    }

    test(
      'the token request carries the code_verifier read back from secureTokens',
      () async {
        final posts = <http.Request>[];
        final manager = await build(posts);
        try {
          await manager.loginAuthorizationCodeFlow();
        } on Object {
          // User creation fails (no id_token); irrelevant to this assertion,
          // which is about the token request that already happened.
        }

        expect(posts, hasLength(1));
        final body = Uri.splitQueryString(posts.single.body);
        // Had the reader relied only on the now-stripped state payload, this
        // would be absent (the token model omits a null code_verifier).
        expect(body['code_verifier'], isNotNull);
        // The verifier that reached the token endpoint is the one behind the
        // challenge that went out on the authorization request.
        expect(
          OidcPkcePair.generateS256Challenge(body['code_verifier']!),
          manager.lastAuthRequest!.codeChallenge,
        );
      },
    );

    test(
      'the secureTokens code_verifier is cleared once the flow is handled',
      () async {
        final posts = <http.Request>[];
        final manager = await build(posts);
        try {
          await manager.loginAuthorizationCodeFlow();
        } on Object {
          // See above.
        }

        final stateId = manager.lastAuthRequest!.state!;
        expect(await manager.store.getStateCodeVerifier(stateId), isNull);
        // The state payload is cleared too (unchanged behavior).
        expect(await manager.store.getStateData(stateId), isNull);
      },
    );
  });

  group('backward compatibility (legacy in-payload code_verifier)', () {
    test(
      'a flow whose code_verifier is still embedded in the state payload '
      '(no secureTokens entry) completes via the fallback',
      () async {
        final posts = <http.Request>[];
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            posts.add(req);
            return http.Response(
              jsonEncode({'access_token': 'at', 'token_type': 'Bearer'}),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final store = OidcMemoryStore();
        final manager = _CodeFlowManager(
          discoveryDocument: _metadata(),
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client-1',
          ),
          store: store,
          httpClient: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
          ),
        );
        await manager.init();

        // Simulate a state written by a version that still embedded the
        // code_verifier in the (plaintext) state payload, with nothing in
        // secureTokens — an in-flight flow captured mid app-upgrade.
        final legacyState = OidcAuthorizeState(
          id: 'legacy-state-1',
          codeVerifier: 'legacy-verifier',
          codeChallenge: OidcPkcePair.generateS256Challenge('legacy-verifier'),
          redirectUri: Uri.parse('com.example.app://cb'),
          clientId: 'client-1',
          nonce: 'hashed-nonce',
          originalUri: null,
          extraTokenParams: null,
          extraTokenHeaders: null,
          options: null,
        );
        await store.setStateData(
          state: legacyState.id,
          stateData: legacyState.toStorageString(),
        );
        expect(await store.getStateCodeVerifier(legacyState.id), isNull);

        try {
          await manager.exposeHandleSuccess(
            OidcAuthorizeResponse.fromJson({
              'code': 'auth-code-1',
              'state': legacyState.id,
            }),
            _metadata(),
          );
        } on Object {
          // User creation fails (no id_token); the token POST already happened.
        }

        expect(posts, hasLength(1));
        final body = Uri.splitQueryString(posts.single.body);
        // The token exchange used the embedded (legacy) verifier.
        expect(body['code_verifier'], 'legacy-verifier');
      },
    );
  });
}
