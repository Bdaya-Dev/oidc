import 'dart:convert';

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

  String _getKey(OidcStoreNamespace namespace, String key, String? managerId) {
    return [storagePrefix, managerId, namespace.value, key].nonNulls.join('.');
  }

  String _getNamespaceKeys(OidcStoreNamespace namespace, String? managerId) {
    return [
      storagePrefix,
      managerId,
      'keys',
      namespace.value,
    ].nonNulls.join('.');
  }

  @override
  Future<void> init() {
    return Future.value();
  }

  Future<void> _registerKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    final prev = await getAllKeys(namespace);
    final newKeys = prev.union(keys).toList();
    await _setAllKeys(namespace, newKeys, managerId);
  }

  Future<void> _unRegisterKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    final prev = await getAllKeys(namespace);
    final newKeys = prev.difference(keys).toList();
    await _setAllKeys(namespace, newKeys, managerId);
  }

  @override
  Future<Set<String>> getAllKeys(
    OidcStoreNamespace namespace, {
    String? managerId,
  }) async {
    final keysRaw =
        window.localStorage.getItem(_getNamespaceKeys(namespace, managerId)) ??
        '[]';
    return (jsonDecode(keysRaw) as List).cast<String>().toSet();
  }

  Future<void> _setAllKeys(
    OidcStoreNamespace namespace,
    List<String> keys,
    String? managerId,
  ) async {
    window.localStorage.setItem(
      _getNamespaceKeys(namespace, managerId),
      jsonEncode(keys),
    );
  }

  Future<Map<String, String>> _defaultGetMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    return keys
        .map(
          (key) => MapEntry(
            key,
            window.localStorage.getItem(_getKey(namespace, key, managerId)),
          ),
        )
        .purify();
  }

  void _defaultSetMany(
    OidcStoreNamespace namespace,
    Map<String, String> values,
    String? managerId,
  ) {
    for (final entry in values.entries) {
      window.localStorage.setItem(
        _getKey(namespace, entry.key, managerId),
        entry.value,
      );
    }
  }

  void _defaultRemoveMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) {
    for (final key in keys) {
      window.localStorage.removeItem(_getKey(namespace, key, managerId));
    }
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        //TODO: find a way to secure these tokens
        return _defaultGetMany(namespace, keys, managerId);
      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          return keys
              .map(
                (key) => MapEntry(
                  key,
                  window.sessionStorage.getItem(
                    _getKey(namespace, key, managerId),
                  ),
                ),
              )
              .purify();
        }
        return _defaultGetMany(namespace, keys, managerId);
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.discoveryDocument:
      case OidcStoreNamespace.stateResponse:
        return _defaultGetMany(namespace, keys, managerId);
    }
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
    String? managerId,
  }) async {
    await _registerKeyForNamespace(namespace, values.keys.toSet(), managerId);

    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        //TODO: find a way to secure these tokens
        return _defaultSetMany(namespace, values, managerId);

      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          for (final element in values.entries) {
            window.sessionStorage.setItem(
              _getKey(namespace, element.key, managerId),
              element.value,
            );
          }
        } else {
          _defaultSetMany(namespace, values, managerId);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.stateResponse:
      case OidcStoreNamespace.discoveryDocument:
        _defaultSetMany(namespace, values, managerId);
    }
  }

  @override
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    await _unRegisterKeyForNamespace(namespace, keys, managerId);
    // final mappedKeys = keys.map((e) => _getKey(namespace, e)).toSet();
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        // TODO: find a way to secure these tokens
        _defaultRemoveMany(namespace, keys, managerId);

      case OidcStoreNamespace.session:
        if (webSessionManagementLocation ==
            OidcWebStoreSessionManagementLocation.sessionStorage) {
          for (final element in keys) {
            window.sessionStorage.removeItem(
              _getKey(namespace, element, managerId),
            );
          }
        } else {
          _defaultRemoveMany(namespace, keys, managerId);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.discoveryDocument:
      case OidcStoreNamespace.stateResponse:
        _defaultRemoveMany(namespace, keys, managerId);
    }
  }
}

extension on Iterable<MapEntry<String, String?>> {
  Map<String, String> purify() {
    return Map.fromEntries(
      where((element) => element.value != null),
    ).cast<String, String>();
  }
}
