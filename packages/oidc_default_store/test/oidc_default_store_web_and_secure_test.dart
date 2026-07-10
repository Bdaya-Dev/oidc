// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:oidc_default_store/src/html_stub.dart' as html_stub;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcDefaultStore web branches (testIsWeb = true)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    for (final webSessionManagementLocation
        in OidcDefaultStoreWebSessionManagementLocation.values) {
      testWidgets(
          'exercises the html.window based storage paths for '
          '$webSessionManagementLocation', (tester) async {
        final store = OidcDefaultStore(
          webSessionManagementLocation: webSessionManagementLocation,
        )..testIsWeb = true;
        await store.init();

        const goldenValues = {'k1': 'v1', 'k2': 'v2'};

        for (final namespace in OidcStoreNamespace.values) {
          var allKeys = await store.getAllKeys(namespace);
          expect(allKeys, isEmpty);

          await store.setMany(namespace, values: goldenValues);
          allKeys = await store.getAllKeys(namespace);
          expect(allKeys, goldenValues.keys);

          final allValues =
              await store.getMany(namespace, keys: {...allKeys, 'missing'});
          expect(allValues, allOf(hasLength(2), equals(goldenValues)));

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

          await store.removeMany(namespace, keys: allKeys);
          final afterRemove = await store.getMany(namespace, keys: allKeys);
          expect(afterRemove, isEmpty);
        }
      });
    }

    testWidgets(
        'session namespace on web with sessionStorage location does not leak '
        'into localStorage', (tester) async {
      final store = OidcDefaultStore()..testIsWeb = true;
      await store.init();

      await store.set(
        OidcStoreNamespace.session,
        key: 'sessionKey',
        value: 'sessionValue',
      );

      // it must be readable back through the store.
      expect(
        await store.get(OidcStoreNamespace.session, key: 'sessionKey'),
        'sessionValue',
      );
    });
  });

  group('OidcDefaultStore secureTokens namespace with a real secure storage',
      () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    testWidgets(
        'routes secureTokens through FlutterSecureStorage, not through '
        'SharedPreferences', (tester) async {
      const secureStorage = FlutterSecureStorage();
      final store = OidcDefaultStore(secureStorageInstance: secureStorage);
      await store.init();

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'access_token': 'secret-value'},
      );

      // readable through the secure storage instance directly.
      expect(
        await secureStorage.read(key: 'oidc.secureTokens.access_token'),
        'secret-value',
      );

      // readable through the store's getMany/get.
      expect(
        await store.get(
          OidcStoreNamespace.secureTokens,
          key: 'access_token',
        ),
        'secret-value',
      );

      // must NOT have leaked into SharedPreferences in plaintext.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('oidc.secureTokens.access_token'), isNull);

      // removeMany must delete it from the secure storage backend.
      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: {'access_token'},
      );
      expect(
        await secureStorage.read(key: 'oidc.secureTokens.access_token'),
        isNull,
      );
      expect(
        await store.get(OidcStoreNamespace.secureTokens, key: 'access_token'),
        isNull,
      );
    });

    testWidgets(
        'secureTokens keys are still tracked in the namespace key index',
        (tester) async {
      const secureStorage = FlutterSecureStorage();
      final store = OidcDefaultStore(secureStorageInstance: secureStorage);
      await store.init();

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'id_token': 'idval', 'refresh_token': 'refval'},
      );

      final keys = await store.getAllKeys(OidcStoreNamespace.secureTokens);
      expect(keys, containsAll(<String>['id_token', 'refresh_token']));

      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: {'id_token'},
      );
      final keysAfter = await store.getAllKeys(OidcStoreNamespace.secureTokens);
      expect(keysAfter, {'refresh_token'});
    });
  });

  group('OidcDefaultStore namespace/managerId isolation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'the same key in different namespaces does not clash, and clearing '
        'one namespace does not affect another', (tester) async {
      final store = OidcDefaultStore();
      await store.init();

      await store.set(
        OidcStoreNamespace.state,
        key: 'shared',
        value: 'state-value',
      );
      await store.set(
        OidcStoreNamespace.request,
        key: 'shared',
        value: 'request-value',
      );

      expect(
        await store.get(OidcStoreNamespace.state, key: 'shared'),
        'state-value',
      );
      expect(
        await store.get(OidcStoreNamespace.request, key: 'shared'),
        'request-value',
      );

      // removing from `state` must not affect `request`.
      await store.remove(OidcStoreNamespace.state, key: 'shared');
      expect(
        await store.get(OidcStoreNamespace.state, key: 'shared'),
        isNull,
      );
      expect(
        await store.get(OidcStoreNamespace.request, key: 'shared'),
        'request-value',
      );
    });

    testWidgets('different managerIds keep fully isolated data and key indexes',
        (tester) async {
      final store = OidcDefaultStore();
      await store.init();
      const ns = OidcStoreNamespace.discoveryDocument;

      await store.setMany(
        ns,
        values: {'doc': 'manager-A-doc'},
        managerId: 'managerA',
      );
      await store.setMany(
        ns,
        values: {'doc': 'manager-B-doc'},
        managerId: 'managerB',
      );

      expect(
        await store.get(ns, key: 'doc', managerId: 'managerA'),
        'manager-A-doc',
      );
      expect(
        await store.get(ns, key: 'doc', managerId: 'managerB'),
        'manager-B-doc',
      );

      final keysA = await store.getAllKeys(ns, managerId: 'managerA');
      final keysB = await store.getAllKeys(ns, managerId: 'managerB');
      expect(keysA, {'doc'});
      expect(keysB, {'doc'});

      // removing managerA's key must not touch managerB's data or index.
      await store.removeMany(ns, keys: {'doc'}, managerId: 'managerA');
      expect(await store.getAllKeys(ns, managerId: 'managerA'), isEmpty);
      expect(await store.getAllKeys(ns, managerId: 'managerB'), {'doc'});
      expect(
        await store.get(ns, key: 'doc', managerId: 'managerB'),
        'manager-B-doc',
      );
    });

    testWidgets(
        'removeMany only removes the requested keys from the index, leaving '
        'the rest intact', (tester) async {
      final store = OidcDefaultStore();
      await store.init();
      const ns = OidcStoreNamespace.stateResponse;

      await store.setMany(
        ns,
        values: {'a': '1', 'b': '2', 'c': '3'},
      );
      await store.removeMany(ns, keys: {'b'});

      final remainingKeys = await store.getAllKeys(ns);
      expect(remainingKeys, {'a', 'c'});

      final remainingValues = await store.getMany(ns, keys: remainingKeys);
      expect(remainingValues, {'a': '1', 'c': '3'});
    });
  });

  group('html_stub.dart (non-web conditional-import shim)', () {
    test('initWeb is a no-op that does not throw', () {
      expect(html_stub.initWeb, returnsNormally);
    });

    test('Storage get/set/remove round-trips values in memory', () {
      final storage = html_stub.Storage();
      expect(storage.getItem('missing'), isNull);

      storage.setItem('key1', 'value1');
      expect(storage.getItem('key1'), 'value1');

      // overwriting an existing key updates the value.
      storage.setItem('key1', 'value2');
      expect(storage.getItem('key1'), 'value2');

      storage.removeItem('key1');
      expect(storage.getItem('key1'), isNull);

      // removing a non-existent key must not throw.
      expect(() => storage.removeItem('never-set'), returnsNormally);
    });

    test('Window exposes independent localStorage and sessionStorage', () {
      final window = html_stub.Window();
      window.localStorage.setItem('a', '1');
      window.sessionStorage.setItem('a', '2');

      // local and session storage must be independent instances.
      expect(window.localStorage.getItem('a'), '1');
      expect(window.sessionStorage.getItem('a'), '2');
    });

    test('module-level window instance persists across accesses', () {
      html_stub.window.localStorage.setItem('persisted', 'yes');
      expect(html_stub.window.localStorage.getItem('persisted'), 'yes');
    });
  });
}
