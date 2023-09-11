// ignore_for_file: prefer_const_constructors

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OidcDefaultStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });
    test('can be instantiated', () {
      expect(OidcDefaultStore(), isNotNull);
    });

    final storeConfigs = [
      OidcDefaultStore(),
      OidcDefaultStore()..testIsWeb = true,
      OidcDefaultStore(
        webSessionManagementLocation:
            OidcDefaultStoreWebSessionManagementLocation.localStorage,
      )..testIsWeb = true,
    ];
    for (final store in storeConfigs) {
      testWidgets('Full test', (widgetTester) async {
        // final store = OidcDefaultStore();

        expect(store.didInit, false);
        await store.init();
        expect(store.didInit, true);
        const goldenValues = {
          'k1': 'v1',
          'k2': 'v2',
        };
        for (final namespace in OidcStoreNamespace.values) {
          var allKeys = await store.getAllKeys(namespace);
          expect(allKeys, isEmpty);

          await store.setMany(
            namespace,
            values: goldenValues,
          );
          allKeys = await store.getAllKeys(namespace);
          expect(allKeys, goldenValues.keys);

          var allValues =
              await store.getMany(namespace, keys: {...allKeys, 'k3'});
          expect(allValues, allOf(hasLength(2), equals(goldenValues)));

          //test single entry methods.
          await expectLater(
            store.set(namespace, key: 'k1', value: 'nnv1'),
            completes,
          );
          await expectLater(
            store.get(namespace, key: 'k1'),
            completion('nnv1'),
          );
          await expectLater(store.remove(namespace, key: 'k1'), completes);
          await expectLater(store.get(namespace, key: 'k1'), completion(null));
          //test remove many.
          await store.removeMany(namespace, keys: allKeys);
          allValues = await store.getMany(namespace, keys: allKeys);
          expect(allValues, isEmpty);
        }
      });
    }
  });
}
