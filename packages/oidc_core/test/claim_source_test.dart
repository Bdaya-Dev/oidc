import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcClaimSource.fromJson dispatch', () {
    test('a JWT member produces an aggregated claim source', () {
      final source = OidcClaimSource.fromJson({
        'JWT': 'eyJ.header.sig',
      });
      expect(source, isA<OidcAggregatedClaimSource>());
      expect((source as OidcAggregatedClaimSource).jwt, 'eyJ.header.sig');
      expect(source.src, {'JWT': 'eyJ.header.sig'});
    });

    test('an endpoint member produces a distributed claim source', () {
      final source = OidcClaimSource.fromJson({
        'endpoint': 'https://claims.example.com/source',
        'access_token': 'at-123',
      });
      expect(source, isA<OidcDistributedClaimSource>());
      final distributed = source as OidcDistributedClaimSource;
      expect(
        distributed.endpoint,
        Uri.parse('https://claims.example.com/source'),
      );
      expect(distributed.accessToken, 'at-123');
    });

    test('a distributed source without an access token parses', () {
      final source = OidcClaimSource.fromJson({
        'endpoint': 'https://claims.example.com/source',
      });
      expect(source, isA<OidcDistributedClaimSource>());
      expect((source as OidcDistributedClaimSource).accessToken, isNull);
    });

    test('a JWT source is preferred when both members are present', () {
      final source = OidcClaimSource.fromJson({
        'JWT': 'the-jwt',
        'endpoint': 'https://claims.example.com/source',
      });
      expect(source, isA<OidcAggregatedClaimSource>());
    });

    test('a source with neither member throws ArgumentError', () {
      expect(
        () => OidcClaimSource.fromJson({'foo': 'bar'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('OidcAggregatedClaimSource.fromJson decodes directly', () {
      final agg = OidcAggregatedClaimSource.fromJson({'JWT': 'abc'});
      expect(agg.jwt, 'abc');
    });

    test('OidcDistributedClaimSource.fromJson decodes directly', () {
      final dist = OidcDistributedClaimSource.fromJson({
        'endpoint': 'https://e.example.com',
        'access_token': 'tok',
      });
      expect(dist.endpoint, Uri.parse('https://e.example.com'));
      expect(dist.accessToken, 'tok');
    });
  });
}
