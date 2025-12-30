import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  group('FileOidcStore', () {
    late Directory tempDir;
    late File storeFile;
    late FileOidcStore store;
    late Logger logger;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('oidc_cli_store_test_');
      storeFile = File('${tempDir.path}/store.json');
      logger = _MockLogger();
      when(() => logger.err(any())).thenReturn(null);
      store = FileOidcStore(file: storeFile, logger: logger);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('getConfig returns empty map when store file is missing', () async {
      final config = await store.getConfig();
      expect(config, isEmpty);
    });

    test('setConfig persists and getConfig reads it back', () async {
      await store.setConfig({'issuer': 'https://example.com'});

      final config = await store.getConfig();
      expect(config['issuer'], 'https://example.com');

      final raw =
          jsonDecode(storeFile.readAsStringSync()) as Map<String, dynamic>;
      expect(raw['config'], isA<Map<String, dynamic>>());
    });

    test('setMany/getMany are namespaced and manager-scoped', () async {
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        values: {
          'k1': 'v1',
          'k2': 'v2',
        },
      );
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm2',
        values: {
          'k1': 'v3',
        },
      );

      final m1 = await store.getMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        keys: {'k1', 'k2'},
      );
      expect(m1, {'k1': 'v1', 'k2': 'v2'});

      final m2 = await store.getMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm2',
        keys: {'k1', 'k2'},
      );
      expect(m2, {'k1': 'v3'});
    });

    test('getAllKeys returns keys without prefix for a managerId', () async {
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        values: {
          'k1': 'v1',
          'k2': 'v2',
        },
      );

      final keys = await store.getAllKeys(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
      );

      expect(keys, {'k1', 'k2'});
    });

    test('removeMany deletes only requested keys', () async {
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        values: {
          'k1': 'v1',
          'k2': 'v2',
        },
      );

      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        keys: {'k2'},
      );

      final remaining = await store.getMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        keys: {'k1', 'k2'},
      );
      expect(remaining, {'k1': 'v1'});
    });

    test('removeAll preserves config and clears other keys', () async {
      await store.setConfig({'issuer': 'https://example.com'});
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
        values: {
          'k1': 'v1',
        },
      );

      await store.removeAll('oidc');

      final raw =
          jsonDecode(storeFile.readAsStringSync()) as Map<String, dynamic>;
      expect(raw.keys, {'config'});
      expect((raw['config'] as Map)['issuer'], 'https://example.com');

      final keys = await store.getAllKeys(
        OidcStoreNamespace.secureTokens,
        managerId: 'm1',
      );
      expect(keys, isEmpty);
    });

    test('invalid JSON store content is treated as empty (no throw)', () async {
      storeFile.createSync(recursive: true);
      storeFile.writeAsStringSync('this is not json');

      final config = await store.getConfig();
      expect(config, isEmpty);

      final keys = await store.getAllKeys(OidcStoreNamespace.secureTokens);
      expect(keys, isEmpty);

      // One error log for each read.
      verify(() => logger.err(any())).called(2);
    });
  });
}
