@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

String _unsignedJwt(Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(
            JsonWebKey.generate('HS256'),
            algorithm: 'HS256',
          ))
        .build()
        .toCompactSerialization();

void main() {
  group('OidcEndpoints.userInfoFollowDistributedClaims', () {
    test(
      'returns the response untouched when there are no claim names',
      () async {
        final response = OidcUserInfoResponse.fromJson({'sub': 'u1'});
        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
        );
        expect(identical(result, response), isTrue);
      },
    );

    test(
      'returns untouched when claim names reference missing sources',
      () async {
        final response = OidcUserInfoResponse.fromJson({
          'sub': 'u1',
          '_claim_names': {'address': 'src-1'},
          // no src-1 in _claim_sources
          '_claim_sources': <String, dynamic>{},
        });
        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
        );
        expect(identical(result, response), isTrue);
      },
    );

    test('resolves an aggregated claim source (embedded JWT)', () async {
      final aggregatedJwt = _unsignedJwt({
        'address': {'country': 'DE'},
        'unrelated': 'ignored',
      });
      final response = OidcUserInfoResponse.fromJson({
        'sub': 'u1',
        '_claim_names': {'address': 'src-1'},
        '_claim_sources': {
          'src-1': {'JWT': aggregatedJwt},
        },
      });

      final result = await OidcEndpoints.userInfoFollowDistributedClaims(
        response: response,
      );
      expect(result.src['address'], {'country': 'DE'});
      // only the referenced claim is merged, not the aggregate's other claims
      expect(result.src.containsKey('unrelated'), isFalse);
      // base claims are preserved
      expect(result.sub, 'u1');
    });

    test(
      'resolves a distributed claim source over http (Bearer token)',
      () async {
        final distributedJwt = _unsignedJwt({
          'payment_info': 'gold',
          'ignored': true,
        });
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(distributedJwt, 200);
        });

        final response = OidcUserInfoResponse.fromJson({
          'sub': 'u1',
          '_claim_names': {'payment_info': 'src-2'},
          '_claim_sources': {
            'src-2': {
              'endpoint': 'https://claims.example.com/payment',
              'access_token': 'dist-token',
            },
          },
        });

        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
          client: client,
        );
        expect(result.src['payment_info'], 'gold');
        expect(result.src.containsKey('ignored'), isFalse);
        expect(captured.url, Uri.parse('https://claims.example.com/payment'));
        expect(captured.headers['Authorization'], 'Bearer dist-token');
      },
    );

    test(
      'uses getAccessTokenFor when the distributed source has no token',
      () async {
        final distributedJwt = _unsignedJwt({'payment_info': 'silver'});
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(distributedJwt, 200);
        });

        String? requestedSource;
        Uri? requestedEndpoint;

        final response = OidcUserInfoResponse.fromJson({
          'sub': 'u1',
          '_claim_names': {'payment_info': 'src-3'},
          '_claim_sources': {
            'src-3': {'endpoint': 'https://claims.example.com/p'},
          },
        });

        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
          client: client,
          getAccessTokenFor: (source, endpoint) async {
            requestedSource = source;
            requestedEndpoint = endpoint;
            return 'fetched-token';
          },
        );

        expect(result.src['payment_info'], 'silver');
        expect(requestedSource, 'src-3');
        expect(requestedEndpoint, Uri.parse('https://claims.example.com/p'));
        expect(captured.headers['Authorization'], 'Bearer fetched-token');
      },
    );

    test(
      'a distributed endpoint returning a non-2xx status is skipped',
      () async {
        final client = MockClient((request) async {
          return http.Response('nope', 403);
        });
        final response = OidcUserInfoResponse.fromJson({
          'sub': 'u1',
          '_claim_names': {'payment_info': 'src-4'},
          '_claim_sources': {
            'src-4': {'endpoint': 'https://claims.example.com/p'},
          },
        });

        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
          client: client,
        );
        // The claim could not be resolved, so it is not added.
        expect(result.src.containsKey('payment_info'), isFalse);
        expect(result.sub, 'u1');
      },
    );

    test(
      'a distributed endpoint returning a non-JWT body resolves no claim',
      () async {
        final client = MockClient((request) async {
          return http.Response('not-a-jwt', 200);
        });
        final response = OidcUserInfoResponse.fromJson({
          'sub': 'u1',
          '_claim_names': {'payment_info': 'src-5'},
          '_claim_sources': {
            'src-5': {'endpoint': 'https://claims.example.com/p'},
          },
        });

        final result = await OidcEndpoints.userInfoFollowDistributedClaims(
          response: response,
          client: client,
        );
        expect(result.src.containsKey('payment_info'), isFalse);
      },
    );

    test('merges claims from multiple sources at once', () async {
      final aggregatedJwt = _unsignedJwt({'address': 'Berlin'});
      final distributedJwt = _unsignedJwt({'balance': 100});
      final client = MockClient((request) async {
        return http.Response(distributedJwt, 200);
      });

      final response = OidcUserInfoResponse.fromJson({
        'sub': 'u1',
        '_claim_names': {'address': 'agg', 'balance': 'dist'},
        '_claim_sources': {
          'agg': {'JWT': aggregatedJwt},
          'dist': {
            'endpoint': 'https://claims.example.com/b',
            'access_token': 't',
          },
        },
      });

      final result = await OidcEndpoints.userInfoFollowDistributedClaims(
        response: response,
        client: client,
      );
      expect(result.src['address'], 'Berlin');
      expect(result.src['balance'], 100);
    });
  });
}
