@TestOn('vm')
library;

// Regression test for the PR #425 review advisory A1: in
// `_scheduleBackgroundRevalidation`, `await initFuture;` (~:3816) sits OUTSIDE
// the `try` that begins right below it (~:3817). The `finally`
// (~:3852-3865) that clears `_cacheFirstRevalidationInFlight` /
// `_cacheFirstRevalidationFuture` — the gate `_joinCacheFirstRevalidationIfInFlight`
// (~:296-303) awaits, and that `handleTokenExpiring`/`handleTokenExpired`
// (~:2012/~:2339) also read — therefore never runs if `initFuture` completes
// with an error.
//
// `initFuture` CAN fail: `init()`'s cache-first branch (~:3677-3681) restores
// the cached user, arms the gate, starts `_scheduleBackgroundRevalidation`
// (which immediately awaits `initFuture`), and only THEN calls
// `attachLifecycleListeners()` (~:3679) — a `@protected`, overridable method
// that constructs subclass/platform-supplied streams and can throw
// synchronously. `AsyncMemoizer.hasRun`/`didInit` flips to `true` as soon as
// `init()` is called (before its callback even finishes; see
// `package:async`'s `Completer.isCompleted` semantics), so `ensureInit()`
// never gates a caller off an already-failed init — every later
// `getAccessToken()`/`signInSilent()` reaches
// `_joinCacheFirstRevalidationIfInFlight`, which (pre-fix) re-awaits the SAME
// already-settled, permanently-errored future and rethrows the STALE init
// error forever instead of returning the still-valid cache-first-restored
// token.
//
// This probe: a manager whose `attachLifecycleListeners()` throws
// synchronously, seeded with a FRESH (non-expiring) cached token + cached
// discovery document so `_tryCacheFirstInit()` restores locally with zero
// network I/O. `init()` throws the injected failure (exactly what its own
// caller already observed) — then `getAccessToken()` must NOT re-surface that
// same error.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _issuer = 'https://op.example.com';
final Uri _wellKnown = Uri.parse(
  '$_issuer/.well-known/openid-configuration',
);
final JsonWebKey _signingKey = JsonWebKey.generate('RS256');

String _signIdToken({
  String subject = 'user-1',
  Duration expiresIn = const Duration(hours: 1),
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': subject,
          'aud': 'client-1',
          'exp': now + expiresIn.inSeconds,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

Map<String, dynamic> _metadataJson() => {
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
  // No `jwks_uri`: the signing key is injected into the manager's keyStore
  // directly, so id_token verification never needs a network JWKS fetch.
  'id_token_signing_alg_values_supported': ['RS256'],
};

/// Thrown from [_ThrowingAttachManager.attachLifecycleListeners] to simulate a
/// subclass override whose stream/listener wiring fails synchronously (e.g. a
/// platform-specific stream constructor that isn't available in the current
/// environment).
class _InjectedAttachFailure extends Error {
  @override
  String toString() =>
      '_InjectedAttachFailure: injected attachLifecycleListeners() failure';
}

/// Same harness shape as `cache_first_revalidation_join_test.dart`'s
/// `_Manager` (duplicated: that file's helpers are library-private), except
/// [attachLifecycleListeners] throws synchronously instead of wiring up the
/// (unused, in this test) lifecycle streams — reproducing the exact #425
/// review advisory A1 window in `init()`'s cache-first branch
/// (`user_manager_base.dart:3677-3681`): restore-then-arm-then-attach.
class _ThrowingAttachManager extends OidcUserManagerBase {
  _ThrowingAttachManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  @override
  bool get isWeb => false;

  @override
  void attachLifecycleListeners() {
    throw _InjectedAttachFailure();
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

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

/// Answers discovery only; `/token` and `/userinfo` must never be hit by this
/// probe — the seeded cached token is fresh, so `getAccessToken()` must
/// short-circuit on the cache-first-restored user without any network call.
http.Client _client() => MockClient((req) async {
  final path = req.url.path;
  if (path.endsWith('openid-configuration')) {
    return http.Response(
      jsonEncode(_metadataJson()),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('unexpected request in this probe: ${req.url}', 599);
});

String _freshCachedTokenJson() => jsonEncode(
  OidcToken(
    creationTime: clock.now().toUtc(),
    idToken: _signIdToken(),
    accessToken: 'at-cached',
    tokenType: 'Bearer',
    expiresIn: const Duration(hours: 1),
    refreshToken: 'rt-1',
  ).toJson(),
);

Future<OidcMemoryStore> _seededStore() async {
  final store = OidcMemoryStore();
  await store.init();
  // A FRESH cached discovery document, so `_tryCacheFirstInit` restores
  // locally with zero network I/O.
  await store.setMany(
    OidcStoreNamespace.discoveryDocument,
    values: {
      _wellKnown.toString(): jsonEncode(_metadataJson()),
      '$_wellKnown::oidc_discovery_fetched_at': clock
          .now()
          .millisecondsSinceEpoch
          .toString(),
    },
  );
  await store.setMany(
    OidcStoreNamespace.secureTokens,
    values: {OidcConstants_Store.currentToken: _freshCachedTokenJson()},
  );
  return store;
}

_ThrowingAttachManager _lazyManager(OidcStore store) =>
    _ThrowingAttachManager.lazy(
      discoveryDocumentUri: _wellKnown,
      clientCredentials: const OidcClientAuthentication.none(
        clientId: 'client-1',
      ),
      store: store,
      httpClient: _client(),
      keyStore: JsonWebKeyStore()..addKey(_signingKey),
      // DEFAULT settings: OidcInitMode.cacheFirst is the default init mode.
      settings: OidcUserManagerSettings(redirectUri: Uri.parse('app://cb')),
    );

void main() {
  group(
    'cache-first background revalidation vs. a failed init() '
    '(PR #425 review advisory A1)',
    () {
      test(
        'getAccessToken() after a failed init() does NOT rethrow the stale '
        'init error forever',
        () async {
          final manager = _lazyManager(await _seededStore());

          Object? initError;
          try {
            await manager.init();
          } on Object catch (e) {
            initError = e;
          }
          // Sanity: the injected failure really propagated out of init() —
          // exactly what init()'s own caller already observed directly.
          expect(initError, isA<_InjectedAttachFailure>());

          // The bug: `_scheduleBackgroundRevalidation`'s unguarded
          // `await initFuture` (outside its own try/finally) rethrows this
          // SAME error and never clears `_cacheFirstRevalidationFuture` /
          // `_cacheFirstRevalidationInFlight` — so every subsequent
          // getAccessToken()/signInSilent() re-joins the
          // permanently-errored future and rethrows it forever, instead of
          // returning the still-valid, cache-first-restored cached token.
          String? token1;
          Object? getAccessTokenError;
          try {
            token1 = await manager.getAccessToken();
          } on Object catch (e) {
            getAccessTokenError = e;
          }
          expect(
            getAccessTokenError,
            isNot(isA<_InjectedAttachFailure>()),
            reason:
                'getAccessToken() must not leak the stale init() failure '
                'forever',
          );
          expect(token1, 'at-cached');

          // The leak (when present) is PERMANENT, not a one-shot fluke —
          // probe a second call too.
          Object? secondError;
          String? token2;
          try {
            token2 = await manager.getAccessToken();
          } on Object catch (e) {
            secondError = e;
          }
          expect(secondError, isNull);
          expect(token2, 'at-cached');

          await manager.dispose();
        },
        timeout: const Timeout(Duration(seconds: 10)),
      );
    },
  );
}
