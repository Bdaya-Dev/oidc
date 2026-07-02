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
  });

  void seed(OidcUser user) => userSubject.add(user);

  /// Test hook to drive the protected auto-refresh-on-expiry path.
  Future<void> expire(OidcToken token) => handleTokenExpiring(token);

  /// Test hook to drive the protected RFC 8693 token exchange path.
  Future<OidcTokenResponse> exchange({String? subjectToken}) =>
      exchangeToken(subjectToken: subjectToken);

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
  strictVerification: false,
);

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
  'introspection_endpoint': 'https://op.example.com/introspect',
});

Future<_TestManager> _build(http.Client client) async {
  final manager = _TestManager(
    discoveryDocument: _metadata(),
    // client_secret_basic: the secret is authenticated via the Authorization
    // header, so it must never ALSO appear in the token request body.
    clientCredentials: const OidcClientAuthentication.clientSecretBasic(
      clientId: 'client-1',
      clientSecret: 'super-secret',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      strictJwtVerification: false,
    ),
  );
  await manager.init();
  manager.seed(await _user());
  return manager;
}

Map<String, String> _qp(http.Request r) => Uri.splitQueryString(r.body);

void main() {
  group(
    'client auth is sent in exactly one location on refresh (RFC 6749 §2.3)',
    () {
      test(
        'manual refreshToken(): Basic header present, no client_secret in body',
        () async {
          final tokenCalls = <http.Request>[];
          final client = MockClient((req) async {
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

          expect(tokenCalls, isNotEmpty);
          final req = tokenCalls.first;
          expect(
            req.headers['Authorization'],
            startsWith('Basic '),
            reason: 'client_secret_basic must authenticate via the header',
          );
          expect(
            _qp(req).containsKey('client_secret'),
            isFalse,
            reason:
                'the secret must not ALSO be duplicated into the request '
                'body when a Basic header is already present',
          );
          expect(result, isNotNull);
        },
      );

      test(
        'AUTO refresh-on-expiry: Basic header present, no client_secret in body',
        () async {
          final tokenCalls = <http.Request>[];
          final client = MockClient((req) async {
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

          expect(tokenCalls, isNotEmpty);
          final req = tokenCalls.first;
          expect(req.headers['Authorization'], startsWith('Basic '));
          expect(_qp(req).containsKey('client_secret'), isFalse);
        },
      );

      test(
        'exchangeToken(): Basic header present, no client_secret in body',
        () async {
          final tokenCalls = <http.Request>[];
          final client = MockClient((req) async {
            if (req.url.path.endsWith('/token')) {
              tokenCalls.add(req);
              return http.Response(
                '{"access_token":"exchanged-access","token_type":"Bearer",'
                '"expires_in":3600}',
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          });
          final manager = await _build(client);

          final result = await manager.exchange(
            subjectToken: 'access-token-1',
          );

          expect(tokenCalls, isNotEmpty);
          final req = tokenCalls.first;
          expect(
            req.headers['Authorization'],
            startsWith('Basic '),
            reason: 'client_secret_basic must authenticate via the header',
          );
          expect(
            _qp(req).containsKey('client_secret'),
            isFalse,
            reason:
                'the secret must not ALSO be duplicated into the request '
                'body when a Basic header is already present',
          );
          expect(result.accessToken, 'exchanged-access');
        },
      );

      test(
        'introspectToken(): Basic header present, no client_secret in body',
        () async {
          final introspectCalls = <http.Request>[];
          final client = MockClient((req) async {
            if (req.url.path.endsWith('/introspect')) {
              introspectCalls.add(req);
              return http.Response(
                '{"active":true}',
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          });
          final manager = await _build(client);

          final result = await manager.introspectToken();

          expect(introspectCalls, isNotEmpty);
          final req = introspectCalls.first;
          expect(
            req.headers['Authorization'],
            startsWith('Basic '),
            reason: 'client_secret_basic must authenticate via the header',
          );
          expect(
            _qp(req).containsKey('client_secret'),
            isFalse,
            reason:
                'the secret must not ALSO be duplicated into the request '
                'body when a Basic header is already present',
          );
          expect(result.active, isTrue);
        },
      );
    },
  );
}
