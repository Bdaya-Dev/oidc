// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

// coverage:ignore-line
final _logger = Logger('Oidc.DefaultStore');

/// where to store the values when using the [OidcStoreNamespace.session] namespace.
enum OidcDefaultStoreWebSessionManagementLocation {
  /// sessionStorage
  sessionStorage,

  /// localStorage
  localStorage,
}

/// {@template oidc_default_store}
/// The default [OidcStore] implementation for `package:oidc`
/// this relies on:
/// - for the [OidcStoreNamespace.secureTokens] namespace, we use [FlutterSecureStorage].
/// - for the [OidcStoreNamespace.session] namespace
///     - we use `dart:html` for web,
///         - if [webSessionManagementLocation] is set to [OidcDefaultStoreWebSessionManagementLocation.sessionStorage]
///           we use [html.window.sessionStorage].
///         - if it's set to [OidcDefaultStoreWebSessionManagementLocation.sessionStorage] we use [html.window.localStorage].
///     - we use [SharedPreferences] for other platforms
/// - for the [OidcStoreNamespace.state] namespace
///     - we use `package:universal_html` + `localStorage` for web.
///       this is a MUST and other implementations can't change this behaviour, for the `samePage` navigation mode to work.
/// - [SharedPreferences] for all other operations.
///
/// {@endtemplate}
class OidcDefaultStore implements OidcStore {
  /// {@macro oidc_default_store}
  OidcDefaultStore({
    FlutterSecureStorage? secureStorageInstance,
    SharedPreferences? sharedPreferences,
    this.webSessionManagementLocation =
        OidcDefaultStoreWebSessionManagementLocation.sessionStorage,
  })  : _secureStorage = secureStorageInstance ?? const FlutterSecureStorage(),
        __sharedPreferences = sharedPreferences;
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? __sharedPreferences;
  SharedPreferences get _sharedPreferences => __sharedPreferences!;

  /// checks if the current platform is web.
  @visibleForTesting
  bool testIsWeb = kIsWeb;

  /// if true, we use the `sessionStorage` on web for the [OidcStoreNamespace.session] namespace.
  final OidcDefaultStoreWebSessionManagementLocation
      webSessionManagementLocation;

  /// true if [init] has been called with no exceptions.
  bool get didInit => _hasInit;
  bool _hasInit = false;

  String _getKey(OidcStoreNamespace namespace, String key) {
    return 'oidc-${namespace.value}-$key';
  }

  String _getNamespaceKeys(OidcStoreNamespace namespace) {
    return 'oidc.keys-${namespace.value}';
  }

  @override
  Future<void> init() async {
    if (_hasInit) return;
    try {
      _hasInit = true;
      __sharedPreferences = await SharedPreferences.getInstance();
    } catch (e) {
      // coverage:ignore-line
      _hasInit = false;
      rethrow;
    }
  }

  Future<void> _registerKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    final prev = await getAllKeys(namespace);
    await _sharedPreferences.setStringList(
      _getNamespaceKeys(namespace),
      prev.union(keys).toList(),
    );
  }

  Future<void> _unRegisterKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    final prev = await getAllKeys(namespace);
    await _sharedPreferences.setStringList(
      _getNamespaceKeys(namespace),
      prev.difference(keys).toList(),
    );
  }

  @override
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace) async {
    return _sharedPreferences
            .getStringList(_getNamespaceKeys(namespace))
            ?.toSet() ??
        {};
  }

  Future<Map<String, String>> _defaultGetMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    return keys
        .map(
          (key) => MapEntry(
            key,
            _sharedPreferences.getString(_getKey(namespace, key)),
          ),
        )
        .purify();
  }

  Future<void> _defaultSetMany(
    OidcStoreNamespace namespace,
    Map<String, String> values,
  ) async {
    await Future.wait(
      values.entries.map(
        (entry) => _sharedPreferences.setString(
          _getKey(namespace, entry.key),
          entry.value,
        ),
      ),
    );
  }

  Future<void> _defaultRemoveMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    await Future.wait(
      keys.map((key) => _sharedPreferences.remove(_getKey(namespace, key))),
    );
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  }) async {
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        // optimally we would make these operations concurrent, but due to this issue we can't.
        // see https://github.com/mogol/flutter_secure_storage/issues/381#issuecomment-1128636818
        try {
          // secure storage might not be supported in all platforms,
          // so we fallback to normal storage if that's the case.
          final res = <String, String>{};
          for (final k in keys) {
            final v = await _secureStorage.read(key: _getKey(namespace, k));
            if (v != null) {
              res[k] = v;
            }
          }
          return res;
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried reading secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to using package:shared_pereferences, which is not secure.');
          return _defaultGetMany(namespace, keys);
          // coverage:ignore-end
        }
      case OidcStoreNamespace.state:
        if (testIsWeb) {
          return keys
              .map(
                (key) => MapEntry(
                  key,
                  html.window.localStorage[_getKey(namespace, key)],
                ),
              )
              .purify();
        } else {
          return _defaultGetMany(namespace, keys);
        }
      case OidcStoreNamespace.discoveryDocument:
        return _defaultGetMany(namespace, keys);
      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          return keys
              .map(
                (key) => MapEntry(
                  key,
                  html.window.sessionStorage[_getKey(namespace, key)],
                ),
              )
              .purify();
        }
        return _defaultGetMany(namespace, keys);
    }
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
  }) async {
    await _registerKeyForNamespace(namespace, values.keys.toSet());

    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        try {
          // optimally we would make these operations concurrent, but due to this issue we can't.
          // see https://github.com/mogol/flutter_secure_storage/issues/381#issuecomment-1128636818
          for (final entry in values.entries) {
            await _secureStorage.write(
              key: _getKey(namespace, entry.key),
              value: entry.value,
            );
          }
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried writing secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to using package:shared_pereferences, which is not secure.');
          return _defaultSetMany(namespace, values);
          // coverage:ignore-end
        }
      case OidcStoreNamespace.state:
        if (testIsWeb) {
          for (final element in values.entries) {
            html.window.localStorage[_getKey(namespace, element.key)] =
                element.value;
          }
        } else {
          return _defaultSetMany(namespace, values);
        }
      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          for (final element in values.entries) {
            html.window.sessionStorage[_getKey(namespace, element.key)] =
                element.value;
          }
        } else {
          await _defaultSetMany(namespace, values);
        }
      case OidcStoreNamespace.discoveryDocument:
        await _defaultSetMany(namespace, values);
    }
  }

  @override
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  }) async {
    await _unRegisterKeyForNamespace(namespace, keys);
    // final mappedKeys = keys.map((e) => _getKey(namespace, e)).toSet();
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        try {
          // optimally we would make these operations concurrent, but due to this issue we can't.
          // see https://github.com/mogol/flutter_secure_storage/issues/381#issuecomment-1128636818
          for (final key in keys) {
            await _secureStorage.delete(key: _getKey(namespace, key));
          }
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried removing secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to reading using package:shared_pereferences, which is not secure.');
          await _defaultRemoveMany(namespace, keys);
          // coverage:ignore-end
        }
      case OidcStoreNamespace.state:
        if (testIsWeb) {
          for (final element in keys) {
            html.window.localStorage.remove(_getKey(namespace, element));
          }
        } else {
          await _defaultRemoveMany(namespace, keys);
        }
      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          for (final element in keys) {
            html.window.sessionStorage.remove(_getKey(namespace, element));
          }
        } else {
          await _defaultRemoveMany(namespace, keys);
        }
      case OidcStoreNamespace.discoveryDocument:
        await _defaultRemoveMany(namespace, keys);
    }
  }
}

extension _IterableMapEntryPure on Iterable<MapEntry<String, String?>> {
  Map<String, String> purify() {
    return Map.fromEntries(where((element) => element.value != null))
        .cast<String, String>();
  }
}
