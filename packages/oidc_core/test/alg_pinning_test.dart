@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Exposes the protected `resolveAllowedIdTokenAlgorithms` resolver and the
/// front-channel id_token validator for direct testing.
class _PinManager extends OidcUserManagerBase {
  _PinManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.keyStore,
  });

  List<String>? resolvePin(OidcProviderMetadata metadata) =>
      resolveAllowedIdTokenAlgorithms(metadata);

  Future<void> validateFrontChannel({
    required OidcProviderMetadata metadata,
    required String idToken,
    required String code,
    required String nonce,
    String? accessToken,
  }) => validateFrontChannelIdToken(
    idToken: idToken,
    accessToken: accessToken,
    code: code,
    nonce: nonce,
    metadata: metadata,
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

OidcProviderMetadata _meta(List<String>? algs) =>
    OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'authorization_endpoint': 'https://op.example.com/authorize',
      'token_endpoint': 'https://op.example.com/token',
      'id_token_signing_alg_values_supported': ?algs,
    });

_PinManager _manager({
  List<String>? pin,
  JsonWebKeyStore? keyStore,
  List<String>? opAlgs,
}) => _PinManager(
  discoveryDocument: _meta(opAlgs),
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: OidcMemoryStore(),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('com.example.app://cb'),
    allowedIdTokenAlgorithms: pin,
  ),
  keyStore: keyStore,
);

Map<String, dynamic> _baseClaims([Map<String, dynamic>? extra]) => {
  'iss': 'https://op.example.com',
  'sub': 'user-1',
  'aud': 'client-1',
  'exp':
      clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
  ...?extra,
};

OidcToken _tokenWith(String idToken) => OidcToken(
  idToken: idToken,
  accessToken: 'at',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
  creationTime: clock.now(),
);

String _signRs(JsonWebKey key, Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(key, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();

String _signHs(JsonWebKey key, Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(key, algorithm: 'HS256'))
        .build()
        .toCompactSerialization();

/// Builds an UNSIGNED (`alg:none`) compact JWT.
String _unsigned(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.${seg(claims)}.';
}

JsonWebKey _octFromSecret(String secret) => JsonWebKey.fromJson({
  'kty': 'oct',
  'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
  'use': 'sig',
})!;

void main() {
  group('resolveAllowedIdTokenAlgorithms (override semantics)', () {
    test('null pin => uses the OP-advertised list (unchanged behavior)', () {
      final m = _manager(opAlgs: const ['RS256']);
      expect(m.resolvePin(_meta(const ['RS256'])), const ['RS256']);
    });

    test('null pin + OP omits the list => null (the pre-existing gap)', () {
      final m = _manager();
      expect(m.resolvePin(_meta(null)), isNull);
    });

    test(
      'non-null pin REPLACES the OP-advertised list (override, not union)',
      () {
        final m = _manager(pin: const ['RS256']);
        // OP advertises RS256+HS256, but the pin wins and is authoritative.
        expect(m.resolvePin(_meta(const ['RS256', 'HS256'])), const ['RS256']);
      },
    );

    test('pin is used even when the OP omits the list', () {
      final m = _manager(pin: const ['ES256']);
      expect(m.resolvePin(_meta(null)), const ['ES256']);
    });
  });

  group('pin enforcement during id_token verification', () {
    test(
      'default (null pin) + OP [RS256] + RS256 token => verifies (regression)',
      () async {
        final key = JsonWebKey.generate('RS256');
        final m = _manager(opAlgs: const ['RS256']);
        final ks = JsonWebKeyStore()..addKey(key);
        final user = await OidcUser.fromIdToken(
          token: _tokenWith(_signRs(key, _baseClaims())),
          keystore: ks,
          allowedAlgorithms: m.resolvePin(_meta(const ['RS256'])),
        );
        expect(user.claims.subject, 'user-1');
        expect(user.parsedIdToken.isVerified, isTrue);
      },
    );

    test(
      'default (null pin) + OP [RS256,none] + alg:none token => rejected '
      '(none strip; regression guard)',
      () async {
        final m = _manager(opAlgs: const ['RS256', 'none']);
        final ks = JsonWebKeyStore()..addKey(JsonWebKey.generate('RS256'));
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_unsigned(_baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256', 'none'])),
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'pin [RS256] + OP advertises [RS256,HS256] + HS256 token => rejected '
      '(core defense-in-depth: the pin overrides the OP advertisement)',
      () async {
        const secret = 'a-very-secret-client-secret-value-0123456789';
        final hsKey = JsonWebKey.fromJson({
          'kty': 'oct',
          'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
          'alg': 'HS256',
        })!;
        final m = _manager(
          pin: const ['RS256'],
          opAlgs: const ['RS256', 'HS256'],
        );
        // The verifier COULD otherwise use this oct key for HS256.
        final ks = JsonWebKeyStore()..addKey(_octFromSecret(secret));
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_signHs(hsKey, _baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256', 'HS256'])),
          ),
          throwsA(anything),
          reason: 'HS256 is advertised by the OP but not in the pin',
        );
      },
    );

    test(
      'pin [ES256] + OP advertises [RS256] + RS256 token => rejected '
      '(pin overrides rather than unions with the OP list)',
      () async {
        final key = JsonWebKey.generate('RS256');
        final m = _manager(pin: const ['ES256'], opAlgs: const ['RS256']);
        final ks = JsonWebKeyStore()..addKey(key);
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_signRs(key, _baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256'])),
          ),
          throwsA(anything),
        );
      },
    );

    test('pin [RS256] + valid RS256 token => accepted', () async {
      final key = JsonWebKey.generate('RS256');
      final m = _manager(pin: const ['RS256']);
      final ks = JsonWebKeyStore()..addKey(key);
      final user = await OidcUser.fromIdToken(
        token: _tokenWith(_signRs(key, _baseClaims())),
        keystore: ks,
        allowedAlgorithms: m.resolvePin(_meta(null)),
      );
      expect(user.parsedIdToken.isVerified, isTrue);
    });

    test('pin [RS256] + alg:none token => rejected', () async {
      final m = _manager(pin: const ['RS256']);
      final ks = JsonWebKeyStore()..addKey(JsonWebKey.generate('RS256'));
      await expectLater(
        OidcUser.fromIdToken(
          token: _tokenWith(_unsigned(_baseClaims())),
          keystore: ks,
          allowedAlgorithms: m.resolvePin(_meta(null)),
        ),
        throwsA(anything),
      );
    });

    test(
      'default null + OP OMITS the list + alg:none => rejected, but a valid '
      'RS256 token => accepted (documents the gap the pin can close)',
      () async {
        final m = _manager();
        final resolved = m.resolvePin(_meta(null));
        expect(resolved, isNull);

        final ks1 = JsonWebKeyStore()..addKey(JsonWebKey.generate('RS256'));
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_unsigned(_baseClaims())),
            keystore: ks1,
            allowedAlgorithms: resolved,
          ),
          throwsA(anything),
          reason: 'jose_plus auto-rejects alg:none when the list is null',
        );

        final key = JsonWebKey.generate('RS256');
        final ks2 = JsonWebKeyStore()..addKey(key);
        final user = await OidcUser.fromIdToken(
          token: _tokenWith(_signRs(key, _baseClaims())),
          keystore: ks2,
          allowedAlgorithms: resolved,
        );
        expect(user.parsedIdToken.isVerified, isTrue);
      },
    );

    test(
      'fail-closed: empty pin [] rejects every id_token',
      () async {
        final key = JsonWebKey.generate('RS256');
        final m = _manager(pin: const []);
        final ks = JsonWebKeyStore()..addKey(key);
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_signRs(key, _baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256'])),
          ),
          throwsA(anything),
        );
      },
    );

    test(
      "fail-closed: pin ['none'] (=> empty after strip) rejects every id_token",
      () async {
        final key = JsonWebKey.generate('RS256');
        final m = _manager(pin: const ['none']);
        final ks = JsonWebKeyStore()..addKey(key);
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_signRs(key, _baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256'])),
          ),
          throwsA(anything),
        );
      },
    );

    test(
      "case sensitivity: pin ['rs256'] (wrong case) + RS256 token => rejected",
      () async {
        final key = JsonWebKey.generate('RS256');
        final m = _manager(pin: const ['rs256']);
        final ks = JsonWebKeyStore()..addKey(key);
        await expectLater(
          OidcUser.fromIdToken(
            token: _tokenWith(_signRs(key, _baseClaims())),
            keystore: ks,
            allowedAlgorithms: m.resolvePin(_meta(const ['RS256'])),
          ),
          throwsA(anything),
          reason: 'canonical uppercase JWA names are required',
        );
      },
    );
  });

  group('front-channel/hybrid path honours the pin (:1830 site)', () {
    test(
      'pin [RS256] + HS256 front-channel id_token => validateFrontChannelIdToken '
      'throws BEFORE the code is exchanged',
      () async {
        const secret = 'a-very-secret-client-secret-value-0123456789';
        final hsKey = JsonWebKey.fromJson({
          'kty': 'oct',
          'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
          'alg': 'HS256',
        })!;
        // OP advertises HS256, the keystore HAS the HS256 key — so the ONLY
        // reason verification fails is the pin.
        final ks = JsonWebKeyStore()..addKey(_octFromSecret(secret));
        final m = _manager(
          pin: const ['RS256'],
          opAlgs: const ['RS256', 'HS256'],
          keyStore: ks,
        );
        final idToken = _signHs(hsKey, _baseClaims({'nonce': 'nonce-1'}));
        await expectLater(
          m.validateFrontChannel(
            metadata: _meta(const ['RS256', 'HS256']),
            idToken: idToken,
            code: 'auth-code-1',
            nonce: 'nonce-1',
          ),
          // The signature failure surfaces as a (jose_plus) verification error
          // that propagates out before the code is exchanged.
          throwsA(anything),
        );
      },
    );
  });
}
