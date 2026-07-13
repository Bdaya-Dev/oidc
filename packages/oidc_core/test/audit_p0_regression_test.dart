@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Minimal concrete manager for driving non-platform flows in a VM test.
class _TestManager extends OidcUserManagerBase {
  _TestManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  void seed(OidcUser user) => userSubject.add(user);

  /// Test hook to drive the protected auto-refresh-on-expiry path.
  Future<void> expire(OidcToken token) => handleTokenExpiring(token);

  /// Test hook to drive the protected front-channel-logout path. Calling the
  /// `@protected` member from inside this subclass avoids the
  /// `invalid_use_of_protected_member` analyzer warning.
  Future<void> fcl(OidcFrontChannelLogoutIncomingRequest request) =>
      handleFrontChannelLogoutRequest(request);

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

/// Fixed signing key shared by every id_token this file mints, so a single
/// mocked `/jwks` response (see [_jwksResponseBody]) can verify all of them
/// under the now-always-strict verification path.
final JsonWebKey _signingKey = JsonWebKey.generate('RS256');
final Uri _jwksUri = Uri.parse('https://op.example.com/jwks');

String _jwksResponseBody() =>
    jsonEncode(JsonWebKeySet.fromKeys([_signingKey]).toJson());

String _signIdToken([Map<String, dynamic>? extra]) {
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': 'https://op.example.com',
          'sub': 'user-1',
          'aud': 'client-1',
          'exp':
              clock
                  .now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
          ...?extra,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

Future<OidcUser> _user() => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: clock.now(),
    idToken: _signIdToken(),
    accessToken: 'access-token-1',
    refreshToken: 'refresh-token-1',
    tokenType: 'Bearer',
  ),
);

/// Discovery metadata that OMITS `grant_types_supported`, exactly like
/// Facebook and other compliant OPs that don't advertise it. `jwks_uri` IS
/// present (verification is always-strict now, so a real key set is needed).
OidcProviderMetadata _metadataNoGrantTypes() => OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
  'jwks_uri': _jwksUri.toString(),
});

Future<_TestManager> _build(http.Client client) async {
  final manager = _TestManager(
    discoveryDocument: _metadataNoGrantTypes(),
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
  manager.seed(await _user());
  return manager;
}

void main() {
  group('refresh is NOT gated on grant_types_supported (P0 #4)', () {
    test(
      'refresh proceeds (hits /token) when the OP omits grant_types_supported',
      () async {
        final tokenCalls = <http.Request>[];
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) {
            return http.Response(
              _jwksResponseBody(),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          if (req.url.path.endsWith('/token')) {
            tokenCalls.add(req);
            return http.Response(
              '{"access_token":"new-access","token_type":"Bearer",'
              '"expires_in":3600,"refresh_token":"refresh-token-2",'
              '"id_token":"${_signIdToken()}"}',
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = await _build(client);

        final result = await manager.refreshToken();

        expect(
          tokenCalls,
          isNotEmpty,
          reason:
              'refresh must hit the token endpoint even though the OP did '
              'not advertise refresh_token in grant_types_supported',
        );
        expect(_qp(tokenCalls.first)['grant_type'], 'refresh_token');
        expect(result, isNotNull);
      },
    );

    test(
      'AUTO refresh-on-expiry also hits /token when grant_types_supported is '
      'omitted (handleTokenExpiring not gated on metadata)',
      () async {
        final tokenCalls = <http.Request>[];
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) {
            return http.Response(
              _jwksResponseBody(),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          if (req.url.path.endsWith('/token')) {
            tokenCalls.add(req);
            return http.Response(
              '{"access_token":"new-access","token_type":"Bearer",'
              '"expires_in":3600,"refresh_token":"refresh-token-2",'
              '"id_token":"${_signIdToken()}"}',
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = await _build(client);

        await manager.expire(
          OidcToken(
            creationTime: clock.now(),
            idToken: _signIdToken(),
            accessToken: 'access-token-1',
            refreshToken: 'refresh-token-1',
            tokenType: 'Bearer',
          ),
        );

        expect(
          tokenCalls,
          isNotEmpty,
          reason:
              'auto refresh-on-expiry must not be gated on '
              'grant_types_supported',
        );
        expect(_qp(tokenCalls.first)['grant_type'], 'refresh_token');
      },
    );
  });

  group('front-channel logout honours OPTIONAL iss/sid (P0 #3)', () {
    test(
      'logs out when the OP omits iss/sid (the common, spec-default case)',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = await _build(client);
        expect(manager.currentUser, isNotNull);

        // A paramless front-channel logout request (iss=null, sid=null).
        await manager.fcl(
          OidcFrontChannelLogoutIncomingRequest.fromJson(const {}),
        );

        expect(
          manager.currentUser,
          isNull,
          reason:
              'iss/sid are OPTIONAL (FCL 1.0 §3); their absence must not '
              'block local logout',
        );
      },
    );

    test(
      'does NOT log out when a PRESENT iss mismatches (defense kept)',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = await _build(client);

        await manager.fcl(
          OidcFrontChannelLogoutIncomingRequest.fromJson(
            const {'iss': 'https://evil.example.com'},
          ),
        );

        expect(
          manager.currentUser,
          isNotNull,
          reason: 'a present-but-mismatched iss must be rejected',
        );
      },
    );
  });

  group('refresh failure events (#120 / #123 / #154)', () {
    test(
      't1: auto-refresh invalid_grant emits a TERMINAL failure event '
      '(source=autoExpiry), KEEPS the user, and enters NO offline mode',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) return _jwks();
          if (req.url.path.endsWith('/token')) return _invalidGrant();
          return http.Response('{}', 404);
        });
        final manager = await _buildManager(client);
        addTearDown(manager.dispose);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        await manager.expire(_refreshableToken());
        await pumpEventQueue();

        final failure = events.whereType<OidcTokenRefreshFailedEvent>().single;
        expect(failure.source, OidcTokenRefreshSource.autoExpiry);
        expect(failure.kind, OidcTokenRefreshFailureKind.terminal);
        expect(failure.oauthErrorCode, 'invalid_grant');
        expect(failure.httpStatusCode, 400);
        expect(failure.willRetry, isFalse);
        expect(
          manager.currentUser,
          isNotNull,
          reason:
              'a terminal (invalid_grant) failure retains the user '
              '(ecosystem-majority default); it does not forget it',
        );
        expect(
          events.whereType<OidcOfflineModeEnteredEvent>(),
          isEmpty,
          reason: 'a terminal failure must not enter offline mode',
        );
        await sub.cancel();
      },
    );

    test(
      't2: auto-refresh network failure with supportOfflineAuth=true emits a '
      'TRANSIENT failure event (willRetry) AND enters offline mode with '
      'reason tokenRefreshFailed',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) return _jwks();
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('network down');
          }
          return http.Response('{}', 404);
        });
        final manager = await _buildManager(client, supportOfflineAuth: true);
        addTearDown(manager.dispose);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        await manager.expire(_refreshableToken());
        await pumpEventQueue();

        final failure = events.whereType<OidcTokenRefreshFailedEvent>().single;
        expect(failure.source, OidcTokenRefreshSource.autoExpiry);
        expect(failure.kind, OidcTokenRefreshFailureKind.transient);
        expect(failure.willRetry, isTrue);
        final offline = events.whereType<OidcOfflineModeEnteredEvent>().single;
        expect(offline.reason, OfflineModeReason.tokenRefreshFailed);
        expect(manager.currentUser, isNotNull);
        await sub.cancel();
      },
    );

    test(
      't3: auto-refresh network failure with supportOfflineAuth=false emits a '
      'TRANSIENT failure event with willRetry=false and KEEPS the user',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) return _jwks();
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('network down');
          }
          return http.Response('{}', 404);
        });
        final manager = await _buildManager(client);
        addTearDown(manager.dispose);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        await manager.expire(_refreshableToken());
        await pumpEventQueue();

        final failure = events.whereType<OidcTokenRefreshFailedEvent>().single;
        expect(failure.source, OidcTokenRefreshSource.autoExpiry);
        expect(failure.kind, OidcTokenRefreshFailureKind.transient);
        expect(failure.willRetry, isFalse);
        expect(events.whereType<OidcOfflineModeEnteredEvent>(), isEmpty);
        expect(manager.currentUser, isNotNull);
        await sub.cancel();
      },
    );

    test(
      't4: manual refreshToken() failure emits a failure event with '
      'source=manual AND still throws the OidcException to the caller',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) return _jwks();
          if (req.url.path.endsWith('/token')) return _invalidGrant();
          return http.Response('{}', 404);
        });
        final manager = await _buildManager(client);
        addTearDown(manager.dispose);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        await expectLater(
          manager.refreshToken(),
          throwsA(isA<OidcException>()),
        );
        await pumpEventQueue();

        final failure = events.whereType<OidcTokenRefreshFailedEvent>().single;
        expect(failure.source, OidcTokenRefreshSource.manual);
        expect(failure.oauthErrorCode, 'invalid_grant');
        expect(failure.willRetry, isFalse);
        await sub.cancel();
      },
    );

    test(
      't5 (#123): a refreshBefore lead GREATER than the token lifetime does '
      'NOT cause a tight synchronous refresh loop (bounded to ~once/half-life)',
      () {
        fakeAsync(
          (async) {
            final tokenCalls = <http.Request>[];
            final client = MockClient((req) async {
              if (req.url.path.endsWith('/jwks')) return _jwks();
              if (req.url.path.endsWith('/token')) {
                tokenCalls.add(req);
                // Every refresh returns an equally-short (60s) token.
                return _tokenOk();
              }
              return http.Response('{}', 404);
            });
            // Lead (120s) is DOUBLE the 60s lifetime: without the half-life
            // clamp this fired 'expiring' synchronously on every load → an
            // unbounded tight refresh loop (issue #123).
            unawaited(
              _buildManager(
                client,
                refreshBefore: (_) => const Duration(seconds: 120),
                seed: _shortUser,
              ),
            );
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 5));

            expect(
              tokenCalls,
              isNotEmpty,
              reason: 'a near-expiry token must still refresh',
            );
            expect(
              tokenCalls.length,
              lessThan(20),
              reason:
                  'the half-life clamp bounds refreshes to ~once per 30s '
                  '(=10 over 5 min), not a tight synchronous loop',
            );
          },
          initialTime: DateTime.utc(2024),
        );
      },
    );

    test(
      't6 (#154): a transient failure on an expiring refreshable token never '
      'forgets the user (user retained); the failure event is emitted',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/jwks')) return _jwks();
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('network down');
          }
          return http.Response('{}', 404);
        });
        final manager = await _buildManager(client, supportOfflineAuth: true);
        addTearDown(manager.dispose);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);
        final userChanges = <OidcUser?>[];
        final userSub = manager.userChanges().listen(userChanges.add);

        await manager.expire(_refreshableToken());
        await pumpEventQueue();

        expect(
          manager.currentUser,
          isNotNull,
          reason: 'a transient (network) failure must NEVER forget the user',
        );
        expect(
          userChanges,
          isNot(contains(null)),
          reason:
              'forgetUser (a null user change) must not occur on a '
              'transient failure',
        );
        expect(
          events.whereType<OidcTokenRefreshFailedEvent>(),
          isNotEmpty,
        );
        await sub.cancel();
        await userSub.cancel();
      },
    );
  });
}

Map<String, String> _qp(http.Request r) => Uri.splitQueryString(r.body);

/// Builds a [_TestManager] with configurable offline support / refresh lead and
/// a seeded user (defaults to [_user]).
Future<_TestManager> _buildManager(
  http.Client client, {
  bool supportOfflineAuth = false,
  OidcRefreshBeforeCallback? refreshBefore,
  Future<OidcUser> Function()? seed,
}) async {
  final manager = _TestManager(
    discoveryDocument: _metadataNoGrantTypes(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      supportOfflineAuth: supportOfflineAuth,
      refreshBefore: refreshBefore ?? defaultRefreshBefore,
    ),
  );
  await manager.init();
  manager.seed(await (seed ?? _user)());
  return manager;
}

/// A refreshable, short-lived token used to drive the auto-refresh-on-expiry
/// path via [_TestManager.expire].
OidcToken _refreshableToken() => OidcToken(
  creationTime: clock.now(),
  idToken: _signIdToken(),
  accessToken: 'access-token-1',
  refreshToken: 'refresh-token-1',
  tokenType: 'Bearer',
  expiresIn: const Duration(seconds: 60),
);

/// A user whose token carries a 60s lifetime, so the token-events timer arms.
Future<OidcUser> _shortUser() => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: clock.now(),
    idToken: _signIdToken(),
    accessToken: 'access-token-1',
    refreshToken: 'refresh-token-1',
    tokenType: 'Bearer',
    expiresIn: const Duration(seconds: 60),
  ),
);

http.Response _jwks() => http.Response(
  _jwksResponseBody(),
  200,
  headers: const {'content-type': 'application/json'},
);

http.Response _invalidGrant() => http.Response(
  jsonEncode({
    'error': 'invalid_grant',
    'error_description': 'refresh token revoked',
  }),
  400,
  headers: const {'content-type': 'application/json'},
);

http.Response _tokenOk() => http.Response(
  '{"access_token":"new-access","token_type":"Bearer",'
  '"expires_in":60,"refresh_token":"refresh-token-2",'
  '"id_token":"${_signIdToken()}"}',
  200,
  headers: const {'content-type': 'application/json'},
);
