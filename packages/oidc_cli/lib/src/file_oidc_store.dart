import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:path/path.dart' as p;

/// A JSON-file-backed [OidcStore] for the CLI.
class FileOidcStore implements OidcStore {
  /// Creates a [FileOidcStore] backed by [file].
  FileOidcStore({required this.file, Logger? logger})
    : _logger = logger ?? Logger();

  /// Creates a [FileOidcStore] from a path.
  /// If the file does not exist, it will be created.
  factory FileOidcStore.fromPath(String path, {Logger? logger}) {
    return FileOidcStore(file: File(path), logger: logger);
  }

  /// Creates a [FileOidcStore] in the user's home directory.
  /// (~/.oidc_cli/store.json)
  factory FileOidcStore.userHome({Logger? logger}) {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final path = p.join(home, '.oidc_cli', 'store.json');
    return FileOidcStore.fromPath(path, logger: logger);
  }

  /// The JSON file used for persistence.
  final File file;

  final Logger _logger;

  Future<Map<String, dynamic>> _read() async {
    if (!file.existsSync()) {
      return {};
    }
    try {
      final content = file.readAsStringSync();
      if (content.isEmpty) {
        return {};
      }
      return jsonDecode(content) as Map<String, dynamic>;
    } on Exception catch (e) {
      _logger.err('Error reading store file: $e');
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final encoded = jsonEncode(data);
    // Atomic write: serialize to a sibling temp file, restrict its permissions
    // while it is still empty/owner-owned, then rename it over the target. A
    // crash mid-write therefore cannot truncate or expose a half-written store.
    final tmp = File('${file.path}.tmp')..writeAsStringSync(encoded);
    _restrictToOwner(tmp);
    tmp.renameSync(file.path);
    // The renamed inode already carries 0600 from the temp file on POSIX, but
    // re-assert in case the target pre-existed with looser permissions.
    _restrictToOwner(file);
  }

  /// Restricts [f] to owner-only read/write (`0600`) on POSIX platforms so the
  /// persisted tokens are not world-readable (RFC 9700 §4.9.3 — secrets must
  /// not be stored in plaintext readable by other users).
  ///
  /// `dart:io` exposes no `chmod`, so we shell out to `chmod` and guard it
  /// behind `!Platform.isWindows`. On Windows the store lives under the
  /// per-user profile directory (`%USERPROFILE%\.oidc_cli`) whose ACL already
  /// restricts access to the owning user.
  void _restrictToOwner(File f) {
    if (Platform.isWindows) {
      return;
    }
    try {
      Process.runSync('chmod', ['600', f.path]);
    } on Exception catch (e) {
      _logger.warn('Could not restrict permissions on ${f.path}: $e');
    }
  }

  String _getPrefix(OidcStoreNamespace namespace, String? managerId) {
    if (managerId == null) {
      return '${namespace.value}/';
    }
    return '${namespace.value}/$managerId/';
  }

  String _getFullKey(
    OidcStoreNamespace namespace,
    String key,
    String? managerId,
  ) {
    return '${_getPrefix(namespace, managerId)}$key';
  }

  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getAllKeys(
    OidcStoreNamespace namespace, {
    String? managerId,
  }) async {
    final data = await _read();
    final prefix = _getPrefix(namespace, managerId);
    return data.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toSet();
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    final data = await _read();
    final result = <String, String>{};
    for (final key in keys) {
      final fullKey = _getFullKey(namespace, key, managerId);
      final value = data[fullKey];
      if (value != null) {
        result[key] = value.toString();
      }
    }
    return result;
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
    String? managerId,
  }) async {
    final data = await _read();
    for (final entry in values.entries) {
      final fullKey = _getFullKey(namespace, entry.key, managerId);
      data[fullKey] = entry.value;
    }
    await _write(data);
  }

  @override
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    final data = await _read();
    for (final key in keys) {
      final fullKey = _getFullKey(namespace, key, managerId);
      data.remove(fullKey);
    }
    await _write(data);
  }

  /// Reads the CLI configuration from the store.
  Future<Map<String, dynamic>> getConfig() async {
    final data = await _read();
    return (data['config'] as Map<String, dynamic>?) ?? {};
  }

  /// Persists the CLI configuration to the store.
  Future<void> setConfig(Map<String, dynamic> config) async {
    final data = await _read();
    data['config'] = config;
    await _write(data);
  }
}
