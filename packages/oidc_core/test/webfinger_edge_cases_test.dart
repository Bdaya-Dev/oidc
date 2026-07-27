import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

final Uri _webFingerUri = Uri.parse(
  'https://example.com/.well-known/webfinger?resource=acct%3Ajoe%40example.com',
);

String _jrdBody() => jsonEncode({
  'subject': 'acct:joe@example.com',
  'links': [
    {
      'rel': OidcConstants_WebFinger.relOpenIdIssuer,
      'href': 'https://server.example.com',
    },
  ],
});

// Cases an adversarial review of the first WebFinger implementation found, each
// reproduced against dart:core before being written down:
//
//   Uri.parse('https://[2001:db8::1]/joe').host  ==  '2001:db8::1'
//   Uri.parse('https://2001:db8::1')             ==  throws FormatException
//   ...replace(queryParameters: {'r': 'a b'})    ==  'r=a+b'
//
// The first two are one bug: Dart hands back an IPv6 host without the RFC 3986
// brackets, and splicing that back into 'https://$host' is unparseable. The
// third is a spec violation: '+' is form encoding, and RFC 7033 §4.1 wants
// RFC 3986 percent-encoding.
void main() {
  group('IPv6 literals keep their RFC 3986 brackets', () {
    test('normalization returns a bracketed host', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'https://[2001:db8::1]/joe',
      );
      expect(id.host, '[2001:db8::1]');
    });

    test('a port is kept outside the brackets', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'https://[2001:db8::1]:8443/op',
      );
      expect(id.host, '[2001:db8::1]:8443');
    });

    test('the request URL round-trips through Uri.parse', () {
      final uri = OidcUtils.getWebFingerUri(
        host: '[2001:db8::1]',
        resource: 'https://[2001:db8::1]/joe',
      );
      expect(uri.host, '2001:db8::1');
      expect(uri.toString(), startsWith('https://[2001:db8::1]/.well-known/'));
    });

    test('an end-to-end IPv6 identifier produces a usable URL', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'https://[2001:db8::1]:8443/op',
      );
      final uri = OidcUtils.getWebFingerUri(
        host: id.host,
        resource: id.resource,
      );
      expect(uri.port, 8443);
      expect(uri.path, '/.well-known/webfinger');
    });
  });

  group('internationalized hosts are refused, not silently mangled', () {
    // Dart percent-encodes a non-ASCII host as UTF-8 rather than converting it
    // to an RFC 5891 A-label:
    //
    //   Uri.parse('https://münchen.de/joe').host == 'm%C3%BCnchen.de'
    //
    // Splicing that into the request URL targets a name no resolver can
    // answer, so the lookup fails late and opaquely. Failing at normalization
    // with the reason named beats emitting a request that cannot work.
    for (final input in [
      'joe@münchen.de',
      'münchen.de',
      'https://münchen.de/joe',
      'acct:joe@münchen.de',
    ]) {
      test('$input is rejected with punycode named', () {
        expect(
          () => OidcUtils.normalizeWebFingerIdentifier(input),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('punycode'),
            ),
          ),
        );
      });
    }

    test('an already-converted A-label passes through untouched', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'joe@xn--mnchen-3ya.de',
      );
      expect(id.host, 'xn--mnchen-3ya.de');
    });
  });

  group('a host Uri.parse rejects surfaces as the documented type', () {
    test('getWebFingerUri throws OidcException, never FormatException', () {
      expect(
        () => OidcUtils.getWebFingerUri(host: '2001:db8::1', resource: 'x'),
        throwsA(isA<OidcException>()),
      );
    });

    test('a host with a non-numeric port throws OidcException', () {
      expect(
        () => OidcUtils.getWebFingerUri(host: 'example.com:zzz', resource: 'x'),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('query encoding is RFC 3986, not form encoding', () {
    test('a space becomes %20 and never +', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:a b@example.com',
      );
      expect(uri.query, contains('%20'));
      expect(uri.query, isNot(contains('+')));
    });

    test('the resource survives a decode round-trip', () {
      const resource = 'acct:a b@example.com';
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: resource,
      );
      expect(uri.queryParameters['resource'], resource);
    });
  });

  group('the scheme heuristic looks only at the authority', () {
    test('a :// inside the path does not make it rule 4', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'joe@example.com/x?next=https://elsewhere.example',
      );
      expect(id.host, 'example.com');
    });

    test('a :// inside the fragment does not make it rule 4', () {
      final id = OidcUtils.normalizeWebFingerIdentifier(
        'example.com/joe#see=http://other.example',
      );
      expect(id.host, 'example.com');
    });
  });

  group('JRD parsing tolerates maps that are not Map<String, dynamic>', () {
    test('a Map<dynamic, dynamic> link is still read', () {
      final resp = OidcWebFingerResponse.fromJson(<String, dynamic>{
        'subject': 'acct:joe@example.com',
        'links': <dynamic>[
          <dynamic, dynamic>{
            'rel': OidcConstants_WebFinger.relOpenIdIssuer,
            'href': 'https://op.example.com',
          },
        ],
      });
      expect(resp.getIssuer(), Uri.parse('https://op.example.com'));
    });
  });

  group('a 3xx that is not a followable redirect is an error', () {
    // `_handleResponseRaw` calls anything below 400 a success, so a 3xx the
    // redirect branch does not claim decodes as a JRD -- and an empty body
    // decodes to an empty, "successful" one. The redirect set covers only
    // 301/302/303/307/308, leaving the rest of the range to be silently
    // mistaken for an answer.
    for (final status in [300, 304, 305, 306]) {
      test('$status does not decode as an empty JRD', () async {
        final client = MockClient((_) async => http.Response('', status));
        await expectLater(
          OidcEndpoints.webFinger(_webFingerUri, client: client),
          throwsA(isA<OidcException>()),
        );
      });
    }
  });

  group('credentials do not survive a cross-origin redirect', () {
    // This loop took redirect handling away from package:http specifically to
    // harden it, so leaving out the credential-stripping browsers perform is a
    // hole in that same hardening rather than a missing extra.
    test('Authorization is dropped when the origin changes', () async {
      final seen = <String, String?>{};
      final client = MockClient((req) async {
        seen[req.url.host] = req.headers['Authorization'];
        if (req.url.host == 'example.com') {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://other.example/.well-known/webfinger',
            },
          );
        }
        return http.Response(_jrdBody(), 200);
      });

      await OidcEndpoints.webFinger(
        _webFingerUri,
        client: client,
        headers: {'Authorization': 'Bearer secret'},
      );

      expect(seen['example.com'], 'Bearer secret');
      expect(seen['other.example'], isNull);
    });

    test('Authorization survives a same-origin redirect', () async {
      final seen = <String, String?>{};
      var hops = 0;
      final client = MockClient((req) async {
        seen['hop$hops'] = req.headers['Authorization'];
        if (hops++ == 0) {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://example.com/.well-known/webfinger?v=2',
            },
          );
        }
        return http.Response(_jrdBody(), 200);
      });

      await OidcEndpoints.webFinger(
        _webFingerUri,
        client: client,
        headers: {'Authorization': 'Bearer secret'},
      );

      expect(seen['hop0'], 'Bearer secret');
      expect(seen['hop1'], 'Bearer secret');
    });
  });
}
