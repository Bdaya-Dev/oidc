@TestOn('vm')
library;

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

Uri _cb(Map<String, String> params) =>
    Uri.parse('https://app.example.com/cb').replace(queryParameters: params);

final _issuer = Uri.parse('https://op.example.com');

void main() {
  group('RFC 9207 authorization-response iss validation', () {
    test('require-when-advertised: missing iss is rejected', () async {
      await expectLater(
        OidcEndpoints.parseAuthorizeResponse(
          responseUri: _cb({'code': 'c', 'state': 's'}),
          expectedIssuer: _issuer,
          requireIss: true,
        ),
        throwsA(isA<OidcException>()),
        reason: 'an AS advertising iss support MUST send iss (§2.4)',
      );
    });

    test('present-but-mismatched iss is rejected (mix-up defense)', () async {
      await expectLater(
        OidcEndpoints.parseAuthorizeResponse(
          responseUri: _cb({
            'code': 'c',
            'state': 's',
            'iss': 'https://attacker.example',
          }),
          expectedIssuer: _issuer,
          requireIss: true,
        ),
        throwsA(
          predicate(
            (e) => e is OidcException && e.toString().contains('mix-up'),
          ),
        ),
      );
    });

    test('matching iss is accepted', () async {
      final resp = await OidcEndpoints.parseAuthorizeResponse(
        responseUri: _cb({
          'code': 'c',
          'state': 's',
          'iss': 'https://op.example.com',
        }),
        expectedIssuer: _issuer,
        requireIss: true,
      );
      expect(resp.code, 'c');
      expect(resp.iss, _issuer);
    });

    test(
      'iss is validated on an ERROR redirect BEFORE the server-error throw',
      () async {
        await expectLater(
          OidcEndpoints.parseAuthorizeResponse(
            responseUri: _cb({
              'error': 'access_denied',
              'iss': 'https://attacker.example',
            }),
            expectedIssuer: _issuer,
            requireIss: true,
          ),
          throwsA(
            predicate(
              // the iss/mix-up error, NOT the server-error for access_denied
              (e) => e is OidcException && e.toString().contains('mix-up'),
            ),
          ),
        );
      },
    );

    test('lenient: requireIss=false + missing iss is accepted', () async {
      final resp = await OidcEndpoints.parseAuthorizeResponse(
        responseUri: _cb({'code': 'c', 'state': 's'}),
        expectedIssuer: _issuer,
      );
      expect(resp.code, 'c');
    });

    test(
      'error response still surfaces serverError when iss is fine (requireIss=false)',
      () async {
        await expectLater(
          OidcEndpoints.parseAuthorizeResponse(
            responseUri: _cb({'error': 'access_denied'}),
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );
  });
}
