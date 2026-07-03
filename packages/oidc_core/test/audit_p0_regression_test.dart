@TestOn('vm')
library;

import 'dart:convert';

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
}

Map<String, String> _qp(http.Request r) => Uri.splitQueryString(r.body);
