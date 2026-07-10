// Ensures the package-name-matching entrypoint (`x509_plus.dart`) is
// actually loaded by the test suite, so its re-exported surface stays
// visible to coverage tooling even though the rest of the suite only ever
// imports the legacy `x509.dart` entrypoint.
import 'package:test/test.dart';
import 'package:x509_plus/x509_plus.dart';

void main() {
  group('x509_plus library surface', () {
    test('ObjectIdentifier.parent drops the last arc (RFC-defined OID tree)',
        () {
      // 1.2.840.113549.1 (pkcs) is a well-known OID; its parent must be
      // 1.2.840.113549 (rsadsi), per the OID tree structure documented on
      // `ObjectIdentifier.parent`.
      const oid = ObjectIdentifier([1, 2, 840, 113549, 1]);
      expect(oid.parent, const ObjectIdentifier([1, 2, 840, 113549]));
    });

    test('ObjectIdentifier with a single arc has no parent', () {
      const oid = ObjectIdentifier([1]);
      expect(oid.parent, isNull);
    });
  });
}
