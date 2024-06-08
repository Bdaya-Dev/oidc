import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:web/web.dart';

/// where to store the values when using the [OidcStoreNamespace.session] namespace.
enum OidcWebStoreSessionManagementLocation {
  /// sessionStorage
  sessionStorage,

  /// localStorage
  localStorage,
}

/// {@template oidc_web_store}
/// an implementation of OidcStore for web that doesn't depend on flutter
/// {@endtemplate}
class OidcWebStore implements OidcStore {
  /// {@macro oidc_web_store}

  /// {@macro oidc_default_store}
  const OidcWebStore({
    this.storagePrefix = 'oidc',
    this.webSessionManagementLocation =
        OidcWebStoreSessionManagementLocation.sessionStorage,
  });

  /// prefix to put before the keys.
  ///
  /// by default this is `oidc`
  final String? storagePrefix;

  /// if true, we use the `sessionStorage` on web for the [OidcStoreNamespace.session] namespace.
  final OidcWebStoreSessionManagementLocation webSessionManagementLocation;

  String _getKey(OidcStoreNamespace namespace, String key) {
    return [storagePrefix, namespace.value, key].whereNotNull().join('.');
  }

  String _getNamespaceKeys(OidcStoreNamespace namespace) {
    return [storagePrefix, 'keys', namespace.value].whereNotNull().join('.');
  }

  @override
  Future<void> init() {
    return Future.value();
  }

  Future<void> _registerKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    final prev = await getAllKeys(namespace);
    final newKeys = prev.union(keys).toList();
    await _setAllKeys(namespace, newKeys);
  }

  Future<void> _unRegisterKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    final prev = await getAllKeys(namespace);
    final newKeys = prev.difference(keys).toList();
    await _setAllKeys(namespace, newKeys);
  }

  @override
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace) async {
    final keysRaw = window.localStorage[_getNamespaceKeys(namespace)] ?? '[]';
    return (jsonDecode(keysRaw) as List).cast<String>().toSet();
  }

  Future<void> _setAllKeys(
    OidcStoreNamespace namespace,
    List<String> keys,
  ) async {
    window.localStorage[_getNamespaceKeys(namespace)] = jsonEncode(keys);
  }

  Future<Map<String, String>> _defaultGetMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    return keys
        .map(
          (key) => MapEntry(
            key,
            window.localStorage[_getKey(namespace, key)],
          ),
        )
        .purify();
  }

  Future<void> _defaultSetMany(
    OidcStoreNamespace namespace,
    Map<String, String> values,
  ) async {
    for (final entry in values.entries) {
      window.localStorage[_getKey(namespace, entry.key)] = entry.value;
    }
  }

  Future<void> _defaultRemoveMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
  ) async {
    for (final key in keys) {
      window.localStorage.removeItem(_getKey(namespace, key));
    }
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  }) async {
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        //TODO: find a way to secure these tokens
        return _defaultGetMany(namespace, keys);
      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          return keys
              .map(
                (key) => MapEntry(
                  key,
                  window.sessionStorage[_getKey(namespace, key)],
                ),
              )
              .purify();
        }
        return _defaultGetMany(namespace, keys);
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.discoveryDocument:
      case OidcStoreNamespace.stateResponse:
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
        //TODO: find a way to secure these tokens
        return _defaultSetMany(namespace, values);

      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          for (final element in values.entries) {
            window.sessionStorage[_getKey(namespace, element.key)] =
                element.value;
          }
        } else {
          await _defaultSetMany(namespace, values);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.stateResponse:
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
        // TODO: find a way to secure these tokens
        await _defaultRemoveMany(namespace, keys);

      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          for (final element in keys) {
            window.sessionStorage.removeItem(_getKey(namespace, element));
          }
        } else {
          await _defaultRemoveMany(namespace, keys);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.discoveryDocument:
      case OidcStoreNamespace.stateResponse:
        await _defaultRemoveMany(namespace, keys);
    }
  }
}

extension on Iterable<MapEntry<String, String?>> {
  Map<String, String> purify() {
    return Map.fromEntries(where((element) => element.value != null))
        .cast<String, String>();
  }
}
