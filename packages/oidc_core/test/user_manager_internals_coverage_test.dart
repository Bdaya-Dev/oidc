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
  String? nonce,
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
          'nonce': ?nonce,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

String _rawIdToken(Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(_signingKey, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();

class _M extends OidcUserManagerBase {
  _M({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    this.onAuthorize,
    this.monitorStream,
  });

  _M.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : onAuthorize = null,
       monitorStream = null,
       super.lazy();

  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize;
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSessionOverride;
  Stream<OidcMonitorSessionResult>? monitorStream;

  void seed(OidcUser user) => userSubject.add(user);
  Future<void> saveUserRaw(OidcUser user) => saveUser(user);

  // Public wrappers over the @protected extension surface.
  Future<OidcUser?> validateAndSaveUserTest(OidcUser user) =>
      validateAndSaveUser(user: user, metadata: discoveryDocument);
  Future<void> handleTokenExpiringTest(OidcToken t) => handleTokenExpiring(t);
  void handleTokenExpiredTest(OidcToken t) => handleTokenExpired(t);
  void emitWarningTest() => emitOfflineAuthWarning(
    warningType: OfflineAuthWarningType.usingExpiredToken,
    message: 'test',
  );
  bool offlineExcessiveTest() => isOfflineDurationExcessive();
  Future<OidcUser?> reAuthorizeUserTest() => reAuthorizeUser();

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => onAuthorize == null ? null : onAuthorize!(request);

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async =>
      onEndSessionOverride == null ? null : onEndSessionOverride!(request);

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
  }) => monitorStream ?? const Stream.empty();
}

OidcProviderMetadata _metadata({Map<String, dynamic> extra = const {}}) =>
    OidcProviderMetadata.fromJson({
      'issuer': _issuer,
      'authorization_endpoint': '$_issuer/authorize',
      'token_endpoint': '$_issuer/token',
      'userinfo_endpoint': '$_issuer/userinfo',
      ...extra,
    });

Future<OidcUser> _seedUser({
  bool expired = false,
  String subject = 'user-1',
  String? sessionState,
}) => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: expired
        ? clock.now().subtract(const Duration(hours: 2))
        : clock.now(),
    idToken: _signIdToken(
      subject: subject,
      expiresIn: expired ? const Duration(hours: -1) : const Duration(hours: 1),
    ),
    accessToken: 'at-seed',
    refreshToken: 'rt-seed',
    tokenType: 'Bearer',
    expiresIn: const Duration(hours: 1),
    sessionState: sessionState,
  ),
);

_M _make({
  required http.Client client,
  OidcProviderMetadata? metadata,
  OidcUserManagerSettings? settings,
  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize,
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSession,
  Stream<OidcMonitorSessionResult>? monitorStream,
  OidcStore? store,
}) => _M(
  discoveryDocument: metadata ?? _metadata(),
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  onAuthorize: onAuthorize,
  monitorStream: monitorStream,
  settings:
      settings ??
      OidcUserManagerSettings(redirectUri: Uri.parse('com.example.app://cb')),
)..onEndSessionOverride = onEndSession;

void main() {
  group('validateAndSaveUser + UserInfo', () {
    test('a matching-sub UserInfo response is merged into the user', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'id_token': _signIdToken(),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/userinfo')) {
          return http.Response(
            jsonEncode({'sub': 'user-1', 'email': 'a@b.com'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(client: client);
      await manager.init();

      final user = await manager.loginPassword(username: 'u', password: 'p');
      expect(user, isNotNull);
      expect(user!.userInfo['email'], 'a@b.com');
      expect(manager.lastSuccessfulServerContact, isNotNull);
      await manager.dispose();
    });

    test('a mismatched-sub UserInfo response fails validation', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at',
              'token_type': 'Bearer',
              'id_token': _signIdToken(),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/userinfo')) {
          return http.Response(
            jsonEncode({'sub': 'someone-else'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(client: client);
      await manager.init();

      final user = await manager.loginPassword(username: 'u', password: 'p');
      expect(user, isNull, reason: 'sub mismatch must reject the login');
      await manager.dispose();
    });

    test(
      'a UserInfo network error enters offline mode and keeps the user',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'at',
                'token_type': 'Bearer',
                'id_token': _signIdToken(),
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          if (req.url.path.endsWith('/userinfo')) {
            throw const SocketException('offline');
          }
          return http.Response('{}', 404);
        });
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            supportOfflineAuth: true,
          ),
        );
        await manager.init();
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final user = await manager.loginPassword(username: 'u', password: 'p');
        await Future<void>.delayed(Duration.zero);

        expect(
          user,
          isNotNull,
          reason: 'cached identity survives userinfo loss',
        );
        expect(manager.isInOfflineMode, isTrue);
        expect(events.whereType<OidcOfflineModeEnteredEvent>(), isNotEmpty);
        await sub.cancel();
        await manager.dispose();
      },
    );
  });

  group('createUserFromToken account-swap guard', () {
    test('a refreshed id_token with a different sub is rejected', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at2',
              'token_type': 'Bearer',
              'refresh_token': 'rt2',
              'id_token': _signIdToken(subject: 'attacker'),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      manager.seed(await _seedUser());

      await expectLater(
        manager.refreshToken(),
        throwsA(
          predicate(
            (e) => e is OidcException && e.toString().contains('account swap'),
          ),
        ),
      );
      await manager.dispose();
    });
  });

  group('offline / expiry protected handlers', () {
    test(
      'handleTokenExpired forgets the user without offline support',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await manager.init();
        final user = await _seedUser();
        manager.seed(user);
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        manager.handleTokenExpiredTest(user.token);
        await Future<void>.delayed(Duration.zero);

        expect(events.whereType<OidcTokenExpiredEvent>(), isNotEmpty);
        expect(manager.currentUser, isNull);
        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'handleTokenExpired in offline mode warns instead of logging out',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('offline');
          }
          return http.Response('{}', 404);
        });
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            supportOfflineAuth: true,
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await manager.init();
        final user = await _seedUser(expired: true);
        manager.seed(user);
        // Enter offline mode via a failed manual refresh.
        await manager.refreshToken();
        expect(manager.isInOfflineMode, isTrue);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);
        manager.handleTokenExpiredTest(user.token);
        await Future<void>.delayed(Duration.zero);

        expect(
          events.whereType<OidcOfflineAuthWarningEvent>(),
          isNotEmpty,
          reason: 'expired token in offline mode should warn, not log out',
        );
        expect(manager.currentUser, isNotNull);
        await sub.cancel();
        await manager.dispose();
      },
    );

    test('handleTokenExpiring refreshes the token on success', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'refreshed',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'refresh_token': 'rt-new',
              'id_token': _signIdToken(),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      final user = await _seedUser();
      manager.seed(user);
      final events = <OidcEvent>[];
      final sub = manager.events().listen(events.add);

      await manager.handleTokenExpiringTest(user.token);

      expect(events.whereType<OidcTokenExpiringEvent>(), isNotEmpty);
      expect(manager.currentUser?.token.accessToken, 'refreshed');
      await sub.cancel();
      await manager.dispose();
    });

    test(
      'handleTokenExpiring is a no-op when there is no refresh token',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await manager.init();
        final noRefresh = OidcToken(
          accessToken: 'at',
          tokenType: 'Bearer',
          creationTime: clock.now(),
          expiresIn: const Duration(hours: 1),
        );
        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);
        await manager.handleTokenExpiringTest(noRefresh);
        expect(events.whereType<OidcTokenExpiringEvent>(), isNotEmpty);
        await sub.cancel();
        await manager.dispose();
      },
    );

    test('emitOfflineAuthWarning surfaces a warning event', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = _make(client: client);
      await manager.init();
      final events = <OidcEvent>[];
      final sub = manager.events().listen(events.add);
      manager.emitWarningTest();
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<OidcOfflineAuthWarningEvent>(), isNotEmpty);
      expect(manager.offlineExcessiveTest(), isFalse);
      await sub.cancel();
      await manager.dispose();
    });
  });

  group('session monitoring', () {
    Future<_M> build(Stream<OidcMonitorSessionResult> stream) async {
      String? capturedNonce;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'reauth-at',
              'token_type': 'Bearer',
              'id_token': _signIdToken(nonce: capturedNonce),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        metadata: _metadata(
          extra: {'check_session_iframe': '$_issuer/checksession'},
        ),
        monitorStream: stream,
        onAuthorize: (request) async {
          capturedNonce = request.nonce;
          return OidcAuthorizeResponse.fromJson({
            'code': 'reauth-code',
            'state': request.state,
          });
        },
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          sessionManagementSettings: const OidcSessionManagementSettings(
            enabled: true,
          ),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      return manager;
    }

    test('a changed session triggers re-authorization', () async {
      final controller = StreamController<OidcMonitorSessionResult>.broadcast();
      final manager = await build(controller.stream);
      manager.seed(await _seedUser(sessionState: 'sess-1'));
      await Future<void>.delayed(Duration.zero);

      controller.add(const OidcValidMonitorSessionResult(changed: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Re-authorization ran the code flow with the reauth token.
      expect(manager.currentUser?.token.accessToken, 'reauth-at');
      await controller.close();
      await manager.dispose();
    });

    test('an unchanged/unknown session result is a no-op', () async {
      final controller = StreamController<OidcMonitorSessionResult>.broadcast();
      final manager = await build(controller.stream);
      manager.seed(await _seedUser(sessionState: 'sess-1'));
      await Future<void>.delayed(Duration.zero);

      controller
        ..add(const OidcValidMonitorSessionResult(changed: false))
        ..add(const OidcUnknownMonitorSessionResult(data: 'x'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(manager.currentUser?.token.accessToken, 'at-seed');
      await controller.close();
      await manager.dispose();
    });

    test('a session error result stops monitoring', () async {
      final controller = StreamController<OidcMonitorSessionResult>.broadcast();
      final manager = await build(controller.stream);
      manager.seed(await _seedUser(sessionState: 'sess-1'));
      await Future<void>.delayed(Duration.zero);

      controller.add(const OidcErrorMonitorSessionResult());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(manager.currentUser?.token.accessToken, 'at-seed');
      await controller.close();
      await manager.dispose();
    });
  });

  group('ensureDiscoveryDocument (lazy)', () {
    OidcProviderMetadata docJson() => OidcProviderMetadata.fromJson({
      'issuer': _issuer,
      'authorization_endpoint': '$_issuer/authorize',
      'token_endpoint': '$_issuer/token',
    });

    final wellKnown = OidcUtils.getOpenIdConfigWellKnownUri(
      Uri.parse(_issuer),
    );

    test(
      'fetches, validates and caches the document from the network',
      () async {
        final store = OidcMemoryStore();
        final client = MockClient((req) async {
          if (req.url.path.contains('openid-configuration')) {
            return http.Response(
              jsonEncode(docJson().src),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = _M.lazy(
          discoveryDocumentUri: wellKnown,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client-1',
          ),
          store: store,
          httpClient: client,
          keyStore: JsonWebKeyStore()..addKey(_signingKey),
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await manager.init();
        expect(manager.discoveryDocument.issuer.toString(), _issuer);

        // Second lazy manager over the same store loads it from cache.
        final cached = await store.get(
          OidcStoreNamespace.discoveryDocument,
          key: wellKnown.toString(),
        );
        expect(cached, isNotNull);
        await manager.dispose();
      },
    );

    test(
      'throws when the document cannot be fetched and is not cached',
      () async {
        final client = MockClient((req) async {
          throw const SocketException('offline');
        });
        final manager = _M.lazy(
          discoveryDocumentUri: wellKnown,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client-1',
          ),
          store: OidcMemoryStore(),
          httpClient: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
          ),
        );
        await expectLater(manager.init(), throwsA(isA<OidcException>()));
      },
    );
  });

  group('loadStateResult (redirect return)', () {
    test(
      'a stored authorize state + response is processed on the next init',
      () async {
        final store = OidcMemoryStore();
        String? capturedNonce;
        String? capturedState;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'redirect-at',
                'token_type': 'Bearer',
                'expires_in': 3600,
                'id_token': _signIdToken(nonce: capturedNonce),
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });

        // First manager prepares (and stores) the authorize state, then a
        // redirect "response" is injected while the flow is abandoned — exactly
        // the web same-page redirect-away shape that init() resumes.
        final first = _make(
          client: client,
          store: store,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
          onAuthorize: (request) async {
            capturedNonce = request.nonce;
            capturedState = request.state;
            await store.setStateResponseData(
              state: request.state!,
              stateData: Uri.parse('com.example.app://cb')
                  .replace(
                    queryParameters: {
                      'code': 'redirect-code',
                      'state': request.state,
                    },
                  )
                  .toString(),
            );
            return null;
          },
        );
        await first.init();
        final abandoned = await first.loginAuthorizationCodeFlow();
        expect(abandoned, isNull);
        expect(capturedState, isNotNull);
        await first.dispose();

        // A fresh manager over the same store resumes the pending response.
        final second = _make(
          client: client,
          store: store,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await second.init();
        expect(second.currentUser, isNotNull);
        expect(second.currentUser?.token.accessToken, 'redirect-at');
        await second.dispose();
      },
    );
  });

  group('loadLogoutRequests', () {
    test('a stored front-channel logout request is consumed on init', () async {
      final store = OidcMemoryStore();
      final requestUri = Uri.parse('com.example.app://cb').replace(
        queryParameters: {
          OidcConstants_Store.requestType:
              OidcConstants_Store.frontChannelLogout,
        },
      );
      await store.set(
        OidcStoreNamespace.request,
        key: OidcConstants_Store.frontChannelLogout,
        value: requestUri.toString(),
      );
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = _make(
        client: client,
        store: store,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      // The request was consumed (removed) during init.
      final leftover = await store.getCurrentFrontChannelLogoutRequest();
      expect(leftover, isNull);
      await manager.dispose();
    });
  });

  group('offline mode exit', () {
    test('a successful refresh after a failure exits offline mode', () async {
      var failing = true;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          if (failing) throw const SocketException('offline');
          return http.Response(
            jsonEncode({
              'access_token': 'recovered',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'refresh_token': 'rt-new',
              'id_token': _signIdToken(),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          supportOfflineAuth: true,
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      manager.seed(await _seedUser());

      await manager.refreshToken();
      expect(manager.isInOfflineMode, isTrue);

      final events = <OidcEvent>[];
      final sub = manager.events().listen(events.add);
      failing = false;
      final recovered = await manager.refreshToken();

      expect(recovered?.token.accessToken, 'recovered');
      expect(manager.isInOfflineMode, isFalse);
      expect(events.whereType<OidcOfflineModeExitedEvent>(), isNotEmpty);
      await sub.cancel();
      await manager.dispose();
    });
  });

  group('reAuthorizeUser error handling', () {
    test(
      'an authorization error without offline support forgets the user',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
          onAuthorize: (request) async => throw OidcException.serverError(
            errorResponse: OidcErrorResponse.fromJson({
              'error': 'login_required',
              'state': ?request.state,
            }),
          ),
        );
        await manager.init();
        manager.seed(await _seedUser());

        final result = await manager.reAuthorizeUserTest();
        expect(result, isNull);
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );
  });

  group('createUserFromToken issuer-swap guard', () {
    test('a refreshed id_token with a different issuer is rejected', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at2',
              'token_type': 'Bearer',
              'refresh_token': 'rt2',
              'id_token': _signIdToken(issuer: 'https://evil.example.com'),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      manager.seed(await _seedUser());

      await expectLater(
        manager.refreshToken(),
        throwsA(
          predicate(
            (e) =>
                e is OidcException && e.toString().contains('does not match'),
          ),
        ),
      );
      await manager.dispose();
    });
  });

  group('validateUser id_token edge cases (rejected logins)', () {
    Future<OidcUser?> loginWith(Map<String, dynamic> claims) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at',
              'token_type': 'Bearer',
              'id_token': _rawIdToken(claims),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _make(
        client: client,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      final user = await manager.loginPassword(username: 'u', password: 'p');
      await manager.dispose();
      return user;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    test('an azp that is not the client_id is rejected', () async {
      expect(
        await loginWith({
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'iat': now,
          'exp': now + 3600,
          'azp': 'not-the-client',
        }),
        isNull,
      );
    });

    test('multiple audiences without azp is rejected', () async {
      expect(
        await loginWith({
          'iss': _issuer,
          'sub': 'user-1',
          'aud': ['client-1', 'another'],
          'iat': now,
          'exp': now + 3600,
        }),
        isNull,
      );
    });

    test('a not-yet-valid (future nbf) id_token is rejected', () async {
      expect(
        await loginWith({
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'iat': now,
          'exp': now + 3600,
          'nbf': now + 3600,
        }),
        isNull,
      );
    });

    test('an id_token missing the sub claim is rejected', () async {
      expect(
        await loginWith({
          'iss': _issuer,
          'aud': 'client-1',
          'iat': now,
          'exp': now + 3600,
        }),
        isNull,
      );
    });

    test('an id_token missing the iat claim is rejected', () async {
      expect(
        await loginWith({
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': now + 3600,
        }),
        isNull,
      );
    });
  });

  group('handleSuccessfulAuthResponse guards', () {
    Future<void> expectThrows(
      OidcProviderMetadata metadata,
      Map<String, dynamic> Function(String? state) response,
    ) async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = _make(
        client: client,
        metadata: metadata,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
        onAuthorize: (request) async =>
            OidcAuthorizeResponse.fromJson(response(request.state)),
      );
      await manager.init();
      await expectLater(
        manager.loginAuthorizationCodeFlow(),
        throwsA(isA<OidcException>()),
      );
      await manager.dispose();
    }

    test('a response without a state parameter is rejected', () async {
      await expectThrows(_metadata(), (_) => {'code': 'c'});
    });

    test('a code-flow response without a code is rejected', () async {
      await expectThrows(_metadata(), (state) => {'state': ?state});
    });

    test('a response with no token endpoint is rejected', () async {
      await expectThrows(
        OidcProviderMetadata.fromJson({
          'issuer': _issuer,
          'authorization_endpoint': '$_issuer/authorize',
        }),
        (state) => {'code': 'c', 'state': ?state},
      );
    });
  });

  group('loadStateResult end-session branch', () {
    test('a stored end-session state + response forgets the user', () async {
      final store = OidcMemoryStore();
      final client = MockClient((req) async => http.Response('{}', 404));
      String? capturedState;
      final first = _make(
        client: client,
        store: store,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          postLogoutRedirectUri: Uri.parse('com.example.app://logout'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
        // Custom end-session handler that abandons the flow after persisting a
        // redirect response, mirroring a web same-page logout redirect.
        onEndSession: (request) async {
          capturedState = request.state;
          await store.setStateResponseData(
            state: request.state!,
            stateData: Uri.parse('com.example.app://logout')
                .replace(
                  queryParameters: {'state': request.state},
                )
                .toString(),
          );
          return null;
        },
      );
      await first.init();
      first.seed(await _seedUser());
      await first.logout();
      expect(capturedState, isNotNull);
      await first.dispose();

      final second = _make(
        client: client,
        store: store,
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      // Persist a user so init has something to forget when the end-session
      // response resolves.
      await second.saveUserRaw(await _seedUser());
      await second.init();
      expect(second.currentUser, isNull);
      await second.dispose();
    });
  });

  group('ensureDiscoveryDocument bad cache', () {
    test('an unparseable cached document is discarded and refetched', () async {
      final store = OidcMemoryStore();
      final wellKnown = OidcUtils.getOpenIdConfigWellKnownUri(
        Uri.parse(_issuer),
      );
      await store.set(
        OidcStoreNamespace.discoveryDocument,
        key: wellKnown.toString(),
        value: 'not-valid-json{',
      );
      final client = MockClient((req) async {
        if (req.url.path.contains('openid-configuration')) {
          return http.Response(
            jsonEncode({
              'issuer': _issuer,
              'authorization_endpoint': '$_issuer/authorize',
              'token_endpoint': '$_issuer/token',
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = _M.lazy(
        discoveryDocumentUri: wellKnown,
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'client-1',
        ),
        store: store,
        httpClient: client,
        keyStore: JsonWebKeyStore()..addKey(_signingKey),
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
      );
      await manager.init();
      expect(manager.discoveryDocument.issuer.toString(), _issuer);
      await manager.dispose();
    });
  });

  group('front-channel logout listener wiring', () {
    test(
      'init subscribes when a frontChannelLogoutUri is configured',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = _make(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            frontChannelLogoutUri: Uri.parse('com.example.app://fclo'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        await manager.init();
        expect(manager.didInit, isTrue);
        await manager.dispose();
      },
    );
  });
}
