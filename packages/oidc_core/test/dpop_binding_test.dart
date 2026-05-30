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

  test('userInfo retries once with the RS nonce on use_dpop_nonce '
      '(RFC 9449 §9)', () async {
    final proofs = <String>[];
    var calls = 0;
    final client = MockClient((req) async {
      proofs.add(_hdr(req, 'DPoP'));
      calls++;
      if (calls == 1) {
        // First attempt: challenge with a resource-server nonce. The error is
        // carried in WWW-Authenticate (not a JSON body), per RFC 9449 §7.2.
        return http.Response(
          '',
          401,
          headers: const {
            'www-authenticate': 'DPoP error="use_dpop_nonce"',
            'dpop-nonce': 'rs-nonce-1',
          },
        );
      }
      return http.Response(
        jsonEncode({'sub': 'user-1'}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final dpop = OidcDPoPManager.generate(const OidcDPoPSettings());

    final resp = await OidcEndpoints.userInfo(
      userInfoEndpoint: endpoint,
      accessToken: 'at-123',
      client: client,
      dpopManager: dpop,
      followDistributedClaims: false,
    );

    expect(calls, 2, reason: 'exactly one retry');
    expect(resp.src['sub'], 'user-1');

    Map<String, dynamic> payload(String proof) =>
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(proof.split('.')[1])),
              ),
            )
            as Map<String, dynamic>;
    // First proof had no nonce; the retry's proof carries the RS nonce.
    expect(payload(proofs[0]).containsKey('nonce'), isFalse);
    expect(payload(proofs[1])['nonce'], 'rs-nonce-1');
  });
}
