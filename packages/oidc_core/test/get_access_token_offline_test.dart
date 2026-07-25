@TestOn('vm')
library;

// Regression test for the PR #425 review advisory: `_performAutoRefresh` (the
// shared latch behind `getAccessToken()` / `signInSilent()`) returned
// `failureKind: transient` even when `handleOfflineEligibleFailure` had
// ALREADY absorbed the error and entered offline mode — so a `getAccessToken`
// call while offline THREW a `kind: transient` `OidcException` instead of
// handing back the cached (stale) access token, unlike the legacy
// `_refreshToken` (used by `refreshToken()`), which returns the retained user
// silently on the identical offline-absorbed failure. With
// `supportOfflineAuth: true`, losing the network should retain the session,
// not throw — that is the entire point of enabling offline auth support.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  'id_token_signing_alg_values_supported': ['RS256'],
};

/// Duplicated from `cache_first_init_test.dart` (library-private there).
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

/// Answers discovery/userinfo, and ALWAYS fails `/token` with a
/// [SocketException] — an offline-eligible error per
/// `OidcOfflineAuthErrorHandler.categorizeError`.
http.Client _alwaysOfflineClient() => MockClient((req) async {
  final path = req.url.path;
  if (path.endsWith('openid-configuration')) {
    return http.Response(
      jsonEncode(_metadataJson()),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  if (path.endsWith('/token')) {
    throw const SocketException('offline');
  }
  return http.Response('{}', 404);
});

String _expiredCachedTokenJson() => jsonEncode(
  OidcToken(
    creationTime: clock.now().subtract(const Duration(hours: 2)).toUtc(),
    idToken: _signIdToken(expiresIn: const Duration(hours: -1)),
    accessToken: 'at-cached-stale',
    tokenType: 'Bearer',
    expiresIn: const Duration(hours: 1),
    refreshToken: 'rt-1',
  ).toJson(),
);

Future<_Manager> _offlineEligibleManager() async {
  final store = OidcMemoryStore();
  await store.init();
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

  final manager = _Manager.lazy(
    discoveryDocumentUri: _wellKnown,
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: store,
    httpClient: _alwaysOfflineClient(),
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('app://cb'),
      // blockingValidate: this test is isolated to the offline
      // classification advisory, not the cache-first join fix covered by
      // cache_first_revalidation_join_test.dart.
      initMode: OidcInitMode.blockingValidate,
      supportOfflineAuth: true,
      userInfoSettings: const OidcUserInfoSettings(
        sendUserInfoRequest: false,
      ),
    ),
  );
  // init()'s own loadCachedTokens() also hits the (always-failing) refresh;
  // with supportOfflineAuth it absorbs the failure via the raw _refreshToken
  // path and retains the cached user — unaffected by this fix, already
  // covered by cache_first_init_test.dart's "offline" TTL test.
  await manager.init();
  expect(manager.currentUser, isNotNull);
  return manager;
}

void main() {
  group(
    'getAccessToken/signInSilent offline-mode classification '
    '(PR #425 review advisory)',
    () {
      test(
        'getAccessToken() returns the cached access token (no throw) when a '
        'refresh fails offline-eligibly and supportOfflineAuth is enabled',
        () async {
          final manager = await _offlineEligibleManager();

          // Before the fix, _performAutoRefresh always returned
          // failureKind: transient on ANY failure, so this threw a kind-stamped
          // OidcException even though handleOfflineEligibleFailure had already
          // absorbed the identical error and entered offline mode.
          final accessToken = await manager.getAccessToken();

          expect(accessToken, 'at-cached-stale');
          expect(manager.isInOfflineMode, isTrue);
          await manager.dispose();
        },
      );

      test(
        'signInSilent() returns the retained user (no throw) when a refresh '
        'fails offline-eligibly and supportOfflineAuth is enabled',
        () async {
          final manager = await _offlineEligibleManager();

          final user = await manager.signInSilent();

          expect(user, isNotNull);
          expect(user!.token.accessToken, 'at-cached-stale');
          expect(manager.isInOfflineMode, isTrue);
          await manager.dispose();
        },
      );

      test(
        'getAccessToken() STILL throws a kind:transient OidcException when '
        'the SAME failure occurs with supportOfflineAuth DISABLED (default) '
        '— the fix only changes the offline-absorbed case',
        () async {
          final store = OidcMemoryStore();
          await store.init();
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
            values: {
              OidcConstants_Store.currentToken: _expiredCachedTokenJson(),
            },
          );
          final manager = _Manager.lazy(
            discoveryDocumentUri: _wellKnown,
            clientCredentials: const OidcClientAuthentication.none(
              clientId: 'client-1',
            ),
            store: store,
            httpClient: _alwaysOfflineClient(),
            keyStore: JsonWebKeyStore()..addKey(_signingKey),
            settings: OidcUserManagerSettings(
              redirectUri: Uri.parse('app://cb'),
              initMode: OidcInitMode.blockingValidate,
              // supportOfflineAuth defaults to false: init()'s OWN refresh
              // (loadCachedTokens, on the raw, unaffected-by-this-fix
              // _refreshToken path) would otherwise also fail and forget the
              // user before this test can even reach getAccessToken().
              // isLoadedTokenAcceptable short-circuits that so the session
              // survives init() unrefreshed, isolating getAccessToken()'s OWN
              // (fixed) refresh attempt as the only failure in play.
              isLoadedTokenAcceptable: (user, errors) => true,
              userInfoSettings: const OidcUserInfoSettings(
                sendUserInfoRequest: false,
              ),
            ),
          );
          await manager.init();
          expect(manager.currentUser, isNotNull);
          expect(manager.isInOfflineMode, isFalse);

          await expectLater(
            manager.getAccessToken(),
            throwsA(
              isA<OidcException>().having(
                (e) => e.kind,
                'kind',
                OidcTokenRefreshFailureKind.transient,
              ),
            ),
          );
          // Not absorbed (offline auth disabled): offline mode is NOT entered.
          expect(manager.isInOfflineMode, isFalse);
          await manager.dispose();
        },
      );
    },
  );
}
