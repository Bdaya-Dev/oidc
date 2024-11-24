@TestOn('js')
library;

// ignore_for_file: prefer_const_constructors

import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcWebCore', () {
    test('can be instantiated', () {
      expect(OidcWebCore(), isNotNull);
    });
  });
}
