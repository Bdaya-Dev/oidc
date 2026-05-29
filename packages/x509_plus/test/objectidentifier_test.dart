import 'package:test/test.dart';
import 'package:x509_plus/x509.dart';

void main() {
  group('name', () {
    test('return correct name', () {
      var oid = ObjectIdentifier([2, 5, 4, 3]);
      expect(oid.name, 'commonName');
    });

    test('throw UnknownOIDNameError when unknown oid', () {
      var oid = ObjectIdentifier([1, 2, 3, 4, 5, 6]);
      expect(() => oid.name, throwsA(TypeMatcher<UnknownOIDNameError>()));
    });
  });
}