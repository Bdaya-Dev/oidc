import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Signature verification is always-strict now (no `keyStore`-less opt-out),
/// so these Content-Type-routing tests sign with a real key and provide a
/// matching keyStore, rather than the previous arbitrary-signature trick.
final _signingKey = JsonWebKey.generate('RS256');

/// Builds a compact JWS string carrying [claims], signed by [_signingKey].
/// Verifying it (rather than parsing unverified) still exercises the thing
/// under test: that `Content-Type` detection routes an `application/jwt`
/// body to the JWT branch instead of the JSON parser.
String _compactJwt(Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(_signingKey, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();

void main() {
  group('OidcEndpoints.userInfo Content-Type handling', () {
    Future<OidcUserInfoResponse> fetch(http.Response response) {
      return OidcEndpoints.userInfo(
        userInfoEndpoint: Uri.parse('https://op.example.com/userinfo'),
        accessToken: 'access-token',
        followDistributedClaims: false,
        keyStore: JsonWebKeyStore()..addKey(_signingKey),
        client: MockClient((_) async => response),
      );
    }

    test(
      'parses an application/jwt response '
      '(regression for #302/#193: package:http lowercases response header '
      'keys, so the Content-Type lookup must use the lowercase key)',
      () async {
        final resp = await fetch(
          http.Response(
            _compactJwt({'sub': 'user-123', 'email': 'u@example.com'}),
            200,
            headers: const {'content-type': 'application/jwt'},
          ),
        );
        expect(resp.sub, equals('user-123'));
        expect(resp.src['email'], equals('u@example.com'));
      },
    );

    test(
      'parses an application/jwt response with a charset parameter',
      () async {
        final resp = await fetch(
          http.Response(
            _compactJwt({'sub': 'user-456'}),
            200,
            headers: const {'content-type': 'application/jwt; charset=utf-8'},
          ),
        );
        expect(resp.sub, equals('user-456'));
      },
    );

    test('still parses a plain application/json response', () async {
      final resp = await fetch(
        http.Response(
          jsonEncode({'sub': 'json-user'}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      expect(resp.sub, equals('json-user'));
    });
  });
}
