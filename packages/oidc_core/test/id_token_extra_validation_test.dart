@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

class _ValidationManager extends OidcUserManagerBase {
  _ValidationManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
  });

  List<Exception> run(
    OidcUser user,
    OidcProviderMetadata metadata, {
    String? authorizationCode,
    Duration? maxAge,
  }) => validateUser(
    user: user,
    metadata: metadata,
    authorizationCode: authorizationCode,
    maxAge: maxAge,
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

Map<String, dynamic> _baseClaims() => {
  'iss': 'https://op.example.com',
  'sub': 'user-1',
  'aud': 'client-1',
  'azp': 'client-1',
  'exp':
      clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
};

Future<OidcUser> _user(
  Map<String, dynamic> claims, {
  String? accessToken,
}) async {
  final idToken = await _signIdToken(claims);
  return OidcUser.fromIdToken(
    // keystore null -> unverified; we exercise claim validation, not signature.
    token: OidcToken(
      idToken: idToken,
      accessToken: accessToken,
      tokenType: 'Bearer',
      expiresIn: const Duration(hours: 1),
      creationTime: clock.now(),
    ),
  );
}

_ValidationManager _manager({
  List<String>? allowedAudiences,
  Uri? expectedIssuer,
}) => _ValidationManager(
  discoveryDocument: _metadata,
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'client-1',
  ),
  store: OidcMemoryStore(),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('com.example.app://cb'),
    allowedAudiences: allowedAudiences,
    expectedIssuer: expectedIssuer,
  ),
);

void main() {
  group('oidcComputeTokenHash', () {
    test(
      'is the base64url left-half of the alg hash (independently computed)',
      () {
        const token = 'jHkWEdUXMU1BwAsC4vtUsZwnNvTIxEl0z9K3vx5KF0Y';
        final full = sha256.convert(ascii.encode(token)).bytes;
        final expected = base64Url
            .encode(full.sublist(0, full.length ~/ 2))
            .replaceAll('=', '');
        expect(oidcComputeTokenHash('RS256', token), expected);
        expect(oidcComputeTokenHash('ES256', token), expected);
      },
    );

    test('uses SHA-384/512 for *384/*512 algs', () {
      const token = 'abc';
      expect(
        oidcComputeTokenHash('RS384', token)!.length,
        isNot(oidcComputeTokenHash('RS256', token)!.length),
      );
      expect(oidcComputeTokenHash('ES512', token), isNotNull);
    });

    test('returns null for unsupported alg or non-ASCII value', () {
      expect(oidcComputeTokenHash('none', 'abc'), isNull);
      expect(oidcComputeTokenHash('RS256', 'tokén'), isNull);
    });
  });

  group('oidcReadJwtAlg', () {
    test('reads the alg from a signed JWT header', () async {
      final jwt = await _signIdToken(_baseClaims());
      expect(oidcReadJwtAlg(jwt), 'RS256');
    });
    test('returns null on a non-JWT string', () {
      expect(oidcReadJwtAlg('not-a-jwt'), isNull);
    });
  });

  group('validateUser aud strictness (§3.1.3.7)', () {
    test('rejects an untrusted extra audience', () async {
      final user = await _user({
        ..._baseClaims(),
        'aud': ['client-1', 'other-rp'],
      });
      final errors = _manager().run(user, _metadata);
      expect(
        errors.any((e) => e.toString().contains('untrusted audience')),
        isTrue,
      );
    });

    test('accepts an extra audience listed in allowedAudiences', () async {
      final user = await _user({
        ..._baseClaims(),
        'aud': ['client-1', 'trusted-api'],
      });
      final errors = _manager(
        allowedAudiences: ['trusted-api'],
      ).run(user, _metadata);
      expect(
        errors.any((e) => e.toString().contains('untrusted audience')),
        isFalse,
      );
    });
  });

  group('validateUser at_hash (§3.2.2.9)', () {
    test('accepts a matching at_hash', () async {
      const accessToken = 'access-token-xyz';
      // The id_token is RS256-signed (see _signIdToken), so at_hash uses SHA-256.
      final full = sha256.convert(ascii.encode(accessToken)).bytes;
      final atHash = base64Url
          .encode(full.sublist(0, full.length ~/ 2))
          .replaceAll('=', '');
      final user = await _user(
        {..._baseClaims(), 'at_hash': atHash},
        accessToken: accessToken,
      );
      final errors = _manager().run(user, _metadata);
      expect(errors.any((e) => e.toString().contains('at_hash')), isFalse);
    });

    test('rejects a mismatched at_hash', () async {
      final user = await _user(
        {..._baseClaims(), 'at_hash': 'totally-wrong'},
        accessToken: 'access-token-xyz',
      );
      final errors = _manager().run(user, _metadata);
      expect(errors.any((e) => e.toString().contains('at_hash')), isTrue);
    });
  });

  group('validateUser c_hash (§3.3.2.11)', () {
    String hashOf(String value) {
      // The id_token is RS256-signed (see _signIdToken), so c_hash uses SHA-256.
      final full = sha256.convert(ascii.encode(value)).bytes;
      return base64Url
          .encode(full.sublist(0, full.length ~/ 2))
          .replaceAll('=', '');
    }

    test('accepts a matching c_hash', () async {
      const code = 'auth-code-xyz';
      final user = await _user({..._baseClaims(), 'c_hash': hashOf(code)});
      final errors = _manager().run(user, _metadata, authorizationCode: code);
      expect(errors.any((e) => e.toString().contains('c_hash')), isFalse);
    });

    test('rejects a mismatched c_hash', () async {
      final user = await _user({..._baseClaims(), 'c_hash': 'totally-wrong'});
      final errors = _manager().run(
        user,
        _metadata,
        authorizationCode: 'auth-code-xyz',
      );
      expect(errors.any((e) => e.toString().contains('c_hash')), isTrue);
    });

    test('ignores c_hash when no authorization code is threaded in', () async {
      final user = await _user({..._baseClaims(), 'c_hash': 'whatever'});
      final errors = _manager().run(user, _metadata); // no code
      expect(errors.any((e) => e.toString().contains('c_hash')), isFalse);
    });
  });

  group('validateUser auth_time vs max_age (§3.1.2.1)', () {
    int secondsAgo(Duration d) =>
        clock.now().subtract(d).millisecondsSinceEpoch ~/ 1000;

    test(
      'rejects when max_age was requested but auth_time is missing',
      () async {
        final user = await _user(_baseClaims()); // no auth_time
        final errors = _manager().run(
          user,
          _metadata,
          maxAge: const Duration(minutes: 5),
        );
        expect(
          errors.any((e) => e.toString().contains('auth_time')),
          isTrue,
        );
      },
    );

    test('accepts a recent auth_time within max_age', () async {
      final user = await _user({
        ..._baseClaims(),
        'auth_time': secondsAgo(const Duration(minutes: 1)),
      });
      final errors = _manager().run(
        user,
        _metadata,
        maxAge: const Duration(minutes: 5),
      );
      expect(errors.any((e) => e.toString().contains('auth_time')), isFalse);
    });

    test('rejects an auth_time older than max_age', () async {
      final user = await _user({
        ..._baseClaims(),
        'auth_time': secondsAgo(const Duration(hours: 1)),
      });
      final errors = _manager().run(
        user,
        _metadata,
        maxAge: const Duration(minutes: 5),
      );
      expect(errors.any((e) => e.toString().contains('older than')), isTrue);
    });

    test('ignores auth_time when max_age was not requested', () async {
      final user = await _user({
        ..._baseClaims(),
        'auth_time': secondsAgo(const Duration(hours: 10)),
      });
      final errors = _manager().run(user, _metadata); // no maxAge
      expect(errors.any((e) => e.toString().contains('auth_time')), isFalse);
    });
  });

  group('validateUser exp requirement (OIDC Core §2)', () {
    test(
      'returns a collected error (does not throw) when exp is missing',
      () async {
        final claims = _baseClaims()..remove('exp');
        final user = await _user(claims);
        // Must not throw a raw TypeError out of validateUser; the missing `exp`
        // is collected as a normal validation error.
        final errors = _manager().run(user, _metadata);
        expect(
          errors.any((e) => e.toString().contains('exp')),
          isTrue,
        );
      },
    );
  });

  group('validateUser issuer pinning (#168, Entra multi-tenant §3.1.3.7)', () {
    // Microsoft Entra ID multi-tenant (`common`/`organizations`) advertises a
    // non-substituted TEMPLATE issuer, while a real id_token carries the
    // CONCRETE per-tenant issuer — the two can never be equal, so the
    // spec-mandated exact `iss` match fails unless the RP pins the concrete one.
    final templateMetadata = OidcProviderMetadata.fromJson({
      'issuer': 'https://login.microsoftonline.com/{tenantid}/v2.0',
      'authorization_endpoint': 'https://op.example.com/authorize',
      'token_endpoint': 'https://op.example.com/token',
    });
    const concreteIssuer =
        'https://login.microsoftonline.com/'
        '11c43ee8-b9d3-4e51-b73f-bd9dda66e29c/v2.0';

    Future<OidcUser> concreteTenantUser() =>
        _user({..._baseClaims(), 'iss': concreteIssuer});

    test(
      'passes when expectedIssuer pins the concrete tenant issuer',
      () async {
        final user = await concreteTenantUser();
        final errors = _manager(
          expectedIssuer: Uri.parse(concreteIssuer),
        ).run(user, templateMetadata);
        // The concrete `iss` now matches the pinned expectedIssuer, so the
        // otherwise-valid token produces no validation errors at all.
        expect(errors, isEmpty);
      },
    );

    test(
      'fails with an issuer mismatch when expectedIssuer is unset '
      '(regression pin: default behavior is unchanged)',
      () async {
        final user = await concreteTenantUser();
        // No expectedIssuer -> the advertised template `metadata.issuer` is used
        // exactly as before, and the concrete `iss` fails the exact-match check.
        final errors = _manager().run(user, templateMetadata);
        expect(
          errors.any((e) => e.toString().contains('Issuer does not match')),
          isTrue,
        );
      },
    );
  });
}
