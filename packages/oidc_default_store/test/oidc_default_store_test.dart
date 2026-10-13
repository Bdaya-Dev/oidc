// ignore_for_file: prefer_const_constructors

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:universal_html/html.dart' as html;

const _migrationMarkerKey = 'oidc.__oidc_async_migration_done';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// A legacy in-memory store that counts every write, so a test can prove that
/// the migration only reads the legacy store.
class _RecordingLegacyStore extends InMemorySharedPreferencesStore {
  _RecordingLegacyStore.withData(super.data) : super.withData();

  int writes = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writes++;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes++;
    return super.remove(key);
  }

  @override
  Future<bool> clear() {
    writes++;
    return super.clear();
  }

  @override
  Future<bool> clearWithPrefix(String prefix) {
    writes++;
    return super.clearWithPrefix(prefix);
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) {
    writes++;
    return super.clearWithParameters(parameters);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    html.window.sessionStorage.clear();
    html.window.localStorage.clear();
  });

  group('OidcDefaultStore', () {
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

    testWidgets('concurrent init calls share one initialization', (
      tester,
    ) async {
      final store = OidcDefaultStore();

      await Future.wait([store.init(), store.init()]);

      expect(store.didInit, isTrue);
      await store.set(OidcStoreNamespace.state, key: 'k1', value: 'v1');
      expect(await store.get(OidcStoreNamespace.state, key: 'k1'), 'v1');
    });
  });

  group('OidcDefaultStore SharedPreferencesAsync backend', () {
    final namespaces = OidcStoreNamespace.values.where(
      (ns) => ns != OidcStoreNamespace.secureTokens,
    );
    for (final namespace in namespaces) {
      testWidgets(
          'stores ${namespace.value} values and the key list in '
          'SharedPreferencesAsync, not in the legacy store', (tester) async {
        final store = OidcDefaultStore();
        await store.init();

        await store.setMany(namespace, values: {'k1': 'v1', 'k2': 'v2'});

        final async = SharedPreferencesAsync();
        expect(await async.getString('oidc.${namespace.value}.k1'), 'v1');
        expect(await async.getString('oidc.${namespace.value}.k2'), 'v2');
        expect(
          await async.getStringList('oidc.keys.${namespace.value}'),
          unorderedEquals(<String>['k1', 'k2']),
        );
        final legacy = await SharedPreferences.getInstance();
        expect(legacy.getKeys(), isEmpty);

        await store.removeMany(namespace, keys: {'k1'});
        expect(await async.getString('oidc.${namespace.value}.k1'), isNull);
        expect(await async.getString('oidc.${namespace.value}.k2'), 'v2');
        expect(await async.getStringList('oidc.keys.${namespace.value}'), [
          'k2',
        ]);
      });
    }

    testWidgets('init keeps an injected SharedPreferencesAsync', (
      tester,
    ) async {
      final injected = SharedPreferencesAsync();
      final store = OidcDefaultStore(sharedPreferencesAsync: injected);
      await store.init();

      await store.set(
        OidcStoreNamespace.discoveryDocument,
        key: 'doc',
        value: 'discovery',
      );

      expect(
        await injected.getString('oidc.discoveryDocument.doc'),
        'discovery',
      );
      expect(
        await store.get(OidcStoreNamespace.discoveryDocument, key: 'doc'),
        'discovery',
      );

      await store.remove(OidcStoreNamespace.discoveryDocument, key: 'doc');
      expect(await injected.getString('oidc.discoveryDocument.doc'), isNull);
    });
  });

  group('OidcDefaultStore secureTokens namespace', () {
    testWidgets('uses the secure storage, not SharedPreferencesAsync', (
      tester,
    ) async {
      const secureStorage = FlutterSecureStorage();
      final store = OidcDefaultStore(secureStorageInstance: secureStorage);
      await store.init();

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'access_token': 'secret-value'},
      );

      expect(
        await secureStorage.read(key: 'oidc.secureTokens.access_token'),
        'secret-value',
      );
      expect(
        await store.get(OidcStoreNamespace.secureTokens, key: 'access_token'),
        'secret-value',
      );
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.secureTokens.access_token'), isNull);
      expect(await async.getStringList('oidc.keys.secureTokens'), [
        'access_token',
      ]);

      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: {'access_token'},
      );
      expect(
        await secureStorage.read(key: 'oidc.secureTokens.access_token'),
        isNull,
      );
    });

    testWidgets(
      'falls back to SharedPreferencesAsync when the secure storage throws',
      (tester) async {
        final secureStorage = _MockSecureStorage();
        final error = Exception('secure storage is not available');
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(error);
        when(() => secureStorage.read(key: any(named: 'key'))).thenThrow(error);
        when(
          () => secureStorage.delete(key: any(named: 'key')),
        ).thenThrow(error);
        final store = OidcDefaultStore(secureStorageInstance: secureStorage);
        await store.init();

        await store.setMany(
          OidcStoreNamespace.secureTokens,
          values: {'access_token': 'fallback-value'},
        );

        final async = SharedPreferencesAsync();
        expect(
          await async.getString('oidc.secureTokens.access_token'),
          'fallback-value',
        );
        expect(
          await store.get(OidcStoreNamespace.secureTokens, key: 'access_token'),
          'fallback-value',
        );

        await store.removeMany(
          OidcStoreNamespace.secureTokens,
          keys: {'access_token'},
        );
        expect(await async.getString('oidc.secureTokens.access_token'), isNull);
      },
    );
  });

  group('OidcDefaultStore web branches (testIsWeb = true)', () {
    testWidgets('session values go to sessionStorage', (tester) async {
      final store = OidcDefaultStore()..testIsWeb = true;
      await store.init();

      await store.set(OidcStoreNamespace.session, key: 'k1', value: 'v1');

      expect(html.window.sessionStorage['oidc.session.k1'], 'v1');
      expect(html.window.localStorage['oidc.session.k1'], isNull);
      expect(html.window.localStorage['oidc.keys.session'], '["k1"]');
      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
    });

    testWidgets('session values go to localStorage when configured', (
      tester,
    ) async {
      final store = OidcDefaultStore(
        webSessionManagementLocation:
            OidcDefaultStoreWebSessionManagementLocation.localStorage,
      )..testIsWeb = true;
      await store.init();

      await store.set(OidcStoreNamespace.session, key: 'k1', value: 'v1');

      expect(html.window.localStorage['oidc.session.k1'], 'v1');
      expect(html.window.sessionStorage['oidc.session.k1'], isNull);
      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
    });

    testWidgets('state values go to localStorage', (tester) async {
      final store = OidcDefaultStore()..testIsWeb = true;
      await store.init();

      await store.set(OidcStoreNamespace.state, key: 'k1', value: 'v1');

      expect(html.window.localStorage['oidc.state.k1'], 'v1');
      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
    });

    testWidgets('init does not migrate the legacy store', (tester) async {
      SharedPreferences.setMockInitialValues({'oidc.state.k1': 'legacy'});
      final store = OidcDefaultStore()..testIsWeb = true;
      await store.init();

      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
    });
  });

  group('OidcDefaultStore legacy to async migration', () {
    testWidgets('copies the legacy values under the storage prefix', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'oidc.keys.session': <String>['k1'],
        'oidc.session.k1': 'legacy-session',
        'some.other.app.key': 'do-not-touch',
      });

      final store = OidcDefaultStore();
      await store.init();

      expect(await store.getAllKeys(OidcStoreNamespace.session), {'k1'});
      expect(
        await store.get(OidcStoreNamespace.session, key: 'k1'),
        'legacy-session',
      );
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.session.k1'), 'legacy-session');
      expect(await async.getStringList('oidc.keys.session'), ['k1']);
      expect(await async.containsKey('some.other.app.key'), isFalse);
      expect(await async.getBool(_migrationMarkerKey), isTrue);
    });

    testWidgets('runs only once', (tester) async {
      SharedPreferences.setMockInitialValues({'oidc.session.k1': 'legacy'});
      await OidcDefaultStore().init();
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.session.k1'), 'legacy');

      // A logout removes the key from the async store.
      await async.remove('oidc.session.k1');
      final secondStore = OidcDefaultStore();
      await secondStore.init();

      expect(
        await secondStore.get(OidcStoreNamespace.session, key: 'k1'),
        isNull,
      );
    });

    testWidgets('does not overwrite existing async values', (tester) async {
      SharedPreferences.setMockInitialValues({
        'oidc.session.k1': 'legacy-value',
        'oidc.keys.session': <String>['k1', 'k2'],
      });
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
        'oidc.session.k1': 'async-value',
        'oidc.keys.session': <String>['k1'],
      });

      final store = OidcDefaultStore();
      await store.init();

      expect(
        await store.get(OidcStoreNamespace.session, key: 'k1'),
        'async-value',
      );
      expect(await store.getAllKeys(OidcStoreNamespace.session), {'k1'});
    });

    for (final prefix in [null, '']) {
      testWidgets('does not copy anything when the prefix is "$prefix"', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'oidc.session.k1': 'legacy',
          'session.k1': 'legacy',
          '.session.k1': 'legacy',
        });

        final store = OidcDefaultStore(storagePrefix: prefix);
        await store.init();

        expect(await SharedPreferencesAsync().getKeys(), isEmpty);
      });
    }

    testWidgets('never writes to the legacy store', (tester) async {
      final legacyStore = _RecordingLegacyStore.withData({
        'flutter.oidc.keys.session': <String>['k1'],
        'flutter.oidc.session.k1': 'legacy',
        'flutter.app.key': 'app',
      });
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = legacyStore;

      final store = OidcDefaultStore();
      await store.init();
      await store.set(OidcStoreNamespace.session, key: 'k2', value: 'new');
      await store.remove(OidcStoreNamespace.session, key: 'k1');

      expect(legacyStore.writes, 0);
      final legacy = await legacyStore.getAll();
      expect(legacy['flutter.oidc.session.k1'], 'legacy');
      expect(legacy['flutter.oidc.keys.session'], ['k1']);
      expect(legacy['flutter.app.key'], 'app');
      expect(
        await SharedPreferencesAsync().getString('oidc.session.k1'),
        isNull,
      );
    });
  });
}
