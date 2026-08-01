import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const String _issuerRel = OidcConstants_WebFinger.relOpenIdIssuer;

/// A minimal RFC 7033 §4.4 JRD carrying a single OIDC issuer link.
Map<String, dynamic> _jrd({
  String subject = 'acct:joe@example.com',
  List<Map<String, dynamic>>? links,
}) => {
  'subject': subject,
  'links':
      links ??
      [
        {'rel': _issuerRel, 'href': 'https://server.example.com'},
      ],
};

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/jrd+json'},
    );

void main() {
  group('OidcUtils.getWebFingerUri', () {
    test('reproduces the §2.2.1 request line verbatim', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:joe@example.com',
      );
      expect(
        uri.toString(),
        'https://example.com/.well-known/webfinger'
        '?resource=acct%3Ajoe%40example.com'
        '&rel=http%3A%2F%2Fopenid.net%2Fspecs%2Fconnect%2F1.0%2Fissuer',
      );
    });

    test('reproduces the §2.2.4 double-encoded resource verbatim', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'shopping.example.com',
        resource: 'acct:juliet%40capulet.example@shopping.example.com',
      );
      expect(
        uri.query,
        'resource=acct%3Ajuliet%2540capulet.example%40shopping.example.com'
        '&rel=http%3A%2F%2Fopenid.net%2Fspecs%2Fconnect%2F1.0%2Fissuer',
      );
    });

    test('the scheme is always https, even for an http resource', () {
      // RFC 7033 §4.2/§9.1: the query MUST be issued over HTTPS only.
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'http://example.com/joe',
      );
      expect(uri.scheme, 'https');
    });

    test('a host:port authority is preserved', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com:8080',
        resource: 'https://example.com:8080/',
      );
      expect(uri.host, 'example.com');
      expect(uri.port, 8080);
      expect(uri.path, '/.well-known/webfinger');
    });

    test('the well-known path is exactly /.well-known/webfinger', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:joe@example.com',
      );
      expect(
        uri.pathSegments,
        OidcConstants_WebFinger.wellKnownPathSegments,
      );
    });

    test('several rel values are emitted as repeated parameters', () {
      // RFC 7033 §4.3: "The 'rel' parameter MAY be included multiple times".
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:joe@example.com',
        rel: const [_issuerRel, 'http://webfinger.example/rel/profile-page'],
      );
      expect(uri.queryParametersAll['rel'], [
        _issuerRel,
        'http://webfinger.example/rel/profile-page',
      ]);
    });

    test('an empty rel list omits the parameter entirely', () {
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:joe@example.com',
        rel: const [],
      );
      expect(uri.queryParameters.containsKey('rel'), isFalse);
      expect(uri.queryParameters['resource'], 'acct:joe@example.com');
    });

    test('host is never sent as a query parameter', () {
      // OIDC Discovery §2 calls `host` a WebFinger parameter, but every §2.2.x
      // example conveys it as the URL authority, not in the query.
      final uri = OidcUtils.getWebFingerUri(
        host: 'example.com',
        resource: 'acct:joe@example.com',
      );
      expect(uri.queryParameters.keys, ['resource', 'rel']);
    });

    test('a host with no authority throws', () {
      expect(
        () => OidcUtils.getWebFingerUri(
          host: '',
          resource: 'acct:joe@example.com',
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('OidcWebFingerResponse', () {
    test('parses every RFC 7033 §4.4 member', () {
      final resp = OidcWebFingerResponse.fromJson({
        'subject': 'acct:bob@example.com',
        'aliases': ['https://www.example.com/~bob/'],
        'properties': {'http://example.com/ns/role': 'employee'},
        'links': [
          {
            'rel': 'http://webfinger.example/rel/profile-page',
            'type': 'text/html',
            'href': 'https://www.example.com/~bob/',
            'titles': {'en-us': "Bob Smith's Blog"},
            'properties': {'http://example.com/ns/role': 'editor'},
          },
        ],
      });

      expect(resp.subject, 'acct:bob@example.com');
      expect(resp.aliases, ['https://www.example.com/~bob/']);
      expect(resp.properties, {'http://example.com/ns/role': 'employee'});
      expect(resp.links, hasLength(1));

      final link = resp.links.single;
      expect(link.rel, 'http://webfinger.example/rel/profile-page');
      expect(link.type, 'text/html');
      expect(link.href, Uri.parse('https://www.example.com/~bob/'));
      expect(link.titles, {'en-us': "Bob Smith's Blog"});
      expect(link.properties, {'http://example.com/ns/role': 'editor'});
    });

    test('a null property value is preserved', () {
      // RFC 7033 §4.4.3: a property value is a string OR null.
      final resp = OidcWebFingerResponse.fromJson({
        'properties': {'http://example.com/ns/role': null},
      });
      expect(resp.properties, {'http://example.com/ns/role': null});
    });

    group('tolerant parsing (RFC 7033 §4.4)', () {
      test('an absent links member yields an empty list', () {
        final resp = OidcWebFingerResponse.fromJson({
          'subject': 'acct:a@b.com',
        });
        expect(resp.links, isEmpty);
        expect(resp.aliases, isEmpty);
        expect(resp.properties, isEmpty);
      });

      test('a non-list links member yields an empty list', () {
        final resp = OidcWebFingerResponse.fromJson({'links': 'nonsense'});
        expect(resp.links, isEmpty);
      });

      test('non-object elements inside links are skipped', () {
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            'nonsense',
            42,
            null,
            {'rel': _issuerRel, 'href': 'https://server.example.com'},
          ],
        });
        expect(resp.links, hasLength(1));
        expect(resp.links.single.rel, _issuerRel);
      });

      test('an unknown member is ignored, not an error', () {
        final resp = OidcWebFingerResponse.fromJson({
          'subject': 'acct:a@b.com',
          'some_future_member': {'deeply': 'nested'},
        });
        expect(resp.subject, 'acct:a@b.com');
        // Asserting `src['some_future_member']` would only re-read the map the
        // test just handed in, and would hold for any implementation. What the
        // unknown member must not do is disturb the typed getters.
        expect(resp.links, isEmpty);
        expect(resp.getIssuer(), isNull);
      });

      test('a malformed href becomes null instead of throwing', () {
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            {'rel': _issuerRel, 'href': 'https://server.example:notaport'},
          ],
        });
        expect(resp.links.single.href, isNull);
      });

      test('a non-string rel/type/href becomes null', () {
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            {'rel': 42, 'type': false, 'href': 12345},
          ],
        });
        expect(resp.links.single.rel, isNull);
        expect(resp.links.single.type, isNull);
        expect(resp.links.single.href, isNull);
      });

      test('a non-list aliases member yields an empty list', () {
        final resp = OidcWebFingerResponse.fromJson({'aliases': 'nonsense'});
        expect(resp.aliases, isEmpty);
      });
    });

    group('linksWithRel', () {
      test('filters client-side when the server ignored the rel parameter', () {
        // RFC 7033 §4.3: rel support is only a SHOULD, and a server that does
        // not support it MUST return every link. The client can therefore never
        // assume the response is already filtered.
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            {
              'rel': 'http://webfinger.example/rel/profile-page',
              'href': 'https://www.example.com/~bob/',
            },
            {'rel': _issuerRel, 'href': 'https://server.example.com'},
            {
              'rel': 'http://webfinger.example/rel/avatar',
              'href': 'https://a/',
            },
          ],
        });

        final filtered = resp.linksWithRel(_issuerRel);
        expect(filtered, hasLength(1));
        expect(filtered.single.href, Uri.parse('https://server.example.com'));
      });

      test('rel comparison is exact and case-sensitive', () {
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            {
              'rel': 'HTTP://OPENID.NET/SPECS/CONNECT/1.0/ISSUER',
              'href': 'https://server.example.com',
            },
          ],
        });
        expect(resp.linksWithRel(_issuerRel), isEmpty);
      });

      test('a link with no rel is never matched', () {
        final resp = OidcWebFingerResponse.fromJson({
          'links': [
            {'href': 'https://server.example.com'},
          ],
        });
        expect(resp.linksWithRel(_issuerRel), isEmpty);
      });
    });

    group('getIssuer', () {
      test('returns the href of the matching link', () {
        expect(
          OidcWebFingerResponse.fromJson(_jrd()).getIssuer(),
          Uri.parse('https://server.example.com'),
        );
      });

      test('returns the FIRST valid candidate in links order', () {
        // RFC 7033 §4.4.4: array order MAY indicate an order of preference.
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel, 'href': 'https://first.example.com'},
              {'rel': _issuerRel, 'href': 'https://second.example.com'},
            ],
          ),
        );
        expect(resp.getIssuer(), Uri.parse('https://first.example.com'));
      });

      test('skips a matching link that has no href and keeps iterating', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel},
              {'rel': _issuerRel, 'href': 'https://server.example.com'},
            ],
          ),
        );
        expect(resp.getIssuer(), Uri.parse('https://server.example.com'));
      });

      test('skips a matching link whose href is unparseable', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel, 'href': 'https://bad.example:notaport'},
              {'rel': _issuerRel, 'href': 'https://server.example.com'},
            ],
          ),
        );
        expect(resp.getIssuer(), Uri.parse('https://server.example.com'));
      });

      test('rejects a non-https issuer location', () {
        // OIDC Discovery §2: the Issuer location's scheme MUST be https.
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel, 'href': 'http://server.example.com'},
            ],
          ),
        );
        expect(resp.getIssuer(), isNull);
      });

      test('rejects an issuer location with a query or fragment', () {
        for (final bad in const [
          'https://server.example.com?a=b',
          'https://server.example.com#frag',
        ]) {
          final resp = OidcWebFingerResponse.fromJson(
            _jrd(
              links: [
                {'rel': _issuerRel, 'href': bad},
              ],
            ),
          );
          expect(resp.getIssuer(), isNull, reason: bad);
        }
      });

      test('rejects an issuer location with no host', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel, 'href': 'https:///justapath'},
            ],
          ),
        );
        expect(resp.getIssuer(), isNull);
      });

      test('accepts an issuer location with a port and a path', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': _issuerRel, 'href': 'https://server.example.com:8443/op'},
            ],
          ),
        );
        expect(
          resp.getIssuer(),
          Uri.parse('https://server.example.com:8443/op'),
        );
      });

      test('returns null when no link carries the requested rel', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {
                'rel': 'http://webfinger.example/rel/profile-page',
                'href': 'https://www.example.com/~bob/',
              },
            ],
          ),
        );
        expect(resp.getIssuer(), isNull);
      });

      test('honours a custom rel', () {
        final resp = OidcWebFingerResponse.fromJson(
          _jrd(
            links: [
              {'rel': 'urn:custom:rel', 'href': 'https://custom.example.com'},
            ],
          ),
        );
        expect(
          resp.getIssuer(rel: 'urn:custom:rel'),
          Uri.parse('https://custom.example.com'),
        );
        expect(resp.getIssuer(), isNull);
      });
    });

    test('isValidIssuerLocation encodes the §2 Issuer-location rule', () {
      expect(
        OidcWebFingerLink.isValidIssuerLocation(
          Uri.parse('https://server.example.com'),
        ),
        isTrue,
      );
      expect(OidcWebFingerLink.isValidIssuerLocation(null), isFalse);
      expect(
        OidcWebFingerLink.isValidIssuerLocation(
          Uri.parse('http://server.example.com'),
        ),
        isFalse,
      );
    });
  });

  group('OidcEndpoints.webFinger', () {
    test('performs a GET and parses the JRD', () async {
      late http.BaseRequest captured;
      final client = MockClient((req) async {
        captured = req;
        return _jsonResponse(_jrd());
      });

      final resp = await OidcEndpoints.webFinger(
        OidcUtils.getWebFingerUri(
          host: 'example.com',
          resource: 'acct:joe@example.com',
        ),
        client: client,
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/.well-known/webfinger');
      expect(
        captured.url.queryParameters['resource'],
        'acct:joe@example.com',
      );
      expect(resp.subject, 'acct:joe@example.com');
      expect(resp.getIssuer(), Uri.parse('https://server.example.com'));
    });

    test('sends an Accept header advertising the JRD media type', () async {
      late http.BaseRequest captured;
      final client = MockClient((req) async {
        captured = req;
        return _jsonResponse(_jrd());
      });

      await OidcEndpoints.webFinger(
        Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
        client: client,
      );

      expect(
        captured.headers['Accept'] ?? captured.headers['accept'],
        contains(OidcConstants_WebFinger.jrdContentType),
      );
    });

    test('a caller-supplied Accept header wins', () async {
      late http.BaseRequest captured;
      final client = MockClient((req) async {
        captured = req;
        return _jsonResponse(_jrd());
      });

      await OidcEndpoints.webFinger(
        Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
        headers: const {'Accept': 'application/json'},
        client: client,
      );

      expect(
        captured.headers['Accept'] ?? captured.headers['accept'],
        'application/json',
      );
    });

    test('rejects a non-https WebFinger URI before any request', () async {
      // RFC 7033 §4.2/§9.1: clients MUST NOT issue queries over a non-secure
      // connection.
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return _jsonResponse(_jrd());
      });

      await expectLater(
        OidcEndpoints.webFinger(
          Uri.parse('http://example.com/.well-known/webfinger?resource=x'),
          client: client,
        ),
        throwsA(isA<OidcException>()),
      );
      expect(called, isFalse, reason: 'no request may leave the client');
    });

    test('does not delegate redirect following to the http client', () async {
      late http.BaseRequest captured;
      final client = MockClient((req) async {
        captured = req;
        return _jsonResponse(_jrd());
      });

      await OidcEndpoints.webFinger(
        Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
        client: client,
      );

      expect((captured as http.Request).followRedirects, isFalse);
    });

    test('a non-JSON body surfaces as an OidcException', () async {
      final client = MockClient(
        (req) async => http.Response('<html>nope</html>', 200),
      );
      await expectLater(
        OidcEndpoints.webFinger(
          Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
          client: client,
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('a 404 surfaces as an OidcException', () async {
      final client = MockClient(
        (req) async => _jsonResponse({}, statusCode: 404),
      );
      await expectLater(
        OidcEndpoints.webFinger(
          Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
          client: client,
        ),
        throwsA(isA<OidcException>()),
      );
    });

    group('redirects (RFC 7033 §4.2)', () {
      test('follows an https redirect and parses the final JRD', () async {
        final visited = <Uri>[];
        final client = MockClient((req) async {
          visited.add(req.url);
          if (req.url.host == 'example.com') {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://webfinger.example.com/.well-known/webfinger'
                    '?resource=acct%3Ajoe%40example.com',
              },
            );
          }
          return _jsonResponse(_jrd());
        });

        final resp = await OidcEndpoints.webFinger(
          Uri.parse(
            'https://example.com/.well-known/webfinger'
            '?resource=acct%3Ajoe%40example.com',
          ),
          client: client,
        );

        expect(visited.map((e) => e.host), [
          'example.com',
          'webfinger.example.com',
        ]);
        expect(resp.getIssuer(), Uri.parse('https://server.example.com'));
      });

      test('resolves a relative Location against the current hop', () async {
        final visited = <Uri>[];
        final client = MockClient((req) async {
          visited.add(req.url);
          if (req.url.path == '/.well-known/webfinger') {
            return http.Response('', 301, headers: {'location': '/moved'});
          }
          return _jsonResponse(_jrd());
        });

        await OidcEndpoints.webFinger(
          Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
          client: client,
        );

        expect(visited.last, Uri.parse('https://example.com/moved'));
      });

      for (final status in const [301, 302, 303, 307, 308]) {
        test('a $status redirect to http:// is refused', () async {
          final client = MockClient((req) async {
            if (req.url.scheme == 'https') {
              return http.Response(
                '',
                status,
                headers: {
                  'location':
                      'http://insecure.example.com/.well-known/webfinger',
                },
              );
            }
            return _jsonResponse(_jrd());
          });

          await expectLater(
            OidcEndpoints.webFinger(
              Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
              client: client,
            ),
            throwsA(isA<OidcException>()),
          );
        });
      }

      test('a redirect loop is capped and throws', () async {
        var hops = 0;
        final client = MockClient((req) async {
          hops++;
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://example.com/hop$hops',
            },
          );
        });

        await expectLater(
          OidcEndpoints.webFinger(
            Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
            client: client,
          ),
          throwsA(isA<OidcException>()),
        );
        // The cap must actually bound the work, not spin forever.
        expect(hops, lessThanOrEqualTo(6));
      });

      test(
        'a 3xx without a Location header is not treated as success',
        () async {
          final client = MockClient((req) async => http.Response('', 302));
          await expectLater(
            OidcEndpoints.webFinger(
              Uri.parse('https://example.com/.well-known/webfinger?resource=x'),
              client: client,
            ),
            throwsA(isA<OidcException>()),
          );
        },
      );
    });
  });

  group('OidcEndpoints.getIssuerViaWebFinger', () {
    test(
      'normalizes, queries the derived host, and returns the issuer',
      () async {
        late Uri requested;
        final client = MockClient((req) async {
          requested = req.url;
          return _jsonResponse(_jrd());
        });

        final issuer = await OidcEndpoints.getIssuerViaWebFinger(
          'joe@example.com',
          client: client,
        );

        expect(requested.scheme, 'https');
        expect(requested.host, 'example.com');
        expect(requested.path, '/.well-known/webfinger');
        expect(requested.queryParameters['resource'], 'acct:joe@example.com');
        expect(requested.queryParameters['rel'], _issuerRel);
        expect(issuer, Uri.parse('https://server.example.com'));
      },
    );

    test('a §2.2.3 host:port identifier queries that authority', () async {
      late Uri requested;
      final client = MockClient((req) async {
        requested = req.url;
        return _jsonResponse(_jrd(subject: 'https://example.com:8080/'));
      });

      await OidcEndpoints.getIssuerViaWebFinger(
        'example.com:8080',
        client: client,
      );

      expect(requested.host, 'example.com');
      expect(requested.port, 8080);
      expect(
        requested.queryParameters['resource'],
        'https://example.com:8080/',
      );
    });

    test(
      'filters by rel client-side when the server ignored the parameter',
      () async {
        final client = MockClient(
          (req) async => _jsonResponse(
            _jrd(
              links: [
                {
                  'rel': 'http://webfinger.example/rel/profile-page',
                  'href': 'https://www.example.com/~joe/',
                },
                {'rel': _issuerRel, 'href': 'https://server.example.com'},
              ],
            ),
          ),
        );

        expect(
          await OidcEndpoints.getIssuerViaWebFinger(
            'joe@example.com',
            client: client,
          ),
          Uri.parse('https://server.example.com'),
        );
      },
    );

    test('throws when the JRD carries no issuer link', () async {
      final client = MockClient(
        (req) async => _jsonResponse(
          _jrd(
            links: [
              {
                'rel': 'http://webfinger.example/rel/profile-page',
                'href': 'https://www.example.com/~joe/',
              },
            ],
          ),
        ),
      );

      await expectLater(
        OidcEndpoints.getIssuerViaWebFinger('joe@example.com', client: client),
        throwsA(
          isA<OidcException>().having(
            (e) => e.message,
            'message',
            // Not `contains('example.com')`: that is a substring of the
            // resource clause above and pins nothing of its own. The rel is
            // what the message must name, so the reader learns which link the
            // lookup wanted.
            allOf(contains('acct:joe@example.com'), contains(_issuerRel)),
          ),
        ),
      );
    });

    test(
      'throws when the only issuer link is not a valid Issuer location',
      () async {
        final client = MockClient(
          (req) async => _jsonResponse(
            _jrd(
              links: [
                {'rel': _issuerRel, 'href': 'http://server.example.com'},
              ],
            ),
          ),
        );

        await expectLater(
          OidcEndpoints.getIssuerViaWebFinger(
            'joe@example.com',
            client: client,
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test(
      'propagates a normalization failure without any network call',
      () async {
        var called = false;
        final client = MockClient((req) async {
          called = true;
          return _jsonResponse(_jrd());
        });

        await expectLater(
          OidcEndpoints.getIssuerViaWebFinger('=joe', client: client),
          throwsA(isA<OidcException>()),
        );
        expect(called, isFalse);
      },
    );

    test('honours a custom rel end-to-end', () async {
      late Uri requested;
      final client = MockClient((req) async {
        requested = req.url;
        return _jsonResponse(
          _jrd(
            links: [
              {'rel': 'urn:custom:rel', 'href': 'https://custom.example.com'},
            ],
          ),
        );
      });

      final issuer = await OidcEndpoints.getIssuerViaWebFinger(
        'joe@example.com',
        rel: 'urn:custom:rel',
        client: client,
      );

      expect(requested.queryParameters['rel'], 'urn:custom:rel');
      expect(issuer, Uri.parse('https://custom.example.com'));
    });

    test('a differing subject is accepted, not validated', () async {
      // RFC 7033 §4.4.1: subject MAY differ from the request resource.
      final client = MockClient(
        (req) async => _jsonResponse(_jrd(subject: 'acct:someoneelse@other')),
      );

      expect(
        await OidcEndpoints.getIssuerViaWebFinger(
          'joe@example.com',
          client: client,
        ),
        Uri.parse('https://server.example.com'),
      );
    });
  });
}
