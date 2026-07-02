@TestOn('vm')
library;

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Minimal concrete manager that captures the [OidcEndSessionRequest] built
/// by [OidcUserManagerBase.logout] instead of actually driving a platform
/// end-session flow.
class _TestManager extends OidcUserManagerBase {
  _TestManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  void seed(OidcUser user) => userSubject.add(user);

  OidcEndSessionRequest? capturedRequest;

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
  ) async {
    capturedRequest = request;
    return null;
  }

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

String _signIdToken() {
  final key = JsonWebKey.generate('RS256');
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
        ..addRecipient(key, algorithm: 'RS256'))
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
  'end_session_endpoint': 'https://op.example.com/end-session',
});

Future<_TestManager> _build({Uri? postLogoutRedirectUri}) async {
  final client = MockClient((req) async => http.Response('{}', 404));
  final manager = _TestManager(
    discoveryDocument: _metadata(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      postLogoutRedirectUri: postLogoutRedirectUri,
    ),
  );
  await manager.init();
  manager.seed(await _user());
  return manager;
}

void main() {
  group('RP-initiated logout always sends id_token_hint', () {
    test(
      'id_token_hint is present even when there is NO '
      'post_logout_redirect_uri',
      () async {
        final manager = await _build();
        final idToken = manager.currentUser!.idToken;

        await manager.logout();

        expect(manager.capturedRequest, isNotNull);
        expect(manager.capturedRequest!.postLogoutRedirectUri, isNull);
        expect(
          manager.capturedRequest!.idTokenHint,
          idToken,
          reason:
              'id_token_hint must not be withheld just because no '
              'post_logout_redirect_uri was requested',
        );
      },
    );

    test(
      'id_token_hint is present when a post_logout_redirect_uri IS set',
      () async {
        final manager = await _build(
          postLogoutRedirectUri: Uri.parse('com.example.app://logged-out'),
        );
        final idToken = manager.currentUser!.idToken;

        await manager.logout();

        expect(manager.capturedRequest, isNotNull);
        expect(manager.capturedRequest!.postLogoutRedirectUri, isNotNull);
        expect(manager.capturedRequest!.idTokenHint, idToken);
      },
    );
  });
}
