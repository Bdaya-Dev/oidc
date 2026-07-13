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

/// A concrete manager whose platform-channel methods are supplied as closures
/// so a single harness can drive code / implicit / logout flows.
class _FlowManager extends OidcUserManagerBase {
  _FlowManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    this.onAuthorize,
    this.onEndSession,
  });

  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize;
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSession;

  void seed(OidcUser user) => userSubject.add(user);

  // Thin public wrappers so the test can drive the @protected surface.
  Future<OidcTokenResponse> exchangeTokenTest() => exchangeToken();
  Future<void> saveUserTest(OidcUser user) => saveUser(user);

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
  ) async => onEndSession == null ? null : onEndSession!(request);

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

OidcProviderMetadata _metadata({
  Map<String, dynamic> extra = const {},
}) => OidcProviderMetadata.fromJson({
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
  'revocation_endpoint': '$_issuer/revoke',
  'introspection_endpoint': '$_issuer/introspect',
  ...extra,
});

Future<_FlowManager> _build({
  required http.Client client,
  OidcProviderMetadata? metadata,
  OidcUserManagerSettings? settings,
  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize,
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSession,
  OidcStore? store,
}) async {
  final manager = _FlowManager(
    discoveryDocument: metadata ?? _metadata(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: store ?? OidcMemoryStore(),
    httpClient: client,
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    onAuthorize: onAuthorize,
    onEndSession: onEndSession,
    settings:
        settings ??
        OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
          // These coverage tests pin the pre-existing blocking init semantics
          // (cache validated/refreshed before init() completes).
          initMode: OidcInitMode.blockingValidate,
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        ),
  );
  await manager.init();
  return manager;
}

void main() {
  group('loginPassword', () {
    test('creates a verified user from the token response', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          final body = Uri.splitQueryString(req.body);
          expect(body['grant_type'], OidcConstants_GrantType.password);
          return http.Response(
            jsonEncode({
              'access_token': 'at-pw',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'id_token': _signIdToken(),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = await _build(client: client);

      final user = await manager.loginPassword(
        username: 'alice',
        password: 'secret',
      );

      expect(user, isNotNull);
      expect(user!.token.accessToken, 'at-pw');
      expect(user.parsedIdToken.isVerified, isTrue);
      expect(manager.currentUser?.uid, user.uid);
      await manager.dispose();
    });
  });

  group('loginImplicitFlow (deprecated)', () {
    test('builds a user from a front-channel implicit response', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(
        client: client,
        metadata: OidcProviderMetadata.fromJson({
          'issuer': _issuer,
          'authorization_endpoint': '$_issuer/authorize',
          'token_endpoint': '$_issuer/token',
        }),
        onAuthorize: (request) async => OidcAuthorizeResponse.fromJson({
          'state': request.state,
          'access_token': 'at-implicit',
          'token_type': 'Bearer',
          'id_token': _signIdToken(nonce: request.nonce),
          'expires_in': '3600',
        }),
      );

      // ignore: deprecated_member_use_from_same_package
      final user = await manager.loginImplicitFlow(
        responseType: const ['id_token', 'token'],
      );

      expect(user, isNotNull);
      expect(user!.token.accessToken, 'at-implicit');
      expect(user.parsedIdToken.isVerified, isTrue);
      await manager.dispose();
    });
  });

  group('loginAuthorizationCodeFlow (full success)', () {
    test('exchanges the code and builds a verified user', () async {
      String? capturedNonce;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'at-code',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'refresh_token': 'rt-code',
              'id_token': _signIdToken(nonce: capturedNonce),
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = await _build(
        client: client,
        onAuthorize: (request) async {
          capturedNonce = request.nonce;
          return OidcAuthorizeResponse.fromJson({
            'code': 'auth-code-1',
            'state': request.state,
          });
        },
      );

      final user = await manager.loginAuthorizationCodeFlow();
      expect(user, isNotNull);
      expect(user!.token.accessToken, 'at-code');
      expect(user.token.refreshToken, 'rt-code');
      expect(manager.currentUser, isNotNull);
      await manager.dispose();
    });

    test(
      'a cancelled authorization (null response) leaves no current user',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = await _build(
          client: client,
          onAuthorize: (request) async => null,
        );
        final user = await manager.loginAuthorizationCodeFlow();
        expect(user, isNull);
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );
  });

  group('logout', () {
    test(
      'with no post_logout_redirect_uri forgets the user immediately',
      () async {
        final client = MockClient((req) async => http.Response('{}', 200));
        final manager = await _build(client: client);
        manager.seed(await _seedUser());
        expect(manager.currentUser, isNotNull);

        await manager.logout();
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );

    test(
      'with a redirect uri round-trips end-session state and forgets the user',
      () async {
        final client = MockClient((req) async => http.Response('{}', 200));
        final manager = await _build(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            postLogoutRedirectUri: Uri.parse('com.example.app://logout'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
          onEndSession: (request) async => OidcEndSessionResponse.fromJson({
            'state': request.state,
          }),
        );
        manager.seed(await _seedUser());

        await manager.logout();
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );

    test(
      'a null end-session result still forgets the user (native platform)',
      () async {
        final client = MockClient((req) async => http.Response('{}', 200));
        final manager = await _build(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            postLogoutRedirectUri: Uri.parse('com.example.app://logout'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
          onEndSession: (request) async => null,
        );
        manager.seed(await _seedUser());

        await manager.logout();
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );

    test('is a no-op when there is no current user', () async {
      final client = MockClient((req) async => http.Response('{}', 200));
      final manager = await _build(client: client);
      await manager.logout();
      expect(manager.currentUser, isNull);
      await manager.dispose();
    });

    test(
      'revokeTokensOnLogout best-effort revokes before ending the session',
      () async {
        final revoked = <String>[];
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/revoke')) {
            revoked.add(Uri.splitQueryString(req.body)['token'] ?? '');
            return http.Response('', 200);
          }
          return http.Response('{}', 200);
        });
        final manager = await _build(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        manager.seed(await _seedUser());

        await manager.logout();
        expect(revoked, containsAll(<String>['rt-seed', 'at-seed']));
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );
  });

  group('revokeAccessToken / revokeRefreshToken', () {
    test('revoking the access token forgets the user on success', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/revoke')) return http.Response('', 200);
        return http.Response('{}', 404);
      });
      final manager = await _build(client: client);
      manager.seed(await _seedUser());
      await manager.revokeAccessToken();
      expect(manager.currentUser, isNull);
      await manager.dispose();
    });

    test('revoking the refresh token forgets the user on success', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/revoke')) return http.Response('', 200);
        return http.Response('{}', 404);
      });
      final manager = await _build(client: client);
      manager.seed(await _seedUser());
      await manager.revokeRefreshToken();
      expect(manager.currentUser, isNull);
      await manager.dispose();
    });

    test('no revocation endpoint is a no-op that keeps the user', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(
        client: client,
        metadata: OidcProviderMetadata.fromJson({
          'issuer': _issuer,
          'token_endpoint': '$_issuer/token',
        }),
      );
      manager.seed(await _seedUser());
      await manager.revokeAccessToken();
      await manager.revokeRefreshToken();
      expect(manager.currentUser, isNotNull);
      await manager.dispose();
    });

    test('revocation is a no-op when there is no current user', () async {
      final client = MockClient((req) async => http.Response('', 200));
      final manager = await _build(client: client);
      await manager.revokeAccessToken();
      await manager.revokeRefreshToken();
      expect(manager.currentUser, isNull);
      await manager.dispose();
    });
  });

  group('introspectToken', () {
    test('returns the parsed introspection response', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/introspect')) {
          return http.Response(
            jsonEncode({'active': true, 'scope': 'openid'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = await _build(client: client);
      manager.seed(await _seedUser());

      final resp = await manager.introspectToken();
      expect(resp.active, isTrue);
      expect(resp.scope, 'openid');
      await manager.dispose();
    });

    test('throws when the provider has no introspection endpoint', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(
        client: client,
        metadata: OidcProviderMetadata.fromJson({
          'issuer': _issuer,
          'token_endpoint': '$_issuer/token',
        }),
      );
      manager.seed(await _seedUser());
      await expectLater(
        manager.introspectToken(),
        throwsA(isA<OidcException>()),
      );
      await manager.dispose();
    });

    test('throws when there is no token to introspect', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(client: client);
      await expectLater(
        manager.introspectToken(),
        throwsA(isA<OidcException>()),
      );
      await manager.dispose();
    });
  });

  group('exchangeToken (RFC 8693)', () {
    test('exchanges the current access token for a new one', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          final body = Uri.splitQueryString(req.body);
          expect(body['grant_type'], OidcConstants_GrantType.tokenExchange);
          expect(body['subject_token'], 'at-seed');
          return http.Response(
            jsonEncode({'access_token': 'exchanged', 'token_type': 'Bearer'}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = await _build(client: client);
      manager.seed(await _seedUser());

      final resp = await manager.exchangeTokenTest();
      expect(resp.accessToken, 'exchanged');
      // Exchange does not change the logged-in user.
      expect(manager.currentUser?.token.accessToken, 'at-seed');
      await manager.dispose();
    });

    test(
      'throws when neither a subject token nor a user is available',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = await _build(client: client);
        await expectLater(
          manager.exchangeTokenTest(),
          throwsA(isA<OidcException>()),
        );
        await manager.dispose();
      },
    );
  });

  group('refreshToken offline handling', () {
    test(
      'a network failure with supportOfflineAuth keeps the cached user and '
      'enters offline mode',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('offline');
          }
          return http.Response('{}', 404);
        });
        final manager = await _build(
          client: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            supportOfflineAuth: true,
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          ),
        );
        final seeded = await _seedUser();
        manager.seed(seeded);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final result = await manager.refreshToken();
        await Future<void>.delayed(Duration.zero);

        expect(result?.token.accessToken, seeded.token.accessToken);
        expect(manager.isInOfflineMode, isTrue);
        expect(
          events.whereType<OidcOfflineModeEnteredEvent>(),
          isNotEmpty,
          reason: 'a recoverable network error must announce offline mode',
        );
        await sub.cancel();
        await manager.dispose();
      },
    );

    test(
      'a network failure without offline support rethrows the error',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            throw const SocketException('offline');
          }
          return http.Response('{}', 404);
        });
        final manager = await _build(client: client);
        manager.seed(await _seedUser());
        await expectLater(
          manager.refreshToken(),
          throwsA(isA<SocketException>()),
        );
        await manager.dispose();
      },
    );

    test('returns null when there is no refresh token', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(client: client);
      // No user seeded -> no refresh token.
      expect(await manager.refreshToken(), isNull);
      await manager.dispose();
    });
  });

  group('loadCachedTokens on re-init', () {
    test(
      'a persisted valid token is restored into a new manager instance',
      () async {
        final store = OidcMemoryStore();
        final client = MockClient((req) async => http.Response('{}', 404));

        final first = await _build(client: client, store: store);
        // Persist a user via the manager save path.
        final user = await _seedUser();
        await first.saveUserTest(user);
        await first.dispose();

        // A fresh manager over the same store must reload the cached user.
        final second = await _build(client: client, store: store);
        expect(second.currentUser, isNotNull);
        expect(second.currentUser?.token.accessToken, 'at-seed');
        await second.dispose();
      },
    );

    test(
      'a persisted expired token with a refresh token is refreshed on load',
      () async {
        final store = OidcMemoryStore();
        String tokenBody() => jsonEncode({
          'access_token': 'refreshed-at',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'rt-seed',
          'id_token': _signIdToken(),
        });
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              tokenBody(),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });

        final first = await _build(client: client, store: store);
        await first.saveUserTest(await _seedUser(expired: true));
        await first.dispose();

        final second = await _build(client: client, store: store);
        expect(second.currentUser, isNotNull);
        expect(second.currentUser?.token.accessToken, 'refreshed-at');
        await second.dispose();
      },
    );
  });

  group('loginDeviceCodeFlow endpoint guards', () {
    test('throws when the provider has no token endpoint', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final manager = await _build(
        client: client,
        metadata: OidcProviderMetadata.fromJson({'issuer': _issuer}),
      );
      await expectLater(
        manager.loginDeviceCodeFlow(),
        throwsA(isA<OidcException>()),
      );
      await manager.dispose();
    });

    test(
      'throws when the provider has no device_authorization_endpoint',
      () async {
        final client = MockClient((req) async => http.Response('{}', 404));
        final manager = await _build(
          client: client,
          metadata: OidcProviderMetadata.fromJson({
            'issuer': _issuer,
            'token_endpoint': '$_issuer/token',
          }),
        );
        await expectLater(
          manager.loginDeviceCodeFlow(),
          throwsA(isA<OidcException>()),
        );
        await manager.dispose();
      },
    );
  });
}

Future<OidcUser> _seedUser({bool expired = false}) => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: expired
        ? clock.now().subtract(const Duration(hours: 2))
        : clock.now(),
    idToken: _signIdToken(
      expiresIn: expired ? const Duration(hours: -1) : const Duration(hours: 1),
    ),
    accessToken: 'at-seed',
    refreshToken: 'rt-seed',
    tokenType: 'Bearer',
    expiresIn: const Duration(hours: 1),
  ),
);
