import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

// The rest of this package's suite constructs `OidcDefaultStore` with
// explicit overrides (or exercises behavior through `init`/`setMany`/etc.),
// but never asserts the documented DEFAULT values of `storagePrefix` or
// `recommendedAndroidOptions` directly. Both are part of the public,
// doc-commented contract of the barrel this test imports.
void main() {
  group('oidc_default_store library surface', () {
    test(
      "storagePrefix defaults to 'oidc' when not overridden",
      () {
        final store = OidcDefaultStore();
        expect(store.storagePrefix, 'oidc');
      },
    );

    test(
      'recommendedAndroidOptions is the flutter_secure_storage v10 default '
      '(no deprecated encryptedSharedPreferences)',
      () {
        expect(
          OidcDefaultStore.recommendedAndroidOptions,
          AndroidOptions.defaultOptions,
        );
      },
    );
  });
}
