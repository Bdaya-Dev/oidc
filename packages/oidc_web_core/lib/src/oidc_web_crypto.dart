import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

// coverage:ignore-line
final _logger = Logger('Oidc.WebStore.Crypto');

/// The literal prefix (scheme + version) that identifies an
/// [OidcWebCrypto]-encrypted envelope, as opposed to a legacy plaintext
/// value.
///
/// See the `oidc_web_core` design proposal for audit #324 item 15:
/// `oidcenc.<version>.<iv-b64url>.<ciphertext-b64url>`.
const oidcWebCryptoEnvelopePrefixV1 = 'oidcenc.v1.';

const _dbName = 'oidc_web_core';
const _cryptoKeysStoreName = 'crypto_keys';
const _algorithmName = 'AES-GCM';
const _keyLengthBits = 256;
const _ivLengthBytes = 12;

/// AES-GCM key-generation parameters.
///
/// `package:web` doesn't model WebCrypto's algorithm-specific dictionaries
/// (there is no generated `AesKeyGenParams`), so this mirrors the pattern
/// already used by the same package's own generated dictionaries (e.g.
/// `JsonWebKey`, `RsaOtherPrimesInfo` in `webcryptoapi.dart`): a tiny
/// `extension type` with an `external factory` to build the JS object
/// literal `crypto.subtle.generateKey` expects.
extension type _AesKeyGenParams._(JSObject _) implements JSObject {
  external factory _AesKeyGenParams({String name, int length});
}

/// AES-GCM encrypt/decrypt parameters (`{name, iv}`). See [_AesKeyGenParams].
extension type _AesGcmParams._(JSObject _) implements JSObject {
  external factory _AesGcmParams({String name, JSUint8Array iv});
}

/// A decoded `oidcenc.v1.` envelope: the random IV used for the write, and
/// the AES-GCM ciphertext (which already includes the appended auth tag).
class _DecodedEnvelope {
  const _DecodedEnvelope(this.iv, this.ciphertext);

  final Uint8List iv;
  final Uint8List ciphertext;
}

/// {@template oidc_web_crypto}
/// Implements at-rest encryption for the `secureTokens` namespace of
/// `OidcWebStore`, per audit #324 item 15's design proposal:
///
/// - a non-extractable AES-GCM 256-bit `CryptoKey`, generated once per
///   `storagePrefix` and persisted as a structured-clone `CryptoKey` object
///   (never its raw bytes) in an IndexedDB object store;
/// - a versioned envelope, `oidcenc.v1.<iv-b64url>.<ciphertext-b64url>`, with
///   a fresh random 12-byte IV per write;
/// - loud, once-per-prefix logging (never a silent downgrade) when
///   WebCrypto/IndexedDB are unavailable.
///
/// **Threat model (read this before assuming more than it provides):**
/// this raises the bar against disk/backup scraping and casual inspection
/// (e.g. DevTools, a copied browser profile). It is **not** protection
/// against XSS: a script running in the page's own origin can call the same
/// `crypto.subtle.decrypt` (or just read decrypted values back out of
/// `OidcStore`) that this code does. A non-extractable key stops the raw key
/// bytes from ever leaving the browser, but does not stop `decrypt()` calls
/// made by same-origin script. Harden against XSS itself (CSP, trusted
/// types, dependency hygiene) and prefer a BFF for high-value applications.
///
/// This class is intentionally **not** exported from `package:oidc_web_core`
/// -- it's an internal implementation detail of `OidcWebStore`, reachable
/// from tests via its `lib/src/` import path only.
/// {@endtemplate}
class OidcWebCrypto {
  const OidcWebCrypto._();

  /// Set (only) by tests to force the "WebCrypto/IndexedDB unavailable"
  /// fallback path.
  ///
  /// There is no supported way to make a real headless-browser test runner
  /// (which DOES expose `window.crypto.subtle` and `window.indexedDB` on a
  /// secure `http://localhost` context) actually lack these APIs: both are
  /// non-configurable accessors on the real `Window`/`Crypto` prototypes, so
  /// they can't be deleted or stubbed out from Dart via js-interop. This
  /// boolean escape hatch mirrors `OidcDefaultStore.testIsWeb` and is the
  /// only implementable version of the two testing seams the design
  /// proposal offered for this branch.
  @visibleForTesting
  static bool debugForceUnavailable = false;

  static final Map<String, Future<web.CryptoKey?>> _keyFutures = {};

  static final Set<String> _warnedRecordKeys = {};

  /// Clears all memoized keys/flags. Call from `setUp`/`tearDown` between
  /// tests that exercise [debugForceUnavailable] or rely on a fresh
  /// warn-once state, so one test can't leak state into the next.
  @visibleForTesting
  static void debugReset() {
    _keyFutures.clear();
    _warnedRecordKeys.clear();
    debugForceUnavailable = false;
  }

  /// True if [raw] looks like an [oidcWebCryptoEnvelopePrefixV1] envelope
  /// produced by [encrypt], as opposed to a legacy (or fallback-written)
  /// plaintext value.
  ///
  /// A real token/JSON value can never collide with this prefix (JWTs start
  /// with `eyJ`, JSON starts with `{`), and even a false positive is safe:
  /// [decryptEnvelope] treats anything it can't decrypt as a miss rather
  /// than throwing or returning corrupted data.
  static bool isEncryptedEnvelope(String raw) =>
      raw.startsWith(oidcWebCryptoEnvelopePrefixV1);

  /// Best-effort warm-up of the encryption key for [recordKey] (normally the
  /// store's `storagePrefix`), so the first real `getMany`/`setMany` call
  /// doesn't pay the IndexedDB round trip. Never throws: unavailability is
  /// surfaced lazily by [encrypt]/[decryptEnvelope] returning `null`.
  static Future<void> warmUpKey(String recordKey) async {
    await _ensureKey(recordKey);
  }

  /// Encrypts [plaintext] under the key for [recordKey] and returns the
  /// encoded `oidcenc.v1.` envelope, or `null` if WebCrypto/IndexedDB are
  /// unavailable or the operation otherwise failed. Never throws.
  static Future<String?> encrypt(
    String plaintext, {
    required String recordKey,
  }) async {
    final key = await _ensureKey(recordKey);
    if (key == null) {
      return null;
    }
    try {
      final iv = _randomIv();
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext)).toJS;
      final cipherResult = await web.window.crypto.subtle
          .encrypt(
            _AesGcmParams(name: _algorithmName, iv: iv.toJS),
            key,
            plaintextBytes,
          )
          .toDart;
      final cipherBytes = (cipherResult! as JSArrayBuffer).toDart.asUint8List();
      return '$oidcWebCryptoEnvelopePrefixV1'
          '${base64Url.encode(iv)}.${base64Url.encode(cipherBytes)}';
    } catch (e, st) {
      _logger.warning(
        'OidcWebStore: failed to encrypt a secureTokens value even though '
        'the encryption key was available; treating as unavailable for this '
        'write.',
        e,
        st,
      );
      return null;
    }
  }

  /// Decrypts an [envelope] (an [isEncryptedEnvelope]-true string) under the
  /// key for [recordKey]. Returns `null` (a miss, never a throw) if the
  /// envelope is malformed, the key is unavailable, or decryption fails
  /// (wrong/rotated key, corrupted data -- the GCM auth tag mismatches).
  static Future<String?> decryptEnvelope(
    String envelope, {
    required String recordKey,
  }) async {
    final decoded = _tryDecodeEnvelope(envelope);
    if (decoded == null) {
      return null;
    }
    final key = await _ensureKey(recordKey);
    if (key == null) {
      return null;
    }
    try {
      final plainResult = await web.window.crypto.subtle
          .decrypt(
            _AesGcmParams(name: _algorithmName, iv: decoded.iv.toJS),
            key,
            decoded.ciphertext.toJS,
          )
          .toDart;
      final plainBytes = (plainResult! as JSArrayBuffer).toDart.asUint8List();
      return utf8.decode(plainBytes);
    } catch (e, st) {
      _logger.fine(
        'OidcWebStore: failed to decrypt a secureTokens envelope (bad tag, '
        'rotated/evicted key, or corrupt data); treating it as a miss '
        'rather than throwing.',
        e,
        st,
      );
      return null;
    }
  }

  /// Logs (once per [recordKey]) that `secureTokens` is being persisted
  /// UNENCRYPTED because WebCrypto/IndexedDB were unavailable, mirroring
  /// `OidcDefaultStore`'s `_warnInsecureSecureTokensFallback`.
  static void warnInsecureFallbackOnce(String recordKey) {
    if (!_warnedRecordKeys.add(recordKey)) {
      return;
    }
    _logger.warning(
      'OidcWebStore: WebCrypto/IndexedDB unavailable -- secureTokens '
      '(access/refresh/id tokens and the OIDC nonce, storagePrefix '
      '"$recordKey") is persisted UNENCRYPTED in localStorage. This can '
      'happen on a non-secure-context (plain http://) origin, or when '
      'IndexedDB is disabled/ephemeral (some private-browsing modes). '
      'Encryption at rest is defense-in-depth against disk/backup scraping, '
      'not XSS protection either way -- harden against XSS (CSP, trusted '
      'types) and prefer a BFF for high-value applications.',
    );
  }

  static Future<web.CryptoKey?> _ensureKey(String recordKey) {
    // `Map.putIfAbsent` synchronously reserves the entry on first call, so
    // concurrent callers in the same event-loop turn all await the SAME
    // future instead of racing separate `generateKey`/`put` calls. This is
    // a dependency-free equivalent of `AsyncMemoizer` (the design proposal's
    // suggested mirror of `OidcDefaultStore`) -- `package:async` isn't a
    // dependency of `oidc_web_core`, and the proposal explicitly promises no
    // new dependencies for this feature.
    return _keyFutures.putIfAbsent(
      recordKey,
      () => _loadOrCreateKey(recordKey),
    );
  }

  static Future<web.CryptoKey?> _loadOrCreateKey(String recordKey) async {
    if (debugForceUnavailable) {
      return null;
    }
    try {
      final db = await _openDatabase();
      try {
        // IndexedDB transactions auto-commit as soon as control returns to
        // the event loop with no request pending on them, so a transaction
        // must never be held across a non-IndexedDB await. Firefox enforces
        // this strictly: reusing the read transaction for the write after
        // awaiting `generateKey` throws TransactionInactiveError (which made
        // the store fall back to writing secureTokens as PLAINTEXT on every
        // Firefox session). Chrome merely happened not to trip the
        // auto-commit. One transaction per await-separated operation.
        final readStore = db
            .transaction(_cryptoKeysStoreName.toJS, 'readonly')
            .objectStore(_cryptoKeysStoreName);
        final existing = await _requestResult(readStore.get(recordKey.toJS));
        if (existing != null) {
          _requestPersistBestEffort();
          return existing as web.CryptoKey;
        }
        final generated = await _generateKey();
        final writeStore = db
            .transaction(_cryptoKeysStoreName.toJS, 'readwrite')
            .objectStore(_cryptoKeysStoreName);
        try {
          // `add` (not `put`): fails with ConstraintError if another
          // same-origin context (tab, iframe) won the generate race between
          // our read and this write. Overwriting with `put` would leave the
          // two contexts encrypting under DIFFERENT keys, each unable to
          // decrypt the other's values on the next load.
          await _requestResult(writeStore.add(generated, recordKey.toJS));
        } catch (_) {
          final rereadStore = db
              .transaction(_cryptoKeysStoreName.toJS, 'readonly')
              .objectStore(_cryptoKeysStoreName);
          final winner = await _requestResult(rereadStore.get(recordKey.toJS));
          if (winner == null) {
            rethrow;
          }
          _requestPersistBestEffort();
          return winner as web.CryptoKey;
        }
        _requestPersistBestEffort();
        return generated;
      } finally {
        db.close();
      }
    } catch (e, st) {
      _logger.warning(
        'OidcWebStore: WebCrypto/IndexedDB are unavailable while acquiring '
        'the secureTokens encryption key for storagePrefix "$recordKey".',
        e,
        st,
      );
      return null;
    }
  }

  static Future<web.CryptoKey> _generateKey() async {
    final result = await web.window.crypto.subtle
        .generateKey(
          _AesKeyGenParams(name: _algorithmName, length: _keyLengthBits),
          // extractable: false -- the raw key bytes can never be exported
          // back out to JS via exportKey()/wrapKey(). This is the crux of
          // the design: even a full-origin XSS that calls decrypt() can't
          // exfiltrate the key material itself for offline use.
          false,
          <JSString>['encrypt'.toJS, 'decrypt'.toJS].toJS,
        )
        .toDart;
    return result! as web.CryptoKey;
  }

  static Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    late final web.IDBOpenDBRequest request;
    request = web.window.indexedDB.open(_dbName, 1)
      ..onupgradeneeded = ((web.Event _) {
        final db = request.result! as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_cryptoKeysStoreName)) {
          db.createObjectStore(_cryptoKeysStoreName);
        }
      }).toJS
      ..onsuccess = ((web.Event _) {
        completer.complete(request.result! as web.IDBDatabase);
      }).toJS
      ..onerror = ((web.Event _) {
        completer.completeError(
          request.error ?? StateError('Failed to open IndexedDB "$_dbName"'),
        );
      }).toJS;
    return completer.future;
  }

  static Future<JSAny?> _requestResult(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request
      ..onsuccess = ((web.Event _) {
        completer.complete(request.result);
      }).toJS
      ..onerror = ((web.Event _) {
        completer.completeError(
          request.error ?? StateError('IndexedDB request failed'),
        );
      }).toJS;
    return completer.future;
  }

  /// Best-effort `navigator.storage.persist()` request, so the origin's
  /// storage (including this key) is less likely to be evicted under
  /// pressure. Failures here must never fail key acquisition -- this is
  /// pure hardening, not a correctness requirement (see the design
  /// proposal's persistence/eviction trade-off section).
  ///
  /// Fire-and-forget by contract: Firefox surfaces `persist()` as a
  /// permission doorhanger and the returned promise stays PENDING until the
  /// user answers it -- in headless/CI (and for any user who ignores the
  /// prompt) that is forever, so `await`ing it wedges key acquisition.
  /// Nothing may ever await this.
  static void _requestPersistBestEffort() {
    try {
      unawaited(
        web.window.navigator.storage.persist().toDart.then(
          (_) {},
          onError: (Object _) {},
        ),
      );
    } catch (_) {
      // Not all browsers/contexts implement the Storage Manager API; a
      // failure here just means we didn't get the (best-effort) hardening.
    }
  }

  static Uint8List _randomIv() {
    final jsBytes = Uint8List(_ivLengthBytes).toJS;
    web.window.crypto.getRandomValues(jsBytes);
    return jsBytes.toDart;
  }

  static _DecodedEnvelope? _tryDecodeEnvelope(String raw) {
    if (!raw.startsWith(oidcWebCryptoEnvelopePrefixV1)) {
      return null;
    }
    final rest = raw.substring(oidcWebCryptoEnvelopePrefixV1.length);
    final parts = rest.split('.');
    if (parts.length != 2) {
      return null;
    }
    try {
      return _DecodedEnvelope(
        base64Url.decode(parts[0]),
        base64Url.decode(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }
}
