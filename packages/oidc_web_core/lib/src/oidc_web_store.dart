import 'dart:convert';

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/src/oidc_web_crypto.dart';
import 'package:web/web.dart';

/// where to store the values when using the [OidcStoreNamespace.session] namespace.
enum OidcWebStoreSessionManagementLocation {
  /// sessionStorage
  sessionStorage,

  /// localStorage
  localStorage,
}

/// controls how [OidcWebStore] handles encrypting the
/// [OidcStoreNamespace.secureTokens] namespace at rest.
///
/// See [OidcWebStore] for the full threat model: this is defense-in-depth
/// against disk/backup scraping and casual inspection, **not** protection
/// against XSS.
enum OidcWebStoreEncryption {
  /// Encrypt `secureTokens` (AES-GCM via WebCrypto, key in IndexedDB) when
  /// possible.
  ///
  /// If WebCrypto or IndexedDB are unavailable (a non-secure-context origin,
  /// or IndexedDB disabled/ephemeral in some private-browsing modes), falls
  /// back to the previous plaintext-in-`localStorage` behavior, logging a
  /// one-shot warning naming exactly what is insecure and why. This is the
  /// default, and preserves backward compatibility: the package keeps
  /// working in every context it worked in before.
  preferred,

  /// Encrypt `secureTokens`, or throw an [OidcException] instead of ever
  /// writing plaintext.
  ///
  /// Opt-in, for deployments that would rather fail loudly than persist an
  /// unencrypted token.
  required,
}

/// {@template oidc_web_store}
/// an implementation of OidcStore for web that doesn't depend on flutter
///
/// ## Encryption at rest (`secureTokens`)
///
/// The [OidcStoreNamespace.secureTokens] namespace (access/refresh/id
/// tokens and the OIDC nonce) is encrypted at rest by default: AES-GCM via
/// WebCrypto, with a non-extractable key persisted in IndexedDB and a fresh
/// random IV per write. See [OidcWebStoreEncryption] to opt into a hard
/// failure instead of the default plaintext fallback when WebCrypto/
/// IndexedDB are unavailable.
///
/// **This is defense-in-depth against disk/backup scraping and casual
/// inspection (e.g. DevTools, a copied browser profile) -- it is NOT
/// protection against XSS.** A script running in this page's own origin can
/// call the exact same `crypto.subtle.decrypt`, or more simply just read
/// tokens back out through the `OidcStore` API after this code decrypts
/// them; a non-extractable key stops the raw key bytes from ever leaving
/// the browser, but doesn't stop same-origin `decrypt()` calls. Harden
/// against XSS itself (CSP, trusted types, dependency hygiene) and prefer a
/// BFF (tokens behind HttpOnly cookies) for high-value applications.
///
/// Values written before this feature existed (or written by the
/// [OidcWebStoreEncryption.preferred] fallback) are read back correctly:
/// [getMany] transparently reads through legacy plaintext, and the next
/// [setMany] for that key re-writes it encrypted. This migration is
/// forward-only: downgrading to an `oidc_web_core` version predating this
/// feature will see encrypted values as opaque strings.
/// {@endtemplate}
class OidcWebStore implements OidcStore {
  /// {@macro oidc_web_store}

  /// {@macro oidc_default_store}
  const OidcWebStore({
    this.storagePrefix = 'oidc',
    this.webSessionManagementLocation =
        OidcWebStoreSessionManagementLocation.sessionStorage,
    this.encryption = OidcWebStoreEncryption.preferred,
  });

  /// prefix to put before the keys.
  ///
  /// by default this is `oidc`
  final String? storagePrefix;

  /// if true, we use the `sessionStorage` on web for the [OidcStoreNamespace.session] namespace.
  final OidcWebStoreSessionManagementLocation webSessionManagementLocation;

  /// controls how the [OidcStoreNamespace.secureTokens] namespace is
  /// encrypted at rest. Defaults to [OidcWebStoreEncryption.preferred].
  final OidcWebStoreEncryption encryption;

  /// the record key used to look up (and, if absent, generate) this store's
  /// `secureTokens` encryption key in [OidcWebCrypto].
  String get _cryptoRecordKey => storagePrefix ?? 'oidc';

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
  Future<void> init() async {
    // Best-effort warm-up of the secureTokens encryption key so the
    // IndexedDB round trip doesn't land on the first token read/write.
    // Never throws: unavailability is handled lazily by getMany/setMany
    // (warn-once + plaintext fallback, or a required hard-fail).
    await OidcWebCrypto.warmUpKey(_cryptoRecordKey);
  }

  Future<void> _registerKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    // Read from the SAME per-manager bucket `_setAllKeys` writes to (keyed by
    // managerId); reading the default bucket corrupted per-manager key cleanup.
    final prev = await getAllKeys(namespace, managerId: managerId);
    final newKeys = prev.union(keys).toList();
    await _setAllKeys(namespace, newKeys, managerId);
  }

  Future<void> _unRegisterKeyForNamespace(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    // Read from the SAME per-manager bucket `_setAllKeys` writes to (keyed by
    // managerId); reading the default bucket corrupted per-manager key cleanup.
    final prev = await getAllKeys(namespace, managerId: managerId);
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

  /// [OidcStoreNamespace.secureTokens] read path: reads the raw stored
  /// strings (same as [_defaultGetMany]), then for each value either
  /// decrypts it (if it's an [OidcWebCrypto.isEncryptedEnvelope] envelope)
  /// or reads it through as-is (legacy plaintext, written before this
  /// feature existed or by the [OidcWebStoreEncryption.preferred] fallback).
  ///
  /// A value that fails to decrypt (wrong/rotated key, corrupt data) is
  /// dropped from the result -- a miss, never a throw.
  Future<Map<String, String>> _secureGetMany(
    OidcStoreNamespace namespace,
    Set<String> keys,
    String? managerId,
  ) async {
    final raw = await _defaultGetMany(namespace, keys, managerId);
    final result = <String, String>{};
    for (final entry in raw.entries) {
      if (OidcWebCrypto.isEncryptedEnvelope(entry.value)) {
        final plain = await OidcWebCrypto.decryptEnvelope(
          entry.value,
          recordKey: _cryptoRecordKey,
        );
        if (plain != null) {
          result[entry.key] = plain;
        }
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// [OidcStoreNamespace.secureTokens] write path: encrypts every value in
  /// [values] and writes the whole batch as ciphertext envelopes.
  ///
  /// If encryption is unavailable (WebCrypto/IndexedDB missing) or fails,
  /// the batch is written as plaintext instead -- unless [encryption] is
  /// [OidcWebStoreEncryption.required], in which case nothing is written and
  /// an [OidcException] is thrown. Either way this is an all-or-nothing
  /// decision per call: encryption availability is a single memoized
  /// per-[storagePrefix] outcome, not something that can differ key-by-key
  /// within one batch.
  Future<void> _secureSetMany(
    OidcStoreNamespace namespace,
    Map<String, String> values,
    String? managerId,
  ) async {
    final encrypted = <String, String>{};
    for (final entry in values.entries) {
      final envelope = await OidcWebCrypto.encrypt(
        entry.value,
        recordKey: _cryptoRecordKey,
      );
      if (envelope == null) {
        if (encryption == OidcWebStoreEncryption.required) {
          throw OidcException(
            'OidcWebStore: secureTokens encryption is required '
            '(OidcWebStoreEncryption.required) but WebCrypto/IndexedDB are '
            'unavailable for storagePrefix "$_cryptoRecordKey".',
          );
        }
        OidcWebCrypto.warnInsecureFallbackOnce(_cryptoRecordKey);
        _defaultSetMany(namespace, values, managerId);
        return;
      }
      encrypted[entry.key] = envelope;
    }
    _defaultSetMany(namespace, encrypted, managerId);
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    switch (namespace) {
      case OidcStoreNamespace.secureTokens:
        return _secureGetMany(namespace, keys, managerId);
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
        return _secureSetMany(namespace, values, managerId);

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
        // Encryption is transparent to removal: deleting a key doesn't
        // depend on whether its stored value is an `oidcenc.v1.` envelope
        // or legacy plaintext.
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
