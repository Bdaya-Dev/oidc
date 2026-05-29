import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// Builds a compact JWS string carrying [claims]. The signature segment is
/// arbitrary on purpose: these tests exercise the *unverified* parse path
/// (no key store), which is enough to prove `Content-Type` detection routes an
/// `application/jwt` body to the JWT branch instead of the JSON parser.
String _compactJwt(Map<String, dynamic> claims) =>
    '${_b64(const {'alg': 'RS256', 'typ': 'JWT'})}.${_b64(claims)}.AQID';

void main() {
  group('OidcEndpoints.userInfo Content-Type handling', () {
    Future<OidcUserInfoResponse> fetch(http.Response response) {
      return OidcEndpoints.userInfo(
        userInfoEndpoint: Uri.parse('https://op.example.com/userinfo'),
        accessToken: 'access-token',
        followDistributedClaims: false,
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

    test('parses an application/jwt response with a charset parameter',
        () async {
      final resp = await fetch(
        http.Response(
          _compactJwt({'sub': 'user-456'}),
          200,
          headers: const {'content-type': 'application/jwt; charset=utf-8'},
        ),
      );
      expect(resp.sub, equals('user-456'));
    });

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
