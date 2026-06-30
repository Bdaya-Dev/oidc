@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

final Uri _userInfoEndpoint = Uri.parse('https://op.example.com/userinfo');
final Uri _issuer = Uri.parse('https://op.example.com');
const _clientId = 'client-1';

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// Signs a UserInfo JWT (RS256) with a fresh key and returns it as the body of
/// a `application/jwt` response served by a [MockClient], along with the
/// keyStore that can verify it.
({http.Client client, JsonWebKeyStore keyStore}) _signedUserInfo(
  Map<String, dynamic> claims,
) {
  final key = JsonWebKey.generate('RS256');
  final jwt =
      (JsonWebSignatureBuilder()
            ..jsonContent = claims
            ..addRecipient(key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
  final client = MockClient(
    (req) async => http.Response(
      jwt,
      200,
      headers: const {'content-type': 'application/jwt'},
    ),
  );
  return (client: client, keyStore: JsonWebKeyStore()..addKey(key));
}

Future<OidcUserInfoResponse> _callUserInfo({
  required Map<String, dynamic> claims,
  bool validateSignedResponseClaims = true,
  bool requireSignedResponseIssAud = false,
}) async {
  final fixture = _signedUserInfo(claims);
  return OidcEndpoints.userInfo(
    userInfoEndpoint: _userInfoEndpoint,
    accessToken: 'at',
    keyStore: fixture.keyStore,
    allowedAlgorithms: const ['RS256'],
    expectedIssuer: _issuer,
    clientId: _clientId,
    followDistributedClaims: false,
    validateSignedResponseClaims: validateSignedResponseClaims,
    requireSignedResponseIssAud: requireSignedResponseIssAud,
    client: fixture.client,
  );
}

Map<String, dynamic> _validClaims([Map<String, dynamic>? overrides]) => {
  'sub': 'user-1',
  'iss': 'https://op.example.com',
  'aud': 'client-1',
  'exp': _epoch(clock.now().add(const Duration(hours: 1))),
  ...?overrides,
};

void main() {
  test('valid iss/aud/exp => accepted, claims used', () async {
    final resp = await _callUserInfo(claims: _validClaims());
    expect(resp.sub, 'user-1');
    expect(resp.iss, 'https://op.example.com');
  });

  test('iss != metadata.issuer (attacker issuer) => rejected', () async {
    await expectLater(
      _callUserInfo(
        claims: _validClaims({'iss': 'https://attacker.example'}),
      ),
      throwsA(isA<OidcException>()),
    );
  });

  test('aud does not contain clientId => rejected', () async {
    await expectLater(
      _callUserInfo(claims: _validClaims({'aud': 'some-other-client'})),
      throwsA(isA<OidcException>()),
    );
  });

  test('exp in the past beyond tolerance => rejected', () async {
    await expectLater(
      _callUserInfo(
        claims: _validClaims({
          'exp': _epoch(clock.now().subtract(const Duration(minutes: 5))),
        }),
      ),
      throwsA(isA<OidcException>()),
    );
  });

  test(
    'REGRESSION (force-unwrap guard): no exp claim => accepted, no crash',
    () async {
      final claims = _validClaims()..remove('exp');
      final resp = await _callUserInfo(claims: claims);
      expect(resp.sub, 'user-1');
    },
  );

  test('exp slightly past but within tolerance (skew) => accepted', () async {
    final resp = await _callUserInfo(
      claims: _validClaims({
        'exp': _epoch(clock.now().subtract(const Duration(seconds: 30))),
      }),
    );
    expect(resp.sub, 'user-1');
  });

  test(
    'missing iss + requireSignedResponseIssAud=false (default) => accepted',
    () async {
      final claims = _validClaims()..remove('iss');
      final resp = await _callUserInfo(claims: claims);
      expect(resp.sub, 'user-1');
    },
  );

  test('missing iss + requireSignedResponseIssAud=true => rejected', () async {
    final claims = _validClaims()..remove('iss');
    await expectLater(
      _callUserInfo(claims: claims, requireSignedResponseIssAud: true),
      throwsA(isA<OidcException>()),
    );
  });

  test('missing aud + requireSignedResponseIssAud=true => rejected', () async {
    final claims = _validClaims()..remove('aud');
    await expectLater(
      _callUserInfo(claims: claims, requireSignedResponseIssAud: true),
      throwsA(isA<OidcException>()),
    );
  });

  test(
    'validateSignedResponseClaims=false + iss mismatch => accepted',
    () async {
      final resp = await _callUserInfo(
        claims: _validClaims({'iss': 'https://attacker.example'}),
        validateSignedResponseClaims: false,
      );
      expect(resp.sub, 'user-1');
    },
  );

  test(
    'multi-valued aud that includes clientId among others => accepted',
    () async {
      final resp = await _callUserInfo(
        claims: _validClaims({
          'aud': ['other-client', 'client-1'],
        }),
      );
      expect(resp.sub, 'user-1');
    },
  );

  test(
    'plain application/json UserInfo with no iss/aud/exp => accepted '
    '(validation only applies to the signed-JWT verified branch)',
    () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({'sub': 'user-1'}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final resp = await OidcEndpoints.userInfo(
        userInfoEndpoint: _userInfoEndpoint,
        accessToken: 'at',
        keyStore: JsonWebKeyStore(),
        expectedIssuer: _issuer,
        clientId: _clientId,
        followDistributedClaims: false,
        client: client,
      );
      expect(resp.sub, 'user-1');
    },
  );

  group('null keyStore + signed (application/jwt) UserInfo', () {
    http.Client jwtClient(String body) => MockClient(
      (req) async => http.Response(
        body,
        200,
        headers: const {'content-type': 'application/jwt'},
      ),
    );

    String signedJwt(Map<String, dynamic> claims) {
      final key = JsonWebKey.generate('RS256');
      return (JsonWebSignatureBuilder()
            ..jsonContent = claims
            ..addRecipient(key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
    }

    test(
      'strictJwtVerification=true (default) => throws OidcException '
      '(no silent unverified trust)',
      () async {
        final client = jwtClient(signedJwt(_validClaims()));
        await expectLater(
          OidcEndpoints.userInfo(
            userInfoEndpoint: _userInfoEndpoint,
            accessToken: 'at',
            followDistributedClaims: false,
            client: client,
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test(
      'strictJwtVerification=false => parses unverified claims (opt-out)',
      () async {
        final client = jwtClient(signedJwt(_validClaims()));
        final resp = await OidcEndpoints.userInfo(
          userInfoEndpoint: _userInfoEndpoint,
          accessToken: 'at',
          followDistributedClaims: false,
          strictJwtVerification: false,
          client: client,
        );
        expect(resp.sub, 'user-1');
      },
    );

    test('forged application/jwt + strict (default) => throws', () async {
      final signed = signedJwt(_validClaims());
      // Tamper the signature segment so it can never verify.
      final parts = signed.split('.');
      final forged = '${parts[0]}.${parts[1]}.AAAA${parts[2]}';
      final client = jwtClient(forged);
      await expectLater(
        OidcEndpoints.userInfo(
          userInfoEndpoint: _userInfoEndpoint,
          accessToken: 'at',
          followDistributedClaims: false,
          client: client,
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('plain application/json with null keyStore => unaffected', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({'sub': 'user-1'}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final resp = await OidcEndpoints.userInfo(
        userInfoEndpoint: _userInfoEndpoint,
        accessToken: 'at',
        followDistributedClaims: false,
        client: client,
      );
      expect(resp.sub, 'user-1');
    });
  });
}
