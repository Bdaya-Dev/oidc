@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

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

/// A concrete manager that exposes the `@protected` on-expiry entry point so a
/// test can drive the deferred-refresh path deterministically (the exact path
/// the CLI `status` crash walked: handleTokenExpired -> _autoRefresh ->
/// _performAutoRefresh -> eventsController.add).
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

  void handleTokenExpiredTest(OidcToken event) => handleTokenExpired(event);

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

Future<_M> _build(http.Client client) async {
  final manager = _M(
    discoveryDocument: _metadata(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
    ),
  );
  await manager.init();
  return manager;
}

/// An already-expired user that still carries a refresh token. `expiresIn` is
/// left `null` so seeding it does NOT arm the token-events timer — the test
/// drives the expiry path itself, deterministically.
Future<OidcUser> _expiredRefreshableUser() => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: clock.now().subtract(const Duration(hours: 2)),
    idToken: _signIdToken(),
    accessToken: 'at-expired',
    refreshToken: 'rt-1',
    tokenType: 'Bearer',
  ),
);

void main() {
  group('#120 post-dispose deferred refresh (close-safety)', () {
    test(
      'a DELAYED refresh that succeeds after dispose() is a complete no-op '
      '(no Bad state, no event, user untouched)',
      () async {
        final refreshResponse = Completer<http.Response>();
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            // Never resolves until the test completes it — models a token
            // endpoint whose response lands only after the manager is gone.
            return refreshResponse.future;
          }
          return http.Response('{}', 404);
        });

        final manager = await _build(client);
        final seededUser = await _expiredRefreshableUser();
        manager.seed(seededUser);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final zoneErrors = <Object>[];
        await runZonedGuarded(
          () async {
            // Kick off the on-expiry refresh; it parks on the delayed response.
            manager.handleTokenExpiredTest(seededUser.token);
            await pumpEventQueue();
            expect(
              tokenCalls,
              1,
              reason: 'the auto-refresh reached the token endpoint',
            );
            final eventsAtDispose = List<OidcEvent>.of(events);

            // Dispose BEFORE the refresh response lands.
            await manager.dispose();

            // Now let the delayed (successful) response resume the refresh.
            refreshResponse.complete(
              http.Response(
                jsonEncode({
                  'access_token': 'at-new',
                  'token_type': 'Bearer',
                  'expires_in': 3600,
                  'id_token': _signIdToken(),
                  'refresh_token': 'rt-2',
                }),
                200,
                headers: const {'content-type': 'application/json'},
              ),
            );
            await pumpEventQueue();

            // No event emitted after dispose closed the controller.
            expect(
              events,
              eventsAtDispose,
              reason: 'no event may be emitted after dispose()',
            );
          },
          (error, stack) => zoneErrors.add(error),
        );

        expect(
          zoneErrors,
          isEmpty,
          reason:
              'a refresh completing after close() must not throw '
              '"Bad state: Cannot add new events after calling close"',
        );
        // User untouched: not replaced by the refreshed user, not forgotten.
        expect(manager.currentUser, same(seededUser));

        await sub.cancel();
      },
    );

    test(
      'a DELAYED refresh that FAILS after dispose() is a complete no-op '
      '(no Bad state, no failure event, no forgetUser)',
      () async {
        final refreshResponse = Completer<http.Response>();
        var tokenCalls = 0;
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return refreshResponse.future;
          }
          return http.Response('{}', 404);
        });

        final manager = await _build(client);
        final seededUser = await _expiredRefreshableUser();
        manager.seed(seededUser);

        final events = <OidcEvent>[];
        final sub = manager.events().listen(events.add);

        final zoneErrors = <Object>[];
        await runZonedGuarded(
          () async {
            manager.handleTokenExpiredTest(seededUser.token);
            await pumpEventQueue();
            expect(tokenCalls, 1);
            final eventsAtDispose = List<OidcEvent>.of(events);

            await manager.dispose();

            // A terminal failure (invalid_grant) — the path that, pre-fix,
            // both emitted OidcTokenRefreshFailedEvent after close AND called
            // forgetUser() on a disposed manager.
            refreshResponse.complete(
              http.Response(
                jsonEncode({'error': 'invalid_grant'}),
                400,
                headers: const {'content-type': 'application/json'},
              ),
            );
            await pumpEventQueue();

            expect(
              events,
              eventsAtDispose,
              reason: 'no failure event may be emitted after dispose()',
            );
          },
          (error, stack) => zoneErrors.add(error),
        );

        expect(
          zoneErrors,
          isEmpty,
          reason: 'a failed refresh after close() must not throw Bad state',
        );
        // The terminal-failure forget path must not have run post-dispose.
        expect(manager.currentUser, same(seededUser));

        await sub.cancel();
      },
    );
  });
}
