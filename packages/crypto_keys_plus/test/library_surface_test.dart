// Ensures the package-name-matching entrypoint (`crypto_keys_plus.dart`) is
// actually loaded by the test suite, so its re-exported surface stays
// visible to coverage tooling even though the rest of the suite only ever
// imports the legacy `crypto_keys.dart` entrypoint.
import 'package:crypto_keys_plus/crypto_keys_plus.dart';
import 'package:test/test.dart';

void main() {
  group('crypto_keys_plus library surface', () {
    test(
      'algorithms exposes the documented digest identifiers',
      () {
        // `algorithms` is the top-level singleton re-exported from
        // `crypto_keys.dart` via the package-name-matching barrel. Its
        // identifier names are part of the documented public contract.
        expect(algorithms.digest.sha256.name, 'digest/SHA-256');
        expect(algorithms.digest.sha512.name, 'digest/SHA-512');
      },
    );

    test('curves exposes the documented P-256 curve identifier', () {
      expect(curves.p256.name, 'curve/P-256');
    });
  });
}
