// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Tests for the SharedPreferencesAsync support added for #301:
/// - the default backend is now [SharedPreferencesAsync],
/// - an injected [SharedPreferencesAsync] is honored,
/// - the deprecated synchronous [SharedPreferences] constructor path still
///   works end-to-end,
/// - and existing legacy data is migrated once into the async store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcDefaultStore SharedPreferencesAsync support (#301)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    testWidgets(
        'default (non-injected) backend round-trips through '
        'SharedPreferencesAsync', (tester) async {
      final store = OidcDefaultStore();
      await store.init();

      const ns = OidcStoreNamespace.state;
      await store.setMany(ns, values: {'k1': 'v1', 'k2': 'v2'});

      // readable back through the store.
      final values = await store.getMany(ns, keys: {'k1', 'k2'});
      expect(values, {'k1': 'v1', 'k2': 'v2'});

      // and it truly landed in the async store, not the legacy one: a
      // separately-constructed SharedPreferencesAsync shares the same
      // in-memory platform and sees the same value.
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.state.k1'), 'v1');

      // the legacy store must NOT hold it.
      final legacy = await SharedPreferences.getInstance();
      expect(legacy.getString('oidc.state.k1'), isNull);
    });

    testWidgets(
        'an injected SharedPreferencesAsync is used for all non-secure '
        'persistence', (tester) async {
      final injected = SharedPreferencesAsync();
      final store = OidcDefaultStore(sharedPreferencesAsync: injected);
      await store.init();

      const ns = OidcStoreNamespace.discoveryDocument;
      await store.set(ns, key: 'doc', value: 'discovery');

      // readable directly through the injected instance.
      expect(
        await injected.getString('oidc.discoveryDocument.doc'),
        'discovery',
      );
      // and through the store.
      expect(await store.get(ns, key: 'doc'), 'discovery');

      await store.remove(ns, key: 'doc');
      expect(await injected.getString('oidc.discoveryDocument.doc'), isNull);
    });

    testWidgets(
        'the deprecated synchronous SharedPreferences constructor path still '
        'works end-to-end', (tester) async {
      final legacy = await SharedPreferences.getInstance();
      // ignore: deprecated_member_use_from_same_package
      final store = OidcDefaultStore(sharedPreferences: legacy);
      await store.init();

      const ns = OidcStoreNamespace.request;
      await store.setMany(ns, values: {'a': '1', 'b': '2'});

      // full round-trip through the store.
      expect(await store.getMany(ns, keys: {'a', 'b'}), {'a': '1', 'b': '2'});
      expect(await store.getAllKeys(ns), {'a', 'b'});

      // data lands in the SAME legacy instance we passed.
      expect(legacy.getString('oidc.request.a'), '1');

      // and it must NOT have leaked into the async store.
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.request.a'), isNull);

      await store.removeMany(ns, keys: {'a'});
      expect(legacy.getString('oidc.request.a'), isNull);
      expect(await store.getAllKeys(ns), {'b'});
    });

    testWidgets(
        'existing legacy data under the storagePrefix is migrated once into '
        'the async store, and unrelated keys are left untouched',
        (tester) async {
      // Seed the legacy store as if a previous app version had written OIDC
      // data through the synchronous API, plus an unrelated key.
      SharedPreferences.setMockInitialValues({
        'oidc.keys.state': <String>['k1'],
        'oidc.state.k1': 'legacy-value',
        'some.other.app.key': 'do-not-touch',
      });

      final store = OidcDefaultStore();
      await store.init();

      const ns = OidcStoreNamespace.state;
      // migrated data is now visible through the (async-backed) store.
      expect(await store.getAllKeys(ns), {'k1'});
      expect(await store.get(ns, key: 'k1'), 'legacy-value');

      // it physically exists in the async store now.
      final async = SharedPreferencesAsync();
      expect(await async.getString('oidc.state.k1'), 'legacy-value');
      expect(await async.getStringList('oidc.keys.state'), ['k1']);

      // the unrelated (non-prefixed) key was NOT migrated.
      expect(await async.getString('some.other.app.key'), isNull);

      // the one-time migration marker was written.
      expect(await async.getBool('oidc.__oidc_async_migration_done'), isTrue);
    });

    testWidgets(
        'migration does not overwrite values already in the async store',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'oidc.state.k1': 'legacy-value',
      });
      // The async store already has a newer value for the same key.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
        'oidc.state.k1': 'async-value',
      });

      final store = OidcDefaultStore();
      await store.init();

      // the pre-existing async value wins; the legacy copy must not clobber it.
      expect(
        await store.get(OidcStoreNamespace.state, key: 'k1'),
        'async-value',
      );
    });
  });
}
