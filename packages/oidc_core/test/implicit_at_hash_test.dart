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

// OpenID Connect Core 1.0 §3.2.2.10 (Implicit ID Token): `at_hash` is
// REQUIRED when the ID Token is issued from the Authorization Endpoint
// ALONGSIDE an access_token (response_type `id_token token`), and "not
// used" when only an id_token is returned (`id_token` alone).
//
// `handleSuccessfulAuthResponse`'s implicit branch went straight from the
// front-channel response to `createUserFromToken`, and `validateUser`'s
// `at_hash` check (§3.2.2.9) only verifies a MATCH when the claim happens to
// be present -- it never enforced the REQUIRED-ness from §3.2.2.10. That let
// an OP (or an attacker shaping the redirect) hand back an id_token that
// never committed to an access_token, paired with a substituted
// access_token, and the implicit flow logged the user in regardless.
//
// #447's hybrid-flow fix added exactly this presence check to
// `validateFrontChannelIdToken` for `code id_token token`. Both flows now share
// one rule: `OidcIdTokenSource.authorizationEndpoint` makes `validateUser`
// require the hash (see id_token_hash_rules_test.dart for the per-source unit
// coverage). This file proves it end to end for plain `id_token token`
// implicit logins, and that `id_token`-only implicit logins (where at_hash is
// "not used") are unaffected.

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
  String subject = 'user-1',
  String? nonce,
  String? atHash,
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
          'nonce': ?nonce,
          'at_hash': ?atHash,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

/// A minimal manager whose platform-channel methods are closures -- just
/// enough to drive the deprecated-but-functional `loginImplicitFlow` end to
/// end (mirrors the harness in `user_manager_flows_coverage_test.dart`).
class _FlowManager extends OidcUserManagerBase {
  _FlowManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    this.onAuthorize,
  });

  Future<OidcAuthorizeResponse?> Function(OidcAuthorizeRequest request)?
  onAuthorize;

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

Future<_FlowManager> _build({
  required Future<OidcAuthorizeResponse?> Function(
    OidcAuthorizeRequest request,
  )
  onAuthorize,
}) async {
  final manager = _FlowManager(
    discoveryDocument: _metadata,
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: MockClient((req) async => http.Response('{}', 404)),
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    onAuthorize: onAuthorize,
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

void main() {
  group(
    'implicit flow `id_token token` requires at_hash (OIDC Core §3.2.2.10)',
    () {
      test(
        'rejects an id_token with no at_hash at all -- no user is created',
        () async {
          final manager = await _build(
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

          expect(
            user,
            isNull,
            reason:
                '`id_token token` MUST carry at_hash (OIDC Core §3.2.2.10); '
                'an id_token missing it must never produce a logged-in user.',
          );
          expect(manager.currentUser, isNull);
          await manager.dispose();
        },
      );

      test('accepts a matching at_hash', () async {
        const accessToken = 'at-implicit';
        final manager = await _build(
          onAuthorize: (request) async => OidcAuthorizeResponse.fromJson({
            'state': request.state,
            'access_token': accessToken,
            'token_type': 'Bearer',
            'id_token': _signIdToken(
              nonce: request.nonce,
              atHash: _hash(accessToken),
            ),
            'expires_in': '3600',
          }),
        );

        // ignore: deprecated_member_use_from_same_package
        final user = await manager.loginImplicitFlow(
          responseType: const ['id_token', 'token'],
        );

        expect(user, isNotNull);
        expect(user!.token.accessToken, accessToken);
        expect(manager.currentUser?.uid, user.uid);
        await manager.dispose();
      });

      test('rejects a mismatched at_hash', () async {
        final manager = await _build(
          onAuthorize: (request) async => OidcAuthorizeResponse.fromJson({
            'state': request.state,
            'access_token': 'at-implicit',
            'token_type': 'Bearer',
            'id_token': _signIdToken(
              nonce: request.nonce,
              atHash: 'totally-wrong',
            ),
            'expires_in': '3600',
          }),
        );

        // ignore: deprecated_member_use_from_same_package
        final user = await manager.loginImplicitFlow(
          responseType: const ['id_token', 'token'],
        );

        expect(user, isNull);
        expect(manager.currentUser, isNull);
        await manager.dispose();
      });
    },
  );

  group('implicit flow `id_token` alone does not require at_hash', () {
    test('accepts an id_token with no access_token and no at_hash', () async {
      final manager = await _build(
        onAuthorize: (request) async => OidcAuthorizeResponse.fromJson({
          'state': request.state,
          'id_token': _signIdToken(nonce: request.nonce),
        }),
      );

      // ignore: deprecated_member_use_from_same_package
      final user = await manager.loginImplicitFlow(
        responseType: const ['id_token'],
      );

      expect(user, isNotNull);
      expect(user!.token.accessToken, isNull);
      await manager.dispose();
    });
  });
}
