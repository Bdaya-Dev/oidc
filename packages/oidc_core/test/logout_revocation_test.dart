@TestOn('vm')
library;

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// A manager that lets a test seed a logged-in user and that resolves the
/// end-session flow to null (no platform redirect).
class _LogoutManager extends OidcUserManagerBase {
  _LogoutManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  void seed(OidcUser user) => userSubject.add(user);

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

OidcProviderMetadata _metadata({bool withRevocation = true}) =>
    OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'authorization_endpoint': 'https://op.example.com/authorize',
      'token_endpoint': 'https://op.example.com/token',
      'end_session_endpoint': 'https://op.example.com/logout',
      if (withRevocation)
        'revocation_endpoint': 'https://op.example.com/revoke',
    });

Future<OidcUser> _user() async {
  final key = JsonWebKey.generate('RS256');
  final idToken =
      (JsonWebSignatureBuilder()
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
            }
            ..addRecipient(key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
  return OidcUser.fromIdToken(
    token: OidcToken(
      creationTime: clock.now(),
      idToken: idToken,
      accessToken: 'access-token-1',
      refreshToken: 'refresh-token-1',
      tokenType: 'Bearer',
    ),
  );
}

Future<_LogoutManager> _build(
  List<http.Request> revocations, {
  required bool revokeOnLogout,
  bool withRevocationEndpoint = true,
  bool failRevocation = false,
}) async {
  final client = MockClient((req) async {
    if (req.url.path.endsWith('/revoke')) {
      revocations.add(req);
      if (failRevocation) {
        return http.Response('{"error":"server_error"}', 500);
      }
      return http.Response('', 200);
    }
    return http.Response('{}', 404);
  });
  final manager = _LogoutManager(
    discoveryDocument: _metadata(withRevocation: withRevocationEndpoint),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      revokeTokensOnLogout: revokeOnLogout,
    ),
  );
  await manager.init();
  manager.seed(await _user());
  return manager;
}

Map<String, String> _body(http.Request r) => Uri.splitQueryString(r.body);

void main() {
  group('revoke-on-logout (RFC 7009)', () {
    test('logout revokes the refresh + access tokens by default', () async {
      final revocations = <http.Request>[];
      final manager = await _build(revocations, revokeOnLogout: true);

      await manager.logout();

      final hints = revocations.map((r) => _body(r)['token_type_hint']).toSet();
      expect(hints, containsAll(<String>['refresh_token', 'access_token']));
      final tokens = revocations.map((r) => _body(r)['token']).toSet();
      expect(
        tokens,
        containsAll(<String>['refresh-token-1', 'access-token-1']),
      );
      expect(manager.currentUser, isNull, reason: 'logout still completes');
    });

    test('logout does NOT revoke when revokeTokensOnLogout is false', () async {
      final revocations = <http.Request>[];
      final manager = await _build(revocations, revokeOnLogout: false);

      await manager.logout();

      expect(revocations, isEmpty);
      expect(manager.currentUser, isNull);
    });

    test('logout completes even if revocation fails (best-effort)', () async {
      final revocations = <http.Request>[];
      final manager = await _build(
        revocations,
        revokeOnLogout: true,
        failRevocation: true,
      );

      // Must not throw despite the 500s.
      await manager.logout();

      expect(revocations, isNotEmpty, reason: 'revocation was attempted');
      expect(manager.currentUser, isNull, reason: 'logout still completed');
    });

    test('no revocation_endpoint -> logout is a clean no-op revoke', () async {
      final revocations = <http.Request>[];
      final manager = await _build(
        revocations,
        revokeOnLogout: true,
        withRevocationEndpoint: false,
      );

      await manager.logout();

      expect(revocations, isEmpty);
      expect(manager.currentUser, isNull);
    });
  });
}
