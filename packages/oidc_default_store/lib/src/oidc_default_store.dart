// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'html_stub.dart' if (dart.library.js_interop) 'html_web.dart' as html;

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
///           we use [html.Window.sessionStorage].
///         - if it's set to [OidcDefaultStoreWebSessionManagementLocation.sessionStorage] we use [html.Window.localStorage].
///     - we use `shared_preferences` for other platforms
/// - for the [OidcStoreNamespace.state] namespace
///     - we use `package:universal_html` + `localStorage` for web.
///       this is a MUST and other implementations can't change this behavior, for the `samePage` navigation mode to work.
/// - `shared_preferences` for all other operations.
///
/// The non-secure `shared_preferences` persistence uses the modern
/// [SharedPreferencesAsync] API by default (see #301). You can inject your own
/// instance via the `sharedPreferencesAsync` constructor parameter to share it
/// with the rest of your app. The legacy synchronous [SharedPreferences] path
/// is still supported through the deprecated `sharedPreferences` parameter for
/// backward compatibility. On the default path, this store performs a one-time,
/// best-effort migration of its own keys from the legacy store into
/// [SharedPreferencesAsync] (see [OidcDefaultStore.new]).
/// {@endtemplate}
class OidcDefaultStore implements OidcStore {
  /// {@macro oidc_default_store}
  ///
  /// [sharedPreferencesAsync] lets you inject a [SharedPreferencesAsync]
  /// instance so this store shares the same async preferences as the rest of
  /// your app. When omitted (and no legacy [sharedPreferences] is provided),
  /// [init] creates a default [SharedPreferencesAsync] and runs a one-time,
  /// best-effort migration of this store's own keys from the legacy store (see
  /// `_migrateLegacyPrefsToAsyncIfNeeded`).
  ///
  /// [sharedPreferences] is the deprecated synchronous backend; passing it keeps
  /// the legacy behavior end-to-end (no migration, same data location).
  OidcDefaultStore({
    FlutterSecureStorage? secureStorageInstance,
    @Deprecated(
      'The synchronous SharedPreferences API is now legacy. Pass '
      '`sharedPreferencesAsync` (a SharedPreferencesAsync instance) instead. '
      'See https://pub.dev/packages/shared_preferences and issue #301.',
    )
    SharedPreferences? sharedPreferences,
    SharedPreferencesAsync? sharedPreferencesAsync,
    this.storagePrefix = 'oidc',
    this.webSessionManagementLocation =
        OidcDefaultStoreWebSessionManagementLocation.sessionStorage,
  })  : secureStorage = secureStorageInstance,
        // ignore: deprecated_member_use_from_same_package
        _legacySharedPreferences = sharedPreferences,
        _injectedSharedPreferencesAsync = sharedPreferencesAsync;

  /// Recommended hardened [AndroidOptions] for storing OIDC tokens at rest.
  ///
  /// This is the `flutter_secure_storage` v10 default (an Android-Keystore-backed
  /// RSA key wrapping an AES-GCM payload key). The deprecated
  /// `encryptedSharedPreferences` (Jetpack Security) path is intentionally NOT
  /// set — v10 migrates away from it automatically. (RFC 9700 §4.9.3/§4.14.)
  static const AndroidOptions recommendedAndroidOptions =
      AndroidOptions.defaultOptions;

  /// Recommended hardened [IOSOptions] for storing OIDC tokens at rest.
  ///
  /// `accessibility` is [KeychainAccessibility.first_unlock_this_device]
  /// (the MSAL posture): the item survives a reboot so a backgrounded app can
  /// still refresh tokens after first unlock, but it is never iCloud-synced and
  /// never migrated to another device. `synchronizable` stays at its `false`
  /// default so the item is never written to the iCloud keychain.
  static const IOSOptions recommendedIOSOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Recommended hardened [MacOsOptions] for storing OIDC tokens at rest.
  ///
  /// Mirrors [recommendedIOSOptions]. Note that macOS Flutter apps additionally
  /// require the Keychain Sharing entitlement for `flutter_secure_storage` to
  /// work at all.
  static const MacOsOptions recommendedMacOsOptions = MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Builds a [FlutterSecureStorage] configured with the hardened OIDC defaults
  /// ([recommendedAndroidOptions], [recommendedIOSOptions] and
  /// [recommendedMacOsOptions]).
  ///
  /// Pass the result to [OidcDefaultStore.new]'s `secureStorageInstance` to get
  /// the recommended at-rest posture for the
  /// [OidcStoreNamespace.secureTokens] namespace:
  ///
  /// ```dart
  /// final store = OidcDefaultStore(
  ///   secureStorageInstance: OidcDefaultStore.createHardenedSecureStorage(),
  /// );
  /// ```
  ///
  /// Android uses [recommendedAndroidOptions] (the v10 default), so it is not
  /// passed explicitly here.
  ///
  /// This is opt-in (not the constructor default) to preserve backward
  /// compatibility: callers that pass their own [FlutterSecureStorage], or rely
  /// on the `shared_preferences` fallback, are unaffected.
  static FlutterSecureStorage createHardenedSecureStorage() =>
      const FlutterSecureStorage(
        iOptions: recommendedIOSOptions,
        mOptions: recommendedMacOsOptions,
      );

  /// instance of [FlutterSecureStorage] to use for the
  /// [OidcStoreNamespace.secureTokens] namespace.
  ///
  /// When this is `null`, the [OidcStoreNamespace.secureTokens] namespace falls
  /// back to `package:shared_preferences`, which is **not** secure (it is
  /// plaintext on most platforms and `localStorage` on web). For the hardened
  /// at-rest posture on Android/iOS/macOS, pass
  /// [createHardenedSecureStorage].
  ///
  /// On web there is no real secret-storage primitive: `shared_preferences`
  /// maps to `localStorage`, which is readable by any injected script
  /// (Browser-Based Apps BCP §8). Prefer a BFF (tokens behind HttpOnly cookies)
  /// or in-memory storage with service-worker refresh; treat web persistence as
  /// best-effort.
  FlutterSecureStorage? secureStorage;

  /// One-shot guard so the plaintext-fallback warning is logged once, not per op.
  bool _warnedInsecureSecureTokens = false;

  /// Warns (once) that `secureTokens` is being persisted UNENCRYPTED because no
  /// [FlutterSecureStorage] was supplied. Previously this fallback was silent,
  /// so tokens + the PKCE `code_verifier` landed in plaintext SharedPreferences
  /// with no signal (RFC 9700 / OAuth 2.0 for Browser-Based-Apps BCP).
  void _warnInsecureSecureTokensFallback() {
    if (_warnedInsecureSecureTokens) {
      return;
    }
    _warnedInsecureSecureTokens = true;
    _logger.warning(
      'OidcDefaultStore: no FlutterSecureStorage instance was provided, so the '
      'secureTokens namespace (access/refresh/id tokens and the PKCE '
      'code_verifier) is persisted via package:shared_preferences, which is '
      'NOT encrypted at rest. Pass `secureStorageInstance: '
      'FlutterSecureStorage()` to OidcDefaultStore to store these securely.',
    );
  }

  /// Legacy (synchronous) `shared_preferences` instance, if one was injected
  /// through the deprecated `sharedPreferences` constructor parameter.
  final SharedPreferences? _legacySharedPreferences;

  /// A caller-supplied [SharedPreferencesAsync] instance, if one was injected
  /// through the `sharedPreferencesAsync` constructor parameter.
  final SharedPreferencesAsync? _injectedSharedPreferencesAsync;

  /// The resolved non-secure persistence backend, populated by [init].
  _OidcPrefsBackend? _backend;
  _OidcPrefsBackend get _prefs => _backend!;

  /// prefix to put before the keys.
  ///
  /// by default this is `oidc`
  final String? storagePrefix;

  /// checks if the current platform is web.
  @visibleForTesting
  bool testIsWeb = kIsWeb;

  /// if true, we use the `sessionStorage` on web for the [OidcStoreNamespace.session] namespace.
  final OidcDefaultStoreWebSessionManagementLocation
      webSessionManagementLocation;

  /// true if [init] has been called with no exceptions.
  bool get didInit => initMemoizer.hasRun;

  /// Memoizer for the initialization process.
  @protected
  AsyncMemoizer<void> initMemoizer = AsyncMemoizer<void>();

  String _getKey(OidcStoreNamespace namespace, String key, String? managerId) {
    return [storagePrefix, managerId, namespace.value, key].nonNulls.join('.');
  }

  String _getNamespaceKeys(OidcStoreNamespace namespace, String? managerId) {
    return [storagePrefix, managerId, 'keys', namespace.value]
        .nonNulls
        .join('.');
  }

  @override
  Future<void> init() async {
    await initMemoizer.runOnce(() async {
      html.initWeb();
      _backend ??= await _resolveBackend();
    });
  }

  /// Resolves which non-secure persistence backend [OidcDefaultStore] uses.
  ///
  /// Precedence:
  /// 1. An explicitly injected [SharedPreferencesAsync] (the caller owns its
  ///    lifecycle and any data migration).
  /// 2. The deprecated synchronous [SharedPreferences] (kept end-to-end so its
  ///    data location never moves — full backward compatibility).
  /// 3. The default: a fresh [SharedPreferencesAsync], after a one-time
  ///    best-effort migration of this store's keys from the legacy store.
  Future<_OidcPrefsBackend> _resolveBackend() async {
    if (_injectedSharedPreferencesAsync case final injected?) {
      return _OidcAsyncPrefsBackend(injected);
    }
    if (_legacySharedPreferences case final legacy?) {
      return _OidcLegacyPrefsBackend(legacy);
    }
    final async = SharedPreferencesAsync();
    // On web the `shared_preferences` backend is never exercised (session/state
    // go through window.localStorage), and there the async API shares the same
    // localStorage as the legacy one, so there is nothing to migrate.
    if (!testIsWeb) {
      await _migrateLegacyPrefsToAsyncIfNeeded(async);
    }
    return _OidcAsyncPrefsBackend(async);
  }

  /// One-time, best-effort copy of this store's own keys from the legacy
  /// synchronous `shared_preferences` store into [async].
  ///
  /// The two APIs do not always share the same platform storage: on Android the
  /// legacy API is backed by `SharedPreferences` while [SharedPreferencesAsync]
  /// defaults to DataStore Preferences, so data written before this package
  /// adopted the async API would otherwise appear lost after an upgrade. (On
  /// iOS/macOS/web/Windows/Linux both APIs share one store, so this is a no-op
  /// copy.) See the `shared_preferences` README section "SharedPreferences vs
  /// SharedPreferencesAsync vs SharedPreferencesWithCache" and issue #301.
  ///
  /// Only keys under [storagePrefix] are migrated (never the whole app store),
  /// the copy runs once (guarded by a marker written into [async]), and existing
  /// async values are never overwritten.
  Future<void> _migrateLegacyPrefsToAsyncIfNeeded(
    SharedPreferencesAsync async,
  ) async {
    final prefix = storagePrefix;
    // Without a prefix we cannot scope the migration to this package's keys, so
    // we skip it rather than copying the entire (potentially large) app store.
    if (prefix == null || prefix.isEmpty) {
      return;
    }
    final migrationMarkerKey = '$prefix.__oidc_async_migration_done';
    try {
      if (await async.getBool(migrationMarkerKey) ?? false) {
        return;
      }
      final legacy = await SharedPreferences.getInstance();
      final ownedKeys =
          legacy.getKeys().where((key) => key.startsWith('$prefix.'));
      for (final key in ownedKeys) {
        final value = legacy.get(key);
        if (value is String) {
          if (await async.getString(key) == null) {
            await async.setString(key, value);
          }
        } else if (value is List) {
          if (await async.getStringList(key) == null) {
            await async.setStringList(key, value.cast<String>());
          }
        }
      }
      await async.setBool(migrationMarkerKey, true);
    } catch (e) {
      // coverage:ignore-start
      _logger.warning(
        'OidcDefaultStore: failed to migrate legacy shared_preferences data to '
        'SharedPreferencesAsync; existing values under "$prefix" may need to be '
        're-established. Error: $e',
      );
      // coverage:ignore-end
    }
  }

  Future<void> _registerKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    // Read from the SAME per-manager bucket we write to below: `_setAllKeys`
    // is keyed by `managerId`, so reading the default (null) bucket here made
    // register/unregister operate on a different key set than the writes,
    // corrupting per-manager key cleanup in multi-manager apps.
    final prev = await getAllKeys(namespace, managerId: managerId);
    final newKeys = prev.union(keys).toList();
    await _setAllKeys(namespace, newKeys, managerId);
  }

  Future<void> _unRegisterKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    // Read from the SAME per-manager bucket we write to below: `_setAllKeys`
    // is keyed by `managerId`, so reading the default (null) bucket here made
    // register/unregister operate on a different key set than the writes,
    // corrupting per-manager key cleanup in multi-manager apps.
    final prev = await getAllKeys(namespace, managerId: managerId);
    final newKeys = prev.difference(keys).toList();
    await _setAllKeys(namespace, newKeys, managerId);
  }

  @override
  Future<Set<String>> getAllKeys(
    OidcStoreNamespace namespace, {
    String? managerId,
  }) async {
    if (testIsWeb) {
      final keysRaw = html.window.localStorage
              .getItem(_getNamespaceKeys(namespace, managerId)) ??
          '[]';
      return (jsonDecode(keysRaw) as List).cast<String>().toSet();
    } else {
      return (await _prefs
                  .getStringList(_getNamespaceKeys(namespace, managerId)))
              ?.toSet() ??
          {};
    }
  }

  Future<void> _setAllKeys(
    OidcStoreNamespace namespace,
    List<String> keys,
    String? managerId,
  ) async {
    if (testIsWeb) {
      html.window.localStorage.setItem(
        _getNamespaceKeys(namespace, managerId),
        jsonEncode(keys),
      );
    } else {
      await _prefs.setStringList(
        _getNamespaceKeys(namespace, managerId),
        keys,
      );
    }
  }

  Future<Map<String, String>> _defaultGetMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    if (testIsWeb) {
      return keys
          .map(
            (key) => MapEntry(
              key,
              html.window.localStorage
                  .getItem(_getKey(namespace, key, managerId)),
            ),
          )
          .purify();
    } else {
      final entries = await Future.wait(
        keys.map(
          (key) async => MapEntry(
            key,
            await _prefs.getString(_getKey(namespace, key, managerId)),
          ),
        ),
      );
      return entries.purify();
    }
  }

  Future<void> _defaultSetMany(
    OidcStoreNamespace namespace,
    Map<String, String> values,
    String? managerId,
  ) async {
    if (testIsWeb) {
      for (final entry in values.entries) {
        html.window.localStorage
            .setItem(_getKey(namespace, entry.key, managerId), entry.value);
      }
    } else {
      await Future.wait(
        values.entries.map(
          (entry) => _prefs.setString(
            _getKey(namespace, entry.key, managerId),
            entry.value,
          ),
        ),
      );
    }
  }

  Future<void> _defaultRemoveMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    if (testIsWeb) {
      for (final key in keys) {
        html.window.localStorage.removeItem(_getKey(namespace, key, managerId));
      }
    } else {
      await Future.wait(
        keys.map(
          (key) => _prefs.remove(_getKey(namespace, key, managerId)),
        ),
      );
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
        // optimally we would make these operations concurrent, but due to this issue we can't.
        // see https://github.com/mogol/flutter_secure_storage/issues/381#issuecomment-1128636818
        try {
          // secure storage might not be supported in all platforms,
          // so we fallback to normal storage if that's the case.
          if (secureStorage case final secureStorage?) {
            final res = <String, String>{};
            for (final k in keys) {
              final v = await secureStorage.read(
                key: _getKey(namespace, k, managerId),
              );
              if (v != null) {
                res[k] = v;
              }
            }
            return res;
          } else {
            _warnInsecureSecureTokensFallback();
            return _defaultGetMany(namespace, keys, managerId);
          }
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried reading secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to using package:shared_pereferences, which is not secure.');
          return _defaultGetMany(namespace, keys, managerId);
          // coverage:ignore-end
        }
      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          return keys
              .map(
                (key) => MapEntry(
                  key,
                  html.window.sessionStorage
                      .getItem(_getKey(namespace, key, managerId)),
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
        try {
          if (secureStorage case final secureStorage?) {
            for (final entry in values.entries) {
              await secureStorage.write(
                key: _getKey(namespace, entry.key, managerId),
                value: entry.value,
              );
            }
          } else {
            _warnInsecureSecureTokensFallback();
            return _defaultSetMany(namespace, values, managerId);
          }
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried writing secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to using package:shared_pereferences, which is not secure.');
          return _defaultSetMany(namespace, values, managerId);
          // coverage:ignore-end
        }

      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          for (final element in values.entries) {
            html.window.sessionStorage.setItem(
              _getKey(namespace, element.key, managerId),
              element.value,
            );
          }
        } else {
          await _defaultSetMany(namespace, values, managerId);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.stateResponse:
      case OidcStoreNamespace.discoveryDocument:
        await _defaultSetMany(namespace, values, managerId);
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
        try {
          if (secureStorage case final secureStorage?) {
            for (final key in keys) {
              await secureStorage.delete(
                key: _getKey(namespace, key, managerId),
              );
            }
          } else {
            _warnInsecureSecureTokensFallback();
            await _defaultRemoveMany(namespace, keys, managerId);
          }
        } catch (e) {
          // coverage:ignore-start
          _logger.warning(
              'tried removing secure tokens using package:flutter_secure_storage,'
              ' but it failed, falling back to reading using package:shared_pereferences, which is not secure.');
          await _defaultRemoveMany(namespace, keys, managerId);
          // coverage:ignore-end
        }
      case OidcStoreNamespace.session:
        if (testIsWeb &&
            webSessionManagementLocation ==
                OidcDefaultStoreWebSessionManagementLocation.sessionStorage) {
          for (final element in keys) {
            html.window.sessionStorage
                .removeItem(_getKey(namespace, element, managerId));
          }
        } else {
          await _defaultRemoveMany(namespace, keys, managerId);
        }
      case OidcStoreNamespace.request:
      case OidcStoreNamespace.state:
      case OidcStoreNamespace.discoveryDocument:
      case OidcStoreNamespace.stateResponse:
        await _defaultRemoveMany(namespace, keys, managerId);
    }
  }
}

extension on Iterable<MapEntry<String, String?>> {
  Map<String, String> purify() {
    return Map.fromEntries(where((element) => element.value != null))
        .cast<String, String>();
  }
}

/// Minimal async persistence surface shared by the legacy [SharedPreferences]
/// and the modern [SharedPreferencesAsync] backends, so the rest of
/// [OidcDefaultStore] can stay backend-agnostic (see issue #301).
abstract class _OidcPrefsBackend {
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Adapts the deprecated synchronous [SharedPreferences] to
/// [_OidcPrefsBackend]. Kept for backward compatibility with the deprecated
/// `sharedPreferences` constructor parameter.
class _OidcLegacyPrefsBackend implements _OidcPrefsBackend {
  _OidcLegacyPrefsBackend(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _prefs.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Adapts [SharedPreferencesAsync] (the default, non-legacy backend) to
/// [_OidcPrefsBackend].
class _OidcAsyncPrefsBackend implements _OidcPrefsBackend {
  _OidcAsyncPrefsBackend(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<List<String>?> getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
