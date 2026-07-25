@TestOn('vm')
library;

// Regression test for the PR #425 review BLOCKER: `getAccessToken()` and
// `signInSilent()` (#421/#423) joined the shared `_autoRefreshInFlight` latch
// used by the expiry timers, but NOT the separate in-flight cache-first
// (`OidcInitMode.cacheFirst`, the DEFAULT) background revalidation, which
// refreshes through the raw, un-coalesced `_refreshToken` instead. A caller
// invoking `getAccessToken()` / `signInSilent()` immediately after
// `await manager.init()` returns (cacheFirst returns before the background
// revalidation settles, by design) raced that revalidation and presented the
// SAME still-valid refresh token in a SECOND, concurrent `/token` exchange —
// the RFC 9700 §4.14.2 rotation-reuse hazard the pre-existing
// `_cacheFirstRevalidationInFlight` gate exists to prevent for the
// timer-driven paths (`handleTokenExpiring` / `handleTokenExpired`).
//
// This reproduces the reviewer's exact probe: seed the store with an EXPIRED
// cached token (`refresh_token=rt-1`) plus a FRESH cached discovery document,
// build the manager with DEFAULT settings (cacheFirst), `await init()`, then
// perform ONE action immediately — with a MockClient that delays every
// `/token` response by 50ms (so the background revalidation's own exchange is
// still in flight when the action runs) and records every request body.
//
// | action           | before fix | after fix |
// |------------------|------------|-----------|
// | none (control)   | 1          | 1         |
// | getAccessToken   | 2 (RACE)   | 1         |
// | refreshToken     | 2          | 2 (unfixed by design, see #421 advisory) |
// | signInSilent     | 2 (RACE)   | 1         |

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

/// A concrete manager built via the `.lazy` constructor, mirroring
/// `cache_first_init_test.dart`'s harness (duplicated here since that file's
/// helpers are library-private).
class _Manager extends OidcUserManagerBase {
  _Manager.lazy({
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

/// A MockClient that answers discovery/userinfo immediately, but for `/token`
/// requests: records the request BODY (so a test can assert every exchange
/// presented `refresh_token=rt-1`, proving the race — both exchanges read the
/// same still-cached token before either had a chance to complete) and delays
/// the response by [tokenDelay] before answering success. The 50ms delay
/// reproduces the reviewer's probe window in which the background
/// revalidation's own exchange is still in flight when the test's action runs.
http.Client _client(
  List<String> tokenBodies, {
  Duration tokenDelay = const Duration(milliseconds: 50),
}) => MockClient((req) async {
  final path = req.url.path;
  if (path.endsWith('openid-configuration')) {
    return http.Response(
      jsonEncode(_metadataJson()),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  if (path.endsWith('/userinfo')) {
    return http.Response(
      jsonEncode({'sub': 'user-1'}),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  if (path.endsWith('/token')) {
    tokenBodies.add(req.body);
    await Future<void>.delayed(tokenDelay);
    return http.Response(
      jsonEncode({
        'access_token': 'at-refreshed',
        'token_type': 'Bearer',
        'expires_in': 3600,
        // Deliberately NOT rotated: every captured body is expected to show
        // `refresh_token=rt-1` because a RACING second exchange reads the
        // pre-refresh cached token before either request completes.
        'refresh_token': 'rt-1',
        'id_token': _signIdToken(),
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('{}', 404);
});

String _expiredCachedTokenJson() => jsonEncode(
  OidcToken(
    creationTime: clock.now().subtract(const Duration(hours: 2)).toUtc(),
    idToken: _signIdToken(expiresIn: const Duration(hours: -1)),
    accessToken: 'at-expired',
    tokenType: 'Bearer',
    expiresIn: const Duration(hours: 1),
    refreshToken: 'rt-1',
  ).toJson(),
);

Future<OidcMemoryStore> _seededStore() async {
  final store = OidcMemoryStore();
  await store.init();
  // A FRESH cached discovery document, so `_tryCacheFirstInit` restores
  // locally with zero network I/O (matches `cache_first_init_test.dart`'s
  // "expired+refreshable" seed).
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
    values: {OidcConstants_Store.currentToken: _expiredCachedTokenJson()},
  );
  return store;
}

_Manager _lazyManager({
  required OidcStore store,
  required http.Client client,
}) => _Manager.lazy(
  discoveryDocumentUri: _wellKnown,
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store,
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  // DEFAULT settings: OidcInitMode.cacheFirst is the default init mode, and
  // this deliberately does NOT set supportOfflineAuth — the probe only
  // exercises the SUCCESS interleaving (the MockClient above never fails).
  settings: OidcUserManagerSettings(redirectUri: Uri.parse('app://cb')),
);

/// Runs ONE probe: seed the expired-cached-token store above, `await init()`
/// (which starts the background revalidation but returns immediately — the
/// whole point of the cacheFirst default), then run [action] IMMEDIATELY
/// after — the exact window the reviewer's probe demonstrated the race in.
/// Returns every captured `/token` request body once everything (the
/// revalidation, and whatever [action] started) has settled.
Future<List<String>> _runProbe(
  Future<void> Function(_Manager manager)? action,
) async {
  final tokenBodies = <String>[];
  final store = await _seededStore();
  final manager = _lazyManager(store: store, client: _client(tokenBodies));

  await manager.init();
  await action?.call(manager);
  // `pumpEventQueue()` alone only flushes zero-delay event-loop turns, which
  // can race ahead of a REAL 50ms `Future.delayed` timer; wait out the mock's
  // delay explicitly (with margin) before also draining any remaining
  // microtask follow-up work.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  await pumpEventQueue();

  await manager.dispose();
  return tokenBodies;
}

void main() {
  group(
    'cache-first revalidation vs. silent-acquisition race (PR #425 review)',
    () {
      test(
        '[none] control: the background revalidation alone performs exactly '
        'ONE /token exchange',
        () async {
          final bodies = await _runProbe(null);
          expect(bodies, hasLength(1));
          expect(bodies.single, contains('refresh_token=rt-1'));
        },
      );

      test(
        '[getAccessToken] called immediately after init() JOINS the in-flight '
        'revalidation instead of racing it: exactly ONE /token exchange '
        '(was TWO before the fix)',
        () async {
          final bodies = await _runProbe((manager) => manager.getAccessToken());
          expect(bodies, hasLength(1));
          expect(bodies.single, contains('refresh_token=rt-1'));
        },
      );

      test(
        '[signInSilent] called immediately after init() JOINS the in-flight '
        'revalidation instead of racing it: exactly ONE /token exchange '
        '(was TWO before the fix)',
        () async {
          final bodies = await _runProbe((manager) => manager.signInSilent());
          expect(bodies, hasLength(1));
          expect(bodies.single, contains('refresh_token=rt-1'));
        },
      );

      test(
        '[refreshToken] called immediately after init() is DELIBERATELY left '
        'un-coalesced (#421 remains open for this entry point, see the PR '
        'description): TWO /token exchanges, both presenting the SAME '
        'pre-refresh token',
        () async {
          final bodies = await _runProbe((manager) => manager.refreshToken());
          expect(bodies, hasLength(2));
          for (final body in bodies) {
            expect(body, contains('refresh_token=rt-1'));
          }
        },
      );
    },
  );
}
