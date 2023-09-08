// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

void main() {
  group('OidcDefaultStore', () {
    test('can be instantiated', () {
      expect(OidcDefaultStore(), isNotNull);
    });
  });
}
