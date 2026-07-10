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

    test('can be instantiated with a default (non-injected) logger', () {
      final defaultStore = FileOidcStore(file: storeFile);
      expect(defaultStore, isNotNull);
    });

    test(
      'userHome() builds a path under HOME/USERPROFILE/.oidc_cli/store.json',
      () {
        final home =
            Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            '.';
        final userHomeStore = FileOidcStore.userHome(logger: logger);
        expect(userHomeStore.file.path, contains(home));
        expect(userHomeStore.file.path, contains('.oidc_cli'));
        expect(userHomeStore.file.path, endsWith('store.json'));
      },
    );

    test('getConfig returns empty map when the store file is empty', () async {
      storeFile
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      final config = await store.getConfig();
      expect(config, isEmpty);
    });

    test(
      'setConfig creates missing parent directories before writing',
      () async {
        final nestedFile = File(
          '${tempDir.path}/nested/does/not/exist/store.json',
        );
        final nestedStore = FileOidcStore(file: nestedFile, logger: logger);

        await nestedStore.setConfig({'issuer': 'https://example.com'});

        expect(nestedFile.existsSync(), isTrue);
        final config = await nestedStore.getConfig();
        expect(config['issuer'], 'https://example.com');
      },
    );

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

    test(
      'written store file is created with 0600 (owner rw only) on POSIX',
      () async {
        await store.setConfig({'issuer': 'https://example.com'});

        expect(storeFile.existsSync(), isTrue);
        // 0x1FF masks the permission bits; 0x180 == 0o600 (owner read+write).
        expect(storeFile.statSync().mode & 0x1FF, 0x180);
      },
      // dart:io has no chmod; the 0600 enforcement shells out to `chmod`,
      // which only applies on POSIX. On Windows access is governed by the
      // per-user profile ACL instead.
      skip: Platform.isWindows ? 'POSIX-only file permission check' : false,
    );

    test('overwriting an existing store stays 0600 on POSIX', () async {
      await store.setConfig({'issuer': 'https://first.example'});
      await store.setConfig({'issuer': 'https://second.example'});

      final config = await store.getConfig();
      expect(config['issuer'], 'https://second.example');
      if (!Platform.isWindows) {
        expect(storeFile.statSync().mode & 0x1FF, 0x180);
      }
      // The temp file used for the atomic write must not linger.
      expect(File('${storeFile.path}.tmp').existsSync(), isFalse);
    });

    test('invalid JSON store content is treated as empty (no throw)', () async {
      storeFile
        ..createSync(recursive: true)
        ..writeAsStringSync('this is not json');

      final config = await store.getConfig();
      expect(config, isEmpty);

      final keys = await store.getAllKeys(OidcStoreNamespace.secureTokens);
      expect(keys, isEmpty);

      // One error log for each read.
      verify(() => logger.err(any())).called(2);
    });
  });
}
