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

// `at_hash` / `c_hash` bind an id_token to the tokens returned in the SAME
// response (OpenID Connect Core §3.2.2.9, §3.3.2.11). Whether a hash is
// required, and what it is compared with, must therefore come from that
// response, not from the user the manager builds for it.
//
// When a user is already signed in, `createUserFromToken` builds the new user
// with `OidcUser.replaceToken`, which merges the previous token with the new
// one. An access_token from the previous session survives that merge, so a
// rule that reads `user.token.accessToken` sees an access_token even when the
// response returned none, and wrongly requires (and compares) `at_hash` for:
//
// * an implicit `id_token` response, where at_hash is "not used" (§3.2.2.10),
// * a hybrid `code id_token` response, which has no access_token either.
//
// A non-refresh response that carries no id_token (a password re-login here)
// keeps the previous id_token, as it did before. Only a refresh response
// (§12.2), and the stored session it produces, may skip the kept id_token's
// hashes. Any other response compares a present at_hash with its own
// access_token, as on main.

const _issuer = 'https://op.example.com';
final _signingKey = JsonWebKey.generate('RS256');

/// base64url left-half SHA-256 hash (RS256 id_token), OIDC Core §3.2.2.9.
String _hash(String value) {
  final full = sha256.convert(ascii.encode(value)).bytes;
  return base64Url
      .encode(full.sublist(0, full.length ~/ 2))
      .replaceAll('=', '');
}

String _signIdToken({
  String? nonce,
  String? atHash,
  String? cHash,
  Duration expiresIn = const Duration(hours: 1),
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': now + expiresIn.inSeconds,
          'iat': now,
          'nonce': ?nonce,
          'at_hash': ?atHash,
          'c_hash': ?cHash,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

class _FlowManager extends OidcUserManagerBase {
  _FlowManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize;

  /// Calls the protected [createUserFromToken] the way a subclass would.
  Future<OidcUser?> createFromResponse(
    OidcToken token,
    OidcIdTokenValidationContext context,
  ) => createUserFromToken(
    token: token,
    nonce: null,
    attributes: null,
    userInfo: null,
    metadata: _metadata,
    context: context,
  );

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

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);

/// [tokenResponses] are served, in order, by the token endpoint.
Future<_FlowManager> _build({
  List<Map<String, dynamic>> tokenResponses = const [],
}) async {
  final pending = [...tokenResponses];
  final manager = _FlowManager(
    discoveryDocument: _metadata,
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: MockClient((req) async {
      if (req.url.path.endsWith('/token') && pending.isNotEmpty) {
        return _json(pending.removeAt(0));
      }
      return http.Response('unexpected: ${req.url}', 599);
    }),
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      userInfoSettings: const OidcUserInfoSettings(
        sendUserInfoRequest: false,
      ),
    ),
  );
  await manager.init();
  return manager;
}

/// Signs in with an implicit `id_token token` response, so the manager holds
/// a user with access_token [accessToken].
Future<OidcUser> _signInImplicit(
  _FlowManager manager, {
  String accessToken = 'at-first',
}) async {
  manager.onAuthorize = (request) async => OidcAuthorizeResponse.fromJson({
    'state': request.state,
    'access_token': accessToken,
    'token_type': 'Bearer',
    'expires_in': '3600',
    'id_token': _signIdToken(nonce: request.nonce, atHash: _hash(accessToken)),
  });
  // ignore: deprecated_member_use_from_same_package
  final user = await manager.loginImplicitFlow(
    responseType: const ['id_token', 'token'],
  );
  expect(user, isNotNull, reason: 'the first sign-in must succeed');
  expect(manager.currentUser?.token.accessToken, accessToken);
  return user!;
}

void main() {
  group('while signed in with an access_token', () {
    test(
      'an implicit `id_token` login succeeds: no access_token was returned, '
      'so at_hash is not required (§3.2.2.10)',
      () async {
        final manager = await _build();
        await _signInImplicit(manager);
        late String newIdToken;
        manager.onAuthorize = (request) async {
          newIdToken = _signIdToken(nonce: request.nonce);
          return OidcAuthorizeResponse.fromJson({
            'state': request.state,
            'id_token': newIdToken,
          });
        };

        // ignore: deprecated_member_use_from_same_package
        final user = await manager.loginImplicitFlow(
          responseType: const ['id_token'],
        );

        expect(user, isNotNull);
        expect(user!.idToken, newIdToken);
        expect(manager.currentUser?.idToken, newIdToken);
        await manager.dispose();
      },
    );

    test(
      'an implicit `code id_token` login succeeds: c_hash binds the code, '
      'and no access_token was returned',
      () async {
        final manager = await _build();
        await _signInImplicit(manager);
        late String newIdToken;
        manager.onAuthorize = (request) async {
          newIdToken = _signIdToken(
            nonce: request.nonce,
            cHash: _hash('code-2'),
          );
          return OidcAuthorizeResponse.fromJson({
            'state': request.state,
            'code': 'code-2',
            'id_token': newIdToken,
          });
        };

        // ignore: deprecated_member_use_from_same_package
        final user = await manager.loginImplicitFlow(
          responseType: const ['code', 'id_token'],
        );

        expect(user, isNotNull);
        expect(manager.currentUser?.idToken, newIdToken);
        await manager.dispose();
      },
    );

    test(
      'an implicit `id_token token` login compares at_hash with the NEW '
      'access_token, not the previous one',
      () async {
        final manager = await _build();
        final first = await _signInImplicit(manager);
        manager.onAuthorize = (request) async => OidcAuthorizeResponse.fromJson(
          {
            'state': request.state,
            'access_token': 'at-second',
            'token_type': 'Bearer',
            'expires_in': '3600',
            // Bound to the previous session's access_token.
            'id_token': _signIdToken(
              nonce: request.nonce,
              atHash: _hash('at-first'),
            ),
          },
        );

        // ignore: deprecated_member_use_from_same_package
        final user = await manager.loginImplicitFlow(
          responseType: const ['id_token', 'token'],
        );

        expect(user, isNull);
        expect(manager.currentUser?.idToken, first.idToken);
        await manager.dispose();
      },
    );
  });

  group('createUserFromToken takes the access_token from its response', () {
    test(
      'an authorizationEndpoint context without an accessToken still '
      "requires at_hash for the response token's access_token",
      () async {
        final manager = await _build();
        final user = await manager.createFromResponse(
          OidcToken(
            creationTime: clock.now(),
            idToken: _signIdToken(),
            accessToken: 'at-1',
            tokenType: 'Bearer',
          ),
          const OidcIdTokenValidationContext(
            source: OidcIdTokenSource.authorizationEndpoint,
          ),
        );

        expect(user, isNull);
        expect(manager.currentUser, isNull);
        await manager.dispose();
      },
    );
  });

  group('a password re-login whose response has no id_token, as on main', () {
    Map<String, dynamic> loginResponse({String? atHash}) => {
      'access_token': 'at-first',
      'token_type': 'Bearer',
      'expires_in': 3600,
      'id_token': _signIdToken(atHash: atHash),
    };
    const reloginResponse = {
      'access_token': 'at-second',
      'token_type': 'Bearer',
      'expires_in': 3600,
    };

    test('keeps the previous id_token when it has no at_hash', () async {
      final manager = await _build(
        tokenResponses: [loginResponse(), reloginResponse],
      );
      final first = await manager.loginPassword(username: 'a', password: 'b');
      expect(first, isNotNull);

      final second = await manager.loginPassword(username: 'a', password: 'b');

      expect(second, isNotNull);
      expect(second!.token.accessToken, 'at-second');
      expect(second.idToken, first!.idToken);
      await manager.dispose();
    });

    test(
      "is rejected when the previous id_token's at_hash does not match the "
      'new access_token: only a refresh may skip it (§12.2)',
      () async {
        final manager = await _build(
          tokenResponses: [
            loginResponse(atHash: _hash('at-first')),
            reloginResponse,
          ],
        );
        final first = await manager.loginPassword(username: 'a', password: 'b');
        expect(first, isNotNull);

        final second = await manager.loginPassword(
          username: 'a',
          password: 'b',
        );

        expect(second, isNull);
        // #468: the rejected response leaves the previous session in place.
        expect(manager.currentUser?.token.accessToken, 'at-first');
        await manager.dispose();
      },
    );
  });
}
