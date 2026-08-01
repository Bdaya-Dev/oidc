@TestOn('vm')
library;

// Audit #324 item 20: the PKCE `code_verifier` must not be persisted in the
// plaintext `state` namespace. It lives in the `secureTokens` namespace
// (encrypted at rest on web, secure-storage-backed on mobile/desktop) keyed by
// the state id, and that is now the ONLY place it is read from (#404): the
// legacy in-payload fallback is gone, so a plaintext `state` payload can no
// longer supply the secret that completes a token exchange.

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

  /// Extra parameters folded into the simulated authorization response, so a
  /// test can model an OP — or anyone able to shape the redirect — putting a
  /// `code_verifier` on the response.
  Map<String, dynamic> extraResponseParams = const {};

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
      ...extraResponseParams,
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
      'a code_verifier on the authorization response never outranks the '
      'stored one',
      () async {
        final posts = <http.Request>[];
        final manager = await build(posts)
          // The authorization response arrives over redirect parameters, so
          // its contents are attacker-influenced. A `code_verifier` there must
          // not be able to displace the one this client generated and stored.
          ..extraResponseParams = const {
            'code_verifier': 'response-supplied-verifier',
          };
        try {
          await manager.loginAuthorizationCodeFlow();
        } on Object {
          // User creation fails (no id_token); see above.
        }

        expect(posts, hasLength(1));
        final body = Uri.splitQueryString(posts.single.body);
        expect(body['code_verifier'], isNot('response-supplied-verifier'));
        // What went out is still the verifier behind the challenge this client
        // put on the authorization request.
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

  group('legacy in-payload code_verifier (#404, no longer read)', () {
    test(
      'a state payload that still embeds code_verifier does not feed the '
      'token request',
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

        // A state payload exactly as a pre-2.0.0 version wrote it: the
        // code_verifier sitting in the plaintext `state` namespace, nothing in
        // secureTokens. Hand-built rather than via OidcAuthorizeState so it
        // keeps describing the old on-disk shape after the field is dropped.
        const legacyStateId = 'legacy-state-1';
        await store.setStateData(
          state: legacyStateId,
          stateData: jsonEncode({
            'id': legacyStateId,
            'operationDiscriminator':
                OidcConstants_OperationDiscriminators.authorize,
            'code_verifier': 'legacy-verifier',
            'code_challenge': OidcPkcePair.generateS256Challenge(
              'legacy-verifier',
            ),
            'redirect_uri': 'com.example.app://cb',
            'client_id': 'client-1',
            'nonce': 'hashed-nonce',
          }),
        );
        expect(await store.getStateCodeVerifier(legacyStateId), isNull);

        try {
          await manager.exposeHandleSuccess(
            OidcAuthorizeResponse.fromJson({
              'code': 'auth-code-1',
              'state': legacyStateId,
            }),
            _metadata(),
          );
        } on Object {
          // User creation fails (no id_token); the token POST already happened.
        }

        expect(posts, hasLength(1));
        final body = Uri.splitQueryString(posts.single.body);
        // The plaintext payload is not a source of the secret any more, so the
        // request carries no code_verifier at all (the token model omits a null
        // one). The OP answers invalid_grant and the app re-logs in.
        expect(body.containsKey('code_verifier'), isFalse);
      },
    );
  });
}
