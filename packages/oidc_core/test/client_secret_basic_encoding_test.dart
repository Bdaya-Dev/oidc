@TestOn('vm')
library;

import 'dart:convert';

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('client_secret_basic percent-encoding (RFC 6749 §2.3.1)', () {
    test(
      'a secret with reserved/special characters is form-urlencoded before '
      'the colon-join + base64',
      () {
        const clientId = 'client:1';
        const clientSecret = 's3cr%t &+special';
        const auth = OidcClientAuthentication.clientSecretBasic(
          clientId: clientId,
          clientSecret: clientSecret,
        );

        final header = auth.getAuthorizationHeader();
        expect(header, isNotNull);
        expect(header, startsWith('Basic '));

        final decoded = utf8.decode(
          base64.decode(header!.substring('Basic '.length)),
        );
        final expected =
            '${Uri.encodeQueryComponent(clientId)}:'
            '${Uri.encodeQueryComponent(clientSecret)}';
        expect(decoded, expected);
        // Sanity: the raw, un-encoded concatenation must NOT be what's sent.
        expect(decoded, isNot('$clientId:$clientSecret'));
      },
    );

    test(
      'a plain alphanumeric secret produces an unchanged header '
      '(backward compat)',
      () {
        const clientId = 'client1';
        const clientSecret = 'secret123';
        const auth = OidcClientAuthentication.clientSecretBasic(
          clientId: clientId,
          clientSecret: clientSecret,
        );

        final header = auth.getAuthorizationHeader();
        final expectedRaw = base64.encode(
          utf8.encode('$clientId:$clientSecret'),
        );
        expect(header, 'Basic $expectedRaw');
      },
    );
  });
}
