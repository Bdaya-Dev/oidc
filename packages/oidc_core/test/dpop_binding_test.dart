@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

String _hdr(http.BaseRequest r, String name) => r.headers.entries
    .firstWhere((e) => e.key.toLowerCase() == name.toLowerCase())
    .value;

void main() {
  final endpoint = Uri.parse('https://op.example.com/userinfo');

  test('userInfo presents a DPoP-bound token with the DPoP scheme + ath '
      '(RFC 9449 §7.1)', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'sub': 'user-1'}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final dpop = OidcDPoPManager.generate(const OidcDPoPSettings());

    await OidcEndpoints.userInfo(
      userInfoEndpoint: endpoint,
      accessToken: 'at-123',
      client: client,
      dpopManager: dpop,
      followDistributedClaims: false,
    );

    expect(_hdr(captured!, 'Authorization'), 'DPoP at-123');
    final proof = _hdr(captured!, 'DPoP');
    final payload =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(proof.split('.')[1])),
              ),
            )
            as Map<String, dynamic>;
    expect(payload['ath'], oidcDPoPAth('at-123'));
    expect(payload['htm'], 'GET');
    expect(payload['htu'], 'https://op.example.com/userinfo');
  });

  test('userInfo uses the Bearer scheme when DPoP is not enabled', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'sub': 'u'}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    await OidcEndpoints.userInfo(
      userInfoEndpoint: endpoint,
      accessToken: 'at-123',
      client: client,
      followDistributedClaims: false,
    );

    expect(_hdr(captured!, 'Authorization'), 'Bearer at-123');
    expect(
      captured!.headers.keys.any((k) => k.toLowerCase() == 'dpop'),
      isFalse,
    );
  });
}
