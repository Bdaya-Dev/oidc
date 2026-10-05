@TestOn('vm')
library;

// Regression coverage for #468: `validateAndSaveUser`'s failure branch used to
// unconditionally remove the stored token (`currentToken` / `currentUserInfo`
// / `currentUserAttributes` / nonce) whenever validation produced errors,
// regardless of whether a DIFFERENT, already-signed-in session was sitting in
// `currentUser` at the time. A rejected candidate token (a repeated login
// while already signed in, or a refresh response) tore down the perfectly
// valid PREVIOUS session's persisted token while leaving `currentUser`
// pointing at it in memory -- store and memory then permanently disagreed
// until the next cold start silently signed the user out.
//
// The same unconditional removal also ignored
// `OidcUserManagerSettings.shouldRemoveInvalidToken`: a policy returning
// `false` (keep the stored token) still found the store emptied, because
// `validateAndSaveUser` had already deleted it before `loadCachedTokens`
// consulted the policy.
//
// The fix: `validateAndSaveUser`'s failure branch only clears the nonce and
// returns null, so a rejected candidate leaves the store and `currentUser`
// untouched. Removing a stored session that itself fails revalidation is owned
// by `loadCachedTokens`, which applies `shouldRemoveInvalidToken` and, when it
// does remove the session, forgets the in-memory user too, so memory and
// storage agree.

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
  // No `jwks_uri`: the signing key is injected into the manager's keyStore
  // directly, so id_token verification never needs a network JWKS fetch.
  'id_token_signing_alg_values_supported': ['RS256'],
};

final _metadata = OidcProviderMetadata.fromJson(_metadataJson());

/// A manager exposing both an eager [discoveryDocument] constructor (tests 1
/// & 2, which never need `init()` to hit the network) and the `.lazy`
/// constructor (test 3, which needs a real cache-first `init()`).
class _M extends OidcUserManagerBase {
  _M({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  _M.lazy({
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

OidcUserManagerSettings _settings() => OidcUserManagerSettings(
  redirectUri: Uri.parse('com.example.app://cb'),
  userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
);

_M _eagerManager(http.Client client, {OidcStore? store}) => _M(
  discoveryDocument: _metadata,
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings: _settings(),
);

/// A store holding a fresh discovery cache and an expired, non-refreshable
/// session: revalidating it on `init()` must fail.
Future<OidcMemoryStore> _storeWithExpiredSession() async {
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
      OidcConstants_Store.currentToken: jsonEncode(
        OidcToken(
          creationTime: clock.now().subtract(const Duration(hours: 2)).toUtc(),
          idToken: _signIdToken(expiresIn: const Duration(hours: -1)),
          accessToken: 'at-cached',
          tokenType: 'Bearer',
          expiresIn: const Duration(hours: 1),
        ).toJson(),
      ),
    },
  );
  return store;
}

_M _lazyManager(
  OidcStore store, {
  required OidcInitMode initMode,
  OidcShouldRemoveInvalidTokenCallback? shouldRemoveInvalidToken,
}) => _M.lazy(
  discoveryDocumentUri: _wellKnown,
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store,
  httpClient: MockClient(
    (req) async => http.Response('unexpected: ${req.url}', 599),
  ),
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('com.example.app://cb'),
    initMode: initMode,
    shouldRemoveInvalidToken: shouldRemoveInvalidToken,
    userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
  ),
);

Future<String?> _storedToken(OidcStore store) => store.get(
  OidcStoreNamespace.secureTokens,
  key: OidcConstants_Store.currentToken,
);

void main() {
  group('#468: a rejected NEW candidate token keeps the previous session', () {
    test(
      'signed-in user + new login response failing validation: stored token '
      'unchanged, currentUser unchanged, no emission on userChanges()',
      () async {
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            final idToken = tokenCalls == 1
                // First login: a perfectly valid token.
                ? _signIdToken()
                // Second login (while already signed in): EXPIRED id_token --
                // validateUser collects a `JWT expired` error, taking
                // validateAndSaveUser's failure branch.
                : _signIdToken(expiresIn: const Duration(hours: -1));
            return http.Response(
              jsonEncode({
                'access_token': 'at-$tokenCalls',
                'token_type': 'Bearer',
                'expires_in': 3600,
                'id_token': idToken,
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected request: ${req.url}', 599);
        });

        final store = OidcMemoryStore();
        await store.init();
        final manager = _eagerManager(client, store: store);
        await manager.init();

        final firstUser = await manager.loginPassword(
          username: 'u',
          password: 'p',
        );
        expect(firstUser, isNotNull);
        expect(manager.currentUser?.token.accessToken, 'at-1');
        final storedAfterFirstLogin = await _storedToken(store);
        expect(storedAfterFirstLogin, isNotNull);

        final changes = <OidcUser?>[];
        final sub = manager.userChanges().listen(changes.add);
        // [userSubject] is a value-stream: a fresh listener is replayed the
        // CURRENT value immediately. Drain that replay before exercising the
        // failing second login, so [changes] only captures emissions caused
        // BY that second attempt.
        await pumpEventQueue();
        changes.clear();

        final secondResult = await manager.loginPassword(
          username: 'u',
          password: 'p',
        );

        expect(
          secondResult,
          isNull,
          reason: 'the expired candidate token must be rejected',
        );
        // The previous session is untouched: same user, same stored token.
        expect(manager.currentUser?.token.accessToken, 'at-1');
        expect(await _storedToken(store), storedAfterFirstLogin);
        // Nothing was published on userChanges() for the rejected candidate --
        // in particular, no `null` logging the previous session out.
        expect(changes, isEmpty);

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'refresh response failing validation: previous session kept in BOTH '
      'memory and storage (and the existing OidcTokenRefreshFailedEvent '
      'contract is unaffected)',
      () async {
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            if (tokenCalls == 1) {
              // Initial login, with a refresh_token to refresh later.
              return http.Response(
                jsonEncode({
                  'access_token': 'at-1',
                  'token_type': 'Bearer',
                  'expires_in': 3600,
                  'refresh_token': 'rt-1',
                  'id_token': _signIdToken(),
                }),
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            // The refresh response itself carries an EXPIRED id_token --
            // validateAndSaveUser rejects it.
            return http.Response(
              jsonEncode({
                'access_token': 'at-refreshed',
                'token_type': 'Bearer',
                'expires_in': 3600,
                'refresh_token': 'rt-2',
                'id_token': _signIdToken(expiresIn: const Duration(hours: -1)),
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected request: ${req.url}', 599);
        });

        final store = OidcMemoryStore();
        await store.init();
        final manager = _eagerManager(client, store: store);
        await manager.init();

        final firstUser = await manager.loginPassword(
          username: 'u',
          password: 'p',
        );
        expect(firstUser, isNotNull);
        final storedAfterFirstLogin = await _storedToken(store);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final refreshed = await manager.refreshToken();

        expect(
          refreshed,
          isNull,
          reason: 'the expired refreshed token must be rejected',
        );
        // The previous (pre-refresh) session is kept in memory...
        expect(manager.currentUser?.token.accessToken, 'at-1');
        // ... AND on disk: the still-valid previous token must not be wiped
        // just because the NEW (refreshed) candidate failed validation.
        expect(await _storedToken(store), storedAfterFirstLogin);

        // Documents the EXISTING contract (unchanged by #468): a
        // validation-rejected refresh response returns `null` from
        // `createUserFromToken`/`validateAndSaveUser` WITHOUT throwing, so
        // `_refreshToken`'s catch-based `OidcTokenRefreshFailedEvent` emission
        // (which only runs for a THROWN failure, e.g. an `invalid_grant`
        // token-endpoint error) never fires here. This is a pre-existing gap
        // in the refresh-failure event contract, not something #468 changes --
        // #468 is only about keeping store/memory consistent on rejection.
        expect(events.whereType<OidcTokenRefreshFailedEvent>(), isEmpty);

        await sub.cancel();
        await manager.dispose();
      },
    );
  });

  group(
    '#468: revalidating the STORED session itself keeps memory consistent '
    'with storage',
    () {
      test(
        'cache-first background revalidation of an expired, '
        'non-refreshable cached token forgets the user in BOTH memory and '
        'storage',
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
          // Expired id_token, NO refresh_token: cache-first restores it
          // locally (unverified) and surfaces it as `currentUser` immediately,
          // then the background pass re-verifies it, finds it expired with
          // nothing to refresh with, and must reject it.
          await store.setMany(
            OidcStoreNamespace.secureTokens,
            values: {
              OidcConstants_Store.currentToken: jsonEncode(
                OidcToken(
                  creationTime: clock
                      .now()
                      .subtract(const Duration(hours: 2))
                      .toUtc(),
                  idToken: _signIdToken(expiresIn: const Duration(hours: -1)),
                  accessToken: 'at-cached',
                  tokenType: 'Bearer',
                  expiresIn: const Duration(hours: 1),
                ).toJson(),
              ),
            },
          );

          final manager = _M.lazy(
            discoveryDocumentUri: _wellKnown,
            clientCredentials: const OidcClientAuthentication.none(
              clientId: 'client-1',
            ),
            store: store,
            httpClient: MockClient(
              (req) async => http.Response('unexpected: ${req.url}', 599),
            ),
            keyStore: JsonWebKeyStore()..addKey(_signingKey),
            settings: _settings(),
          );

          final events = <OidcEvent>[];
          final sub = manager.events().listen(events.add);

          await manager.init();
          // The cache-first restore surfaces the (unverified) cached user
          // immediately, before the background pass rejects it.
          expect(manager.currentUser, isNotNull);

          await pumpEventQueue();

          // Consistent: neither memory nor storage has a session anymore.
          expect(manager.currentUser, isNull);
          expect(await _storedToken(store), isNull);
          // The retraction is observable, matching `forgetUser()`'s own
          // contract for turning a signed-in user into a signed-out one.
          expect(events.whereType<OidcPreLogoutEvent>(), hasLength(1));

          await sub.cancel();
          await manager.dispose();
        },
      );
    },
  );
  group('shouldRemoveInvalidToken decides whether a failed stored session is '
      'removed', () {
    for (final initMode in OidcInitMode.values) {
      test(
        '${initMode.name}: a policy returning false keeps the stored token, '
        'and no user is signed in',
        () async {
          final store = await _storeWithExpiredSession();
          final storedBefore = await _storedToken(store);
          final policyCalls = <List<Exception>>[];
          final manager = _lazyManager(
            store,
            initMode: initMode,
            shouldRemoveInvalidToken: (user, errors) {
              policyCalls.add(errors);
              return false;
            },
          );

          await manager.init();
          await pumpEventQueue();

          expect(policyCalls, hasLength(1));
          expect(
            await _storedToken(store),
            storedBefore,
            reason: 'the policy said to keep the stored token.',
          );
          // Rejected-but-kept: the token stays on disk, but nobody is
          // signed in with it.
          expect(manager.currentUser, isNull);
          await manager.dispose();
        },
      );

      test(
        '${initMode.name}: the default policy removes the stored token and '
        'forgets the user',
        () async {
          final store = await _storeWithExpiredSession();
          final manager = _lazyManager(store, initMode: initMode);
          final events = <OidcEvent>[];
          final sub = manager.events().listen(events.add);

          await manager.init();
          await pumpEventQueue();

          expect(await _storedToken(store), isNull);
          expect(manager.currentUser, isNull);
          // Only cache-first ever surfaced the user, so only it retracts one.
          expect(
            events.whereType<OidcPreLogoutEvent>(),
            hasLength(initMode == OidcInitMode.cacheFirst ? 1 : 0),
          );
          await sub.cancel();
          await manager.dispose();
        },
      );
    }
  });
  group('a stored session that fails revalidation after an in-place refresh', () {
    for (final initMode in OidcInitMode.values) {
      for (final keep in [false, true]) {
        test(
          keep
              ? '${initMode.name}: kept by the policy, the user the refresh '
                    'published is not left signed in'
              : '${initMode.name}: removed, the user the refresh published is '
                    'forgotten too',
          () async {
            // The stored access_token is expired, so init() refreshes it. The
            // refresh response validates (and is published as currentUser),
            // but the stored-session revalidation that follows fails on its
            // UserInfo call. loadCachedTokens then removes the stored session,
            // and memory must not keep the user the refresh published.
            final metadataJson = {
              ..._metadataJson(),
              'userinfo_endpoint': '$_issuer/userinfo',
            };
            final store = OidcMemoryStore();
            await store.init();
            await store.setMany(
              OidcStoreNamespace.discoveryDocument,
              values: {
                _wellKnown.toString(): jsonEncode(metadataJson),
                '$_wellKnown::oidc_discovery_fetched_at': clock
                    .now()
                    .millisecondsSinceEpoch
                    .toString(),
              },
            );
            await store.setMany(
              OidcStoreNamespace.secureTokens,
              values: {
                OidcConstants_Store.currentToken: jsonEncode(
                  OidcToken(
                    creationTime: clock
                        .now()
                        .subtract(const Duration(hours: 2))
                        .toUtc(),
                    idToken: _signIdToken(),
                    accessToken: 'at-cached',
                    refreshToken: 'rt-1',
                    tokenType: 'Bearer',
                    expiresIn: const Duration(hours: 1),
                  ).toJson(),
                ),
              },
            );
            var userInfoCalls = 0;
            final client = MockClient((req) async {
              if (req.url.path.endsWith('/token')) {
                return http.Response(
                  jsonEncode({
                    'access_token': 'at-refreshed',
                    'token_type': 'Bearer',
                    'expires_in': 3600,
                    'refresh_token': 'rt-2',
                    'id_token': _signIdToken(),
                  }),
                  200,
                  headers: const {'content-type': 'application/json'},
                );
              }
              if (req.url.path.endsWith('/userinfo')) {
                userInfoCalls++;
                return http.Response(
                  // The refresh's own validation sees the right subject; the
                  // stored-session revalidation right after it does not.
                  jsonEncode({'sub': userInfoCalls == 1 ? 'user-1' : 'other'}),
                  200,
                  headers: const {'content-type': 'application/json'},
                );
              }
              return http.Response('unexpected: ${req.url}', 599);
            });
            final manager = _M.lazy(
              discoveryDocumentUri: _wellKnown,
              clientCredentials: const OidcClientAuthentication.none(
                clientId: 'client-1',
              ),
              store: store,
              httpClient: client,
              keyStore: JsonWebKeyStore()..addKey(_signingKey),
              settings: OidcUserManagerSettings(
                redirectUri: Uri.parse('com.example.app://cb'),
                initMode: initMode,
                shouldRemoveInvalidToken: keep ? (_, _) => false : null,
              ),
            );

            await manager.init();
            await pumpEventQueue();

            expect(userInfoCalls, 2);
            if (keep) {
              // The policy keeps the (refreshed) session on disk, but it failed
              // revalidation, so nobody is signed in with it, exactly as when
              // no refresh happened.
              expect(await _storedToken(store), isNotNull);
            } else {
              expect(await _storedToken(store), isNull);
            }
            expect(
              manager.currentUser,
              isNull,
              reason:
                  'the session failed revalidation, so memory must not '
                  'keep a user signed in with it.',
            );
            await manager.dispose();
          },
        );
      }
    }
  });
}
