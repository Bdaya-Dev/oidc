@TestOn('vm')
library;

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
final _signingKey = JsonWebKey.generate('RS256');

String _signIdToken({
  String subject = 'user-1',
  Duration expiresIn = const Duration(hours: 1),
  String issuer = _issuer,
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': issuer,
          'sub': subject,
          'aud': 'client-1',
          'exp': now + expiresIn.inSeconds,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

/// A concrete manager exposing the `@protected` re-validation surface so the
/// #302 UserInfo-401 reaction can be driven directly from a VM test.
class _M extends OidcUserManagerBase {
  _M({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  void seed(OidcUser user) => userSubject.add(user);
  Future<void> saveUserRaw(OidcUser user) => saveUser(user);

  /// Re-validates an already-established session (the #302 opt-in): a UserInfo
  /// 401 triggers the recover-via-refresh + typed-event reaction.
  Future<OidcUser?> validateResumedSession(OidcUser user) =>
      validateAndSaveUser(
        user: user,
        metadata: discoveryDocument,
        reactToUserInfoUnauthorized: true,
      );

  /// Validates a freshly-issued login token (no #302 reaction), used as the
  /// "not a session resume" contrast.
  Future<OidcUser?> validateFreshLogin(OidcUser user) =>
      validateAndSaveUser(user: user, metadata: discoveryDocument);

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

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
});

OidcToken _token({
  String accessToken = 'at-seed',
  String? refreshToken = 'rt-seed',
}) => OidcToken(
  creationTime: clock.now(),
  idToken: _signIdToken(),
  accessToken: accessToken,
  refreshToken: refreshToken,
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
);

Future<OidcUser> _seedUser({String? refreshToken = 'rt-seed'}) =>
    OidcUser.fromIdToken(token: _token(refreshToken: refreshToken));

_M _make({
  required http.Client client,
  OidcUserManagerSettings? settings,
  OidcStore? store,
}) => _M(
  discoveryDocument: _metadata(),
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings:
      settings ??
      OidcUserManagerSettings(redirectUri: Uri.parse('com.example.app://cb')),
);

/// A `WWW-Authenticate` bearer challenge (RFC 6750 §3) rejecting a revoked
/// access token.
const _invalidTokenChallenge =
    'Bearer error="invalid_token", '
    'error_description="The access token was revoked"';

void main() {
  group('OidcUserInfoFailedEvent.fromError (WWW-Authenticate parsing)', () {
    test('extracts the RFC 6750 §3 error and description from the header', () {
      final event = OidcUserInfoFailedEvent.fromError(
        error: OidcException(
          'UserInfo rejected',
          rawResponse: http.Response(
            '',
            401,
            headers: const {'www-authenticate': _invalidTokenChallenge},
          ),
        ),
      );

      expect(event.httpStatusCode, 401);
      expect(event.oauthErrorCode, 'invalid_token');
      expect(event.errorDescription, 'The access token was revoked');
      expect(event.challenge, isNotNull);
      expect(event.isStepUpChallenge, isFalse);
    });

    test('surfaces RFC 9470 step-up hints (acr_values / max_age)', () {
      final event = OidcUserInfoFailedEvent.fromError(
        error: OidcException(
          'step-up required',
          rawResponse: http.Response(
            '',
            401,
            headers: const {
              'www-authenticate':
                  'Bearer error="insufficient_user_authentication", '
                  'acr_values="urn:mace:incommon:iap:silver", max_age="0"',
            },
          ),
        ),
      );

      expect(event.oauthErrorCode, 'insufficient_user_authentication');
      expect(event.isStepUpChallenge, isTrue);
      expect(
        event.challenge?.acrValues,
        contains('urn:mace:incommon:iap:silver'),
      );
      expect(event.challenge?.maxAge, Duration.zero);
    });

    test('carries no HTTP fields for a non-OidcException error', () {
      final event = OidcUserInfoFailedEvent.fromError(
        error: const SocketException('offline'),
      );
      expect(event.httpStatusCode, isNull);
      expect(event.oauthErrorCode, isNull);
      expect(event.challenge, isNull);
      expect(event.isStepUpChallenge, isFalse);
    });
  });

  group('UserInfo 401 session reaction (#302)', () {
    test(
      'a live refresh token recovers: refresh + one UserInfo retry, no failure '
      'event',
      () async {
        var userInfoCalls = 0;
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            userInfoCalls++;
            if (userInfoCalls == 1) {
              return http.Response(
                '',
                401,
                headers: const {'www-authenticate': _invalidTokenChallenge},
              );
            }
            return http.Response(
              jsonEncode({'sub': 'user-1', 'email': 'a@b.com'}),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
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
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.validateResumedSession(await _seedUser());
        await pumpEventQueue();

        // Exactly one refresh, and UserInfo retried exactly once after it.
        expect(tokenCalls, 1);
        expect(userInfoCalls, 2);
        // The recovered session carries the refreshed access token + UserInfo.
        expect(result?.token.accessToken, 'at-refreshed');
        expect(result?.userInfo['email'], 'a@b.com');
        // A successful recovery surfaces no failure of any kind.
        expect(events.whereType<OidcUserInfoFailedEvent>(), isEmpty);
        expect(events.whereType<OidcTokenRefreshFailedEvent>(), isEmpty);

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'a dead refresh token emits the UserInfo-failed event and the #120 '
      'terminal event, retaining the user',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            return http.Response(
              '',
              401,
              headers: const {'www-authenticate': _invalidTokenChallenge},
            );
          }
          if (req.url.path.endsWith('/token')) {
            // The refresh token is revoked too — RFC 6749 §5.2 invalid_grant.
            return http.Response(
              jsonEncode({'error': 'invalid_grant'}),
              400,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.validateResumedSession(await _seedUser());
        await pumpEventQueue();

        // The user is retained (no automatic forgetUser).
        expect(result, isNotNull);
        expect(result?.token.accessToken, 'at-seed');

        final userInfoFailure = events
            .whereType<OidcUserInfoFailedEvent>()
            .single;
        expect(userInfoFailure.httpStatusCode, 401);
        expect(userInfoFailure.oauthErrorCode, 'invalid_token');
        expect(userInfoFailure.challenge, isNotNull);

        final refreshFailure = events
            .whereType<OidcTokenRefreshFailedEvent>()
            .single;
        expect(refreshFailure.kind, OidcTokenRefreshFailureKind.terminal);
        expect(refreshFailure.oauthErrorCode, 'invalid_grant');

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'no refresh token: the UserInfo-failed event is surfaced, user retained',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            return http.Response(
              '',
              401,
              headers: const {'www-authenticate': _invalidTokenChallenge},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.validateResumedSession(
          await _seedUser(refreshToken: null),
        );
        await pumpEventQueue();

        expect(result, isNotNull, reason: 'user retained');
        expect(events.whereType<OidcUserInfoFailedEvent>().single, isNotNull);
        // No refresh path is fired when there is no refresh token.
        expect(events.whereType<OidcTokenRefreshFailedEvent>(), isEmpty);

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'a non-401 UserInfo failure does not react (no refresh, no event)',
      () async {
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            // A 5xx is a server error, not a token rejection.
            return http.Response('{}', 500);
          }
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return http.Response('{}', 200);
          }
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.validateResumedSession(await _seedUser());
        await pumpEventQueue();

        // Unchanged behaviour: no recovery refresh, no #302 event, user kept.
        expect(tokenCalls, 0);
        expect(events.whereType<OidcUserInfoFailedEvent>(), isEmpty);
        expect(result?.token.accessToken, 'at-seed');

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'a UserInfo 401 during initial login does not react (not a session '
      'resume)',
      () async {
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            return http.Response(
              '',
              401,
              headers: const {'www-authenticate': _invalidTokenChallenge},
            );
          }
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return http.Response('{}', 200);
          }
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.validateFreshLogin(await _seedUser());
        await pumpEventQueue();

        // The login-context path is unchanged: the 401 is not reacted to.
        expect(tokenCalls, 0);
        expect(events.whereType<OidcUserInfoFailedEvent>(), isEmpty);
        expect(result, isNotNull);

        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'the cached-session resume path (init) recovers a revoked access token',
      () async {
        final store = OidcMemoryStore();
        var userInfoCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            userInfoCalls++;
            if (userInfoCalls == 1) {
              return http.Response(
                '',
                401,
                headers: const {'www-authenticate': _invalidTokenChallenge},
              );
            }
            return http.Response(
              jsonEncode({'sub': 'user-1', 'email': 'a@b.com'}),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
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
          return http.Response('{}', 404);
        });

        // Persist a cached (un-expired, but server-side revoked) session, then
        // resume it in a fresh manager over the same store — the reporter's
        // app-restart scenario.
        final seeder = _make(client: client, store: store);
        await seeder.saveUserRaw(await _seedUser());
        await seeder.dispose();

        final manager = _make(client: client, store: store);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);
        await manager.init();
        await pumpEventQueue();

        expect(manager.currentUser?.token.accessToken, 'at-refreshed');
        expect(manager.currentUser?.userInfo['email'], 'a@b.com');
        expect(events.whereType<OidcUserInfoFailedEvent>(), isEmpty);
        expect(events.whereType<OidcTokenRefreshFailedEvent>(), isEmpty);

        await sub.cancel();
        await manager.dispose();
      },
    );
  });
}
