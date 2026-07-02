@TestOn('vm')
library;

import 'package:clock/clock.dart';
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
    super.keyStore,
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

/// Fixed signing key shared by every id_token this file mints (including
/// the refresh response's fresh id_token), so it verifies under the
/// now-always-strict verification path when registered directly on the
/// test manager's keyStore (see [_build]).
final _signingKey = JsonWebKey.generate('RS256');

String _signIdToken() {
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

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
  'userinfo_endpoint': 'https://op.example.com/userinfo',
});

Future<_TestManager> _build(http.Client client) async {
  final manager = _TestManager(
    discoveryDocument: _metadata(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
    ),
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
  );
  await manager.init();
  manager.seed(await _user());
  return manager;
}

http.Response _tokenResponse() => http.Response(
  '{"access_token":"new-access","token_type":"Bearer",'
  '"expires_in":3600,"refresh_token":"refresh-token-2",'
  '"id_token":"${_signIdToken()}"}',
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  group('UserInfo missing sub is rejected (OIDC Core §5.3.2)', () {
    test(
      'a UserInfo response without `sub` fails validation and the refresh '
      'is rejected',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return _tokenResponse();
          }
          if (req.url.path.endsWith('/userinfo')) {
            return http.Response(
              '{"email":"user@example.com"}',
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        final manager = await _build(client);
        final originalUser = manager.currentUser;
        expect(originalUser, isNotNull);

        final result = await manager.refreshToken();

        expect(
          result,
          isNull,
          reason:
              '`sub` is REQUIRED in the UserInfo response (OIDC Core '
              '§5.3.2); a response omitting it must be rejected',
        );
        expect(
          manager.currentUser?.token.accessToken,
          originalUser!.token.accessToken,
          reason:
              'a failed validation must not apply the new (unverified) '
              'token/identity to the current user',
        );
      },
    );

    test('a UserInfo response WITH a matching sub is accepted', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          return _tokenResponse();
        }
        if (req.url.path.endsWith('/userinfo')) {
          return http.Response(
            '{"sub":"user-1","email":"user@example.com"}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final manager = await _build(client);

      final result = await manager.refreshToken();

      expect(result, isNotNull);
      expect(manager.currentUser, isNotNull);
    });
  });
}
