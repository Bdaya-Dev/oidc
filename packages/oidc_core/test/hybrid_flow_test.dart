@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Exposes the protected hybrid front-channel validator for direct testing.
class _HybridManager extends OidcUserManagerBase {
  _HybridManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
  });

  Future<void> validateFrontChannel({
    required String idToken,
    required String code,
    required String nonce,
    String? accessToken,
  }) => validateFrontChannelIdToken(
    idToken: idToken,
    accessToken: accessToken,
    code: code,
    nonce: nonce,
    metadata: discoveryDocument,
  );

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
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

Future<String> _signIdToken(Map<String, dynamic> claims) async {
  final key = JsonWebKey.generate('RS256');
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..addRecipient(key, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

/// base64url left-half SHA-256 hash (RS256 id_token).
String _hash(String value) {
  final full = sha256.convert(ascii.encode(value)).bytes;
  return base64Url
      .encode(full.sublist(0, full.length ~/ 2))
      .replaceAll('=', '');
}

Future<_HybridManager> _manager() async {
  final m = _HybridManager(
    discoveryDocument: _metadata,
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      // unsigned/keystore-less: exercise claim binding, not signature.
      strictJwtVerification: false,
    ),
  );
  await m.init();
  return m;
}

void main() {
  group('Hybrid front-channel id_token validation (OIDC Core §3.3.2)', () {
    Map<String, dynamic> claims({
      String nonce = 'nonce-1',
      String? cHash,
      String? atHash,
    }) => {
      'iss': 'https://op.example.com',
      'sub': 'user-1',
      'aud': 'client-1',
      'azp': 'client-1',
      'nonce': nonce,
      'exp':
          clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
      'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
      'c_hash': ?cHash,
      'at_hash': ?atHash,
    };

    test(
      'accepts a valid front-channel id_token (nonce + c_hash + at_hash)',
      () async {
        const code = 'auth-code-1';
        const accessToken = 'fc-access-token';
        final idToken = await _signIdToken(
          claims(cHash: _hash(code), atHash: _hash(accessToken)),
        );
        final m = await _manager();
        // Completes without throwing.
        await m.validateFrontChannel(
          idToken: idToken,
          accessToken: accessToken,
          code: code,
          nonce: 'nonce-1',
        );
      },
    );

    test('rejects a mismatched c_hash', () async {
      final idToken = await _signIdToken(claims(cHash: 'wrong-c-hash'));
      final m = await _manager();
      expect(
        () => m.validateFrontChannel(
          idToken: idToken,
          code: 'auth-code-1',
          nonce: 'nonce-1',
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('rejects a wrong nonce (replay)', () async {
      final idToken = await _signIdToken(
        claims(nonce: 'attacker-nonce', cHash: _hash('auth-code-1')),
      );
      final m = await _manager();
      expect(
        () => m.validateFrontChannel(
          idToken: idToken,
          code: 'auth-code-1',
          nonce: 'nonce-1',
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });
}
