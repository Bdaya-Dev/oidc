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

  /// Test-only synchronous entry points for the two timer-driven expiry
  /// handlers (mirrors the `*Test`-suffixed wrappers already used for this
  /// purpose elsewhere, e.g. `user_manager_internals_coverage_test.dart`) —
  /// see the A3 test below (PR #425 review advisory A3).
  Future<void> handleTokenExpiringForTest(OidcToken event) =>
      handleTokenExpiring(event);

  void handleTokenExpiredForTest(OidcToken event) =>
      handleTokenExpired(event);

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

/// Same as [_client] (answers discovery), but also answers `/token` and
/// records one entry per exchange, for the A3 test below — which asserts an
/// exact `/token` exchange COUNT rather than just "no rethrow". `/userinfo`
/// still must never be hit: the refreshed token replaces the existing
/// cache-first-restored user via `currentUser.replaceToken` (id_token
/// verified locally against the injected [_signingKey]), never a fresh
/// `OidcUser.fromIdToken` build that would need a userinfo call.
http.Client _clientCountingTokenExchanges(List<String> tokenExchanges) =>
    MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('openid-configuration')) {
        return http.Response(
          jsonEncode(_metadataJson()),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/token')) {
        tokenExchanges.add(req.body);
        return http.Response(
          jsonEncode({
            'access_token': 'at-refreshed',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'refresh_token': 'rt-1',
            'id_token': _signIdToken(),
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response(
        'unexpected request in this probe: ${req.url}',
        599,
      );
    });

/// Shared by [_freshCachedTokenJson] (seeds the store) and the A3 test below
/// (builds the `event` handed directly to `handleTokenExpiring`/
/// `handleTokenExpired`) — both need the same fresh, `refreshToken`-bearing
/// token shape.
OidcToken _freshToken() => OidcToken(
  creationTime: clock.now().toUtc(),
  idToken: _signIdToken(),
  accessToken: 'at-cached',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
  refreshToken: 'rt-1',
);

String _freshCachedTokenJson() => jsonEncode(_freshToken().toJson());

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

_ThrowingAttachManager _lazyManager(
  OidcStore store, {
  http.Client? httpClient,
}) => _ThrowingAttachManager.lazy(
  discoveryDocumentUri: _wellKnown,
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'client-1',
  ),
  store: store,
  httpClient: httpClient ?? _client(),
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

      test(
        'on-expiry auto-refresh (handleTokenExpiring + handleTokenExpired) '
        'is not silently disabled forever by a failed init(): exactly ONE '
        '/token exchange once the revalidation has settled (PR #425 review '
        'advisory A3)',
        () async {
          // A1 fixed a DIFFERENT, more visible symptom: getAccessToken()
          // rethrowing the stale init() error forever. But
          // `_cacheFirstRevalidationInFlight` gates BOTH
          // getAccessToken()/signInSilent() (via
          // _joinCacheFirstRevalidationIfInFlight) AND the timer-driven
          // handleTokenExpiring/handleTokenExpired (a direct `if
          // (_cacheFirstRevalidationInFlight) return;` each, ~:2019/~:2346) —
          // and only the bool's OWN clearing in
          // _scheduleBackgroundRevalidation's `finally` (~:3877) protects the
          // second gate. A test that calls getAccessToken() cannot isolate
          // this: pre-fix it throws (masking the bool's stuck state) and
          // post-fix it returns the cached token without ever exercising
          // these two handlers at all. This probe never calls
          // getAccessToken()/signInSilent() — it drives the two handlers
          // directly and counts real `/token` exchanges, so a stuck-`true`
          // gate is visible as its own distinct symptom (ZERO exchanges, not
          // a rethrown error and not a race producing two).
          final tokenExchanges = <String>[];
          final manager = _lazyManager(
            await _seededStore(),
            httpClient: _clientCountingTokenExchanges(tokenExchanges),
          );

          Object? initError;
          try {
            await manager.init();
          } on Object catch (e) {
            initError = e;
          }
          expect(initError, isA<_InjectedAttachFailure>());

          // Let the already-scheduled `_scheduleBackgroundRevalidation`'s own
          // `await initFuture` observe the SAME rejection and run its
          // catch/finally. This deliberately does NOT go through
          // getAccessToken()/_joinCacheFirstRevalidationIfInFlight (which
          // would explicitly await the captured revalidation future and so
          // synchronize on it for free, masking any timing gap here). There
          // is no further network I/O on the error path (the catch/finally
          // do only synchronous field writes and a log call), so a single
          // `pumpEventQueue()` — draining far more than the one microtask
          // needed — is enough to let it settle either way: post-fix it
          // clears the gate; pre-fix (see the mutation-check in the MR
          // description) it never does, no matter how long this waits.
          await pumpEventQueue();

          // Drive BOTH handlers off the SAME token event, back-to-back with
          // no `await` between them — exactly the "resume fires both
          // timers" interleaving [_autoRefresh]'s shared in-flight latch
          // (#154) exists for, so they race the SAME gate value and (post-
          // fix) share the SAME single exchange instead of each starting its
          // own.
          final tokenEvent = _freshToken();
          final expiringDone = manager.handleTokenExpiringForTest(tokenEvent);
          manager.handleTokenExpiredForTest(tokenEvent);
          await expiringDone;
          await pumpEventQueue();

          expect(
            tokenExchanges,
            hasLength(1),
            reason:
                'pre-fix, _cacheFirstRevalidationInFlight never clears '
                'after a failed init(), so both handlers hit their early '
                '`if (_cacheFirstRevalidationInFlight) return;` and NO '
                '/token exchange happens at all (0 — a permanently, '
                'silently disabled auto-refresh-on-expiry — not a race '
                'producing 2)',
          );

          await manager.dispose();
        },
        timeout: const Timeout(Duration(seconds: 10)),
      );
    },
  );
}
