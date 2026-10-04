@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

// OpenID Connect Core 1.0 §12.2 (RefreshTokenResponse): the refresh response
// MAY omit the id_token, in which case the RP retains the previously-issued
// one. `at_hash` (§3.2.2.9) binds an id_token to the access_token issued
// ALONGSIDE it in the SAME response -- so when a refresh returns a new
// access_token but no new id_token, the RETAINED (old) id_token's `at_hash`
// (if it carries one) must not be compared against the NEW access_token: it
// was never issued together with it.
//
// Before the fix, `validateUser`'s `at_hash` match check (OIDC Core
// §3.2.2.9) ran unconditionally whenever the id_token being validated
// carried `at_hash` and the user had an access_token -- including when that
// id_token was merely retained across a refresh that didn't reissue one.
// That produced a false mismatch (the retained id_token's `at_hash` was
// computed for the PRIOR access_token, not the new one), which silently
// rejected an otherwise-valid refresh: `refreshToken()` returned `null`, no
// exception was thrown, no `OidcTokenRefreshFailedEvent` was emitted, and
// `currentUser` was left pointing at the stale (pre-refresh) access_token.

const _issuer = 'https://op.example.com';
final _signingKey = JsonWebKey.generate('RS256');
const _initialAccessToken = 'at-initial';

/// base64url left-half SHA-256 hash (RS256 id_token), OIDC Core §3.2.2.9.
String _hash(String value) {
  final full = sha256.convert(ascii.encode(value)).bytes;
  return base64Url
      .encode(full.sublist(0, full.length ~/ 2))
      .replaceAll('=', '');
}

String _signIdToken(String atHash) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': now + const Duration(hours: 1).inSeconds,
          'iat': now,
          'at_hash': atHash,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

/// Minimal concrete manager for driving the refresh path in a VM test
/// (mirrors the harness in dual_client_auth_refresh_test.dart).
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

final _metadata = OidcProviderMetadata.fromJson({
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
});

Future<_TestManager> _build(http.Client client) async {
  final manager = _TestManager(
    discoveryDocument: _metadata,
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
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
  // Seeded WITHOUT a keystore, same as dual_client_auth_refresh_test.dart's
  // `_user()`: the id_token is parsed but its signature is not verified,
  // which is irrelevant here -- only the `at_hash` claim value matters.
  final initialUser = await OidcUser.fromIdToken(
    token: OidcToken(
      creationTime: clock.now(),
      idToken: _signIdToken(_hash(_initialAccessToken)),
      accessToken: _initialAccessToken,
      refreshToken: 'rt-1',
      tokenType: 'Bearer',
    ),
  );
  manager.seed(initialUser);
  return manager;
}

void main() {
  group(
    'refresh retains the id_token (OIDC Core §12.2): at_hash must not be '
    "checked against a DIFFERENT response's access_token",
    () {
      test(
        'no new id_token in the refresh response: the refresh succeeds and '
        'the new access_token is adopted',
        () async {
          final client = MockClient((req) async {
            if (req.url.path.endsWith('/token')) {
              return http.Response(
                jsonEncode({
                  'access_token': 'at-refreshed',
                  'token_type': 'Bearer',
                  'expires_in': 3600,
                  'refresh_token': 'rt-2',
                  // No `id_token`: OIDC Core §12.2 allows the refresh
                  // response to omit it; the old one is retained.
                }),
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          });
          final manager = await _build(client);

          final result = await manager.refreshToken();

          expect(
            result,
            isNotNull,
            reason:
                "the retained id_token's `at_hash` (computed for the PRIOR "
                'access_token) must not be checked against the refreshed '
                'access_token.',
          );
          expect(result!.token.accessToken, 'at-refreshed');
          expect(manager.currentUser?.token.accessToken, 'at-refreshed');
        },
      );

      test(
        'a new id_token whose at_hash mismatches the new access_token is '
        'rejected',
        () async {
          final client = MockClient((req) async {
            if (req.url.path.endsWith('/token')) {
              return http.Response(
                jsonEncode({
                  'access_token': 'at-refreshed',
                  'token_type': 'Bearer',
                  'expires_in': 3600,
                  'refresh_token': 'rt-2',
                  'id_token': _signIdToken(_hash('someone-elses-token')),
                }),
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          });
          final manager = await _build(client);

          final result = await manager.refreshToken();

          expect(result, isNull);
          expect(
            manager.currentUser?.token.accessToken,
            _initialAccessToken,
            reason: 'a rejected refresh must not adopt the mismatched token.',
          );
        },
      );

      test(
        'a new id_token whose at_hash matches the new access_token is '
        'accepted',
        () async {
          final client = MockClient((req) async {
            if (req.url.path.endsWith('/token')) {
              return http.Response(
                jsonEncode({
                  'access_token': 'at-refreshed',
                  'token_type': 'Bearer',
                  'expires_in': 3600,
                  'refresh_token': 'rt-2',
                  'id_token': _signIdToken(_hash('at-refreshed')),
                }),
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          });
          final manager = await _build(client);

          final result = await manager.refreshToken();

          expect(result, isNotNull);
          expect(result!.token.accessToken, 'at-refreshed');
          expect(manager.currentUser?.token.accessToken, 'at-refreshed');
        },
      );
    },
  );
}
