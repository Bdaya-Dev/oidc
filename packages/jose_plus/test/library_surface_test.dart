// Ensures the package-name-matching entrypoint (`jose_plus.dart`) is
// actually loaded by the test suite, so its re-exported surface stays
// visible to coverage tooling even though the rest of the suite only ever
// imports the legacy `jose.dart` entrypoint.
import 'package:jose_plus/jose_plus.dart';
import 'package:test/test.dart';

void main() {
  group('jose_plus library surface', () {
    test(
      'JsonWebAlgorithm.getByName resolves RS256 to its RFC 7518 metadata',
      () {
        final alg = JsonWebAlgorithm.getByName('RS256');
        expect(alg.type, 'RSA');
        expect(alg.use, 'sig');
        expect(alg.minKeyBitLength, 2048);
      },
    );

    test('JsonWebAlgorithm.getByName throws for an unsupported name', () {
      expect(
        () => JsonWebAlgorithm.getByName('not-a-real-alg'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
