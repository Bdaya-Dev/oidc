@TestOn('js')
library;

// ignore_for_file: prefer_const_constructors

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:oidc_web_core/src/oidc_web_crypto.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Flips a single character of a base64url segment, keeping it a
/// well-formed base64url string (so decoding still succeeds) but changing
/// the underlying bytes -- used to simulate a corrupted/tampered ciphertext
/// (GCM auth-tag mismatch) rather than a malformed envelope.
String _tamperBase64Url(String segment) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final chars = segment.split('');
  final index = chars.lastIndexWhere((c) => c != '=');
  final current = chars[index];
  final replacement =
      alphabet[(alphabet.indexOf(current) + 1) % alphabet.length];
  chars[index] = replacement;
  return chars.join();
}

void main() {
  setUp(() {
    web.window.localStorage.clear();
    OidcWebCrypto.debugReset();
  });

  group('OidcWebStore secureTokens encryption at rest', () {
    test('round-trips a value through setMany/getMany', () async {
      const store = OidcWebStore(storagePrefix: 'roundtrip');
      await store.init();

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'access_token': 'super-secret-token-value'},
      );
      final result = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'access_token'},
      );

      expect(result['access_token'], 'super-secret-token-value');
    });

    test(
      'persists ciphertext (an oidcenc.v1. envelope), not plaintext',
      () async {
        const store = OidcWebStore(storagePrefix: 'ciphertext');
        await store.init();
        const plaintext = 'super-secret-token-value';

        await store.setMany(
          OidcStoreNamespace.secureTokens,
          values: {'access_token': plaintext},
        );

        final raw = web.window.localStorage.getItem(
          'ciphertext.secureTokens.access_token',
        );
        expect(raw, isNotNull);
        expect(raw, startsWith(oidcWebCryptoEnvelopePrefixV1));
        expect(raw, isNot(contains(plaintext)));
      },
    );

    test('uses a fresh random IV per write', () async {
      const store = OidcWebStore(storagePrefix: 'ivunique');
      await store.init();
      const rawKey = 'ivunique.secureTokens.k';

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'k': 'same-value'},
      );
      final first = web.window.localStorage.getItem(rawKey);

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'k': 'same-value'},
      );
      final second = web.window.localStorage.getItem(rawKey);

      expect(first, isNotNull);
      expect(second, isNotNull);
      // Same plaintext, same key -> different envelopes (different IVs).
      expect(first, isNot(equals(second)));

      final result = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'k'},
      );
      expect(result['k'], 'same-value');
    });

    test('reads a legacy plaintext value through, then upgrades it to an '
        'envelope on the next write', () async {
      const store = OidcWebStore(storagePrefix: 'legacy');
      await store.init();
      const rawKey = 'legacy.secureTokens.refresh_token';

      // Simulate a value written before this feature existed.
      web.window.localStorage.setItem(rawKey, 'legacy-plaintext-value');

      final readBefore = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'refresh_token'},
      );
      expect(readBefore['refresh_token'], 'legacy-plaintext-value');
      // Reading doesn't rewrite -- still plaintext on disk.
      expect(web.window.localStorage.getItem(rawKey), 'legacy-plaintext-value');

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'refresh_token': 'legacy-plaintext-value'},
      );

      final rawAfter = web.window.localStorage.getItem(rawKey);
      expect(rawAfter, startsWith(oidcWebCryptoEnvelopePrefixV1));

      final readAfter = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'refresh_token'},
      );
      expect(readAfter['refresh_token'], 'legacy-plaintext-value');
    });

    test('a tampered envelope (bad GCM auth tag) is treated as a miss, not a '
        'throw', () async {
      const store = OidcWebStore(storagePrefix: 'corrupt');
      await store.init();
      const rawKey = 'corrupt.secureTokens.k';

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'k': 'value'},
      );
      final original = web.window.localStorage.getItem(rawKey)!;
      final parts = original
          .substring(oidcWebCryptoEnvelopePrefixV1.length)
          .split('.');
      final tampered =
          '$oidcWebCryptoEnvelopePrefixV1'
          '${parts[0]}.${_tamperBase64Url(parts[1])}';
      web.window.localStorage.setItem(rawKey, tampered);

      final result = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'k'},
      );

      expect(result.containsKey('k'), isFalse);
    });

    test('removeMany deletes the stored value', () async {
      const store = OidcWebStore(storagePrefix: 'remove');
      await store.init();

      await store.setMany(OidcStoreNamespace.secureTokens, values: {'k': 'v'});
      expect(
        web.window.localStorage.getItem('remove.secureTokens.k'),
        isNotNull,
      );

      await store.removeMany(OidcStoreNamespace.secureTokens, keys: {'k'});

      expect(web.window.localStorage.getItem('remove.secureTokens.k'), isNull);
      final result = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'k'},
      );
      expect(result.containsKey('k'), isFalse);
    });

    test('non-secureTokens namespaces (e.g. state) remain plaintext '
        '(regression guard)', () async {
      const store = OidcWebStore(storagePrefix: 'plain');
      await store.init();

      await store.setMany(
        OidcStoreNamespace.state,
        values: {'s': 'state-value'},
      );

      final raw = web.window.localStorage.getItem('plain.state.s');
      expect(raw, 'state-value');
    });
  });

  group(
    'OidcWebStore session namespace (sessionStorage location, default)',
    () {
      test(
        'setMany/getMany/removeMany round-trip through window.sessionStorage',
        () async {
          const store = OidcWebStore(storagePrefix: 'session-default');
          await store.init();

          await store.setMany(
            OidcStoreNamespace.session,
            values: {'sid': 'abc123'},
          );

          // Written to sessionStorage, NOT localStorage.
          expect(
            web.window.sessionStorage.getItem('session-default.session.sid'),
            'abc123',
          );
          expect(
            web.window.localStorage.getItem('session-default.session.sid'),
            isNull,
          );

          final result = await store.getMany(
            OidcStoreNamespace.session,
            keys: {'sid'},
          );
          expect(result['sid'], 'abc123');

          await store.removeMany(OidcStoreNamespace.session, keys: {'sid'});
          expect(
            web.window.sessionStorage.getItem('session-default.session.sid'),
            isNull,
          );
          final afterRemove = await store.getMany(
            OidcStoreNamespace.session,
            keys: {'sid'},
          );
          expect(afterRemove.containsKey('sid'), isFalse);
        },
      );

      test('a missing session key is simply absent from getMany', () async {
        const store = OidcWebStore(storagePrefix: 'session-missing');
        await store.init();

        final result = await store.getMany(
          OidcStoreNamespace.session,
          keys: {'nope'},
        );
        expect(result.containsKey('nope'), isFalse);
      });
    },
  );

  group('OidcWebStore session namespace (localStorage location)', () {
    test('setMany/getMany/removeMany round-trip through window.localStorage '
        'instead of sessionStorage', () async {
      const store = OidcWebStore(
        storagePrefix: 'session-local',
        webSessionManagementLocation:
            OidcWebStoreSessionManagementLocation.localStorage,
      );
      await store.init();

      await store.setMany(
        OidcStoreNamespace.session,
        values: {'sid': 'xyz789'},
      );

      expect(
        web.window.localStorage.getItem('session-local.session.sid'),
        'xyz789',
      );
      expect(
        web.window.sessionStorage.getItem('session-local.session.sid'),
        isNull,
      );

      final result = await store.getMany(
        OidcStoreNamespace.session,
        keys: {'sid'},
      );
      expect(result['sid'], 'xyz789');

      await store.removeMany(OidcStoreNamespace.session, keys: {'sid'});
      expect(
        web.window.localStorage.getItem('session-local.session.sid'),
        isNull,
      );
    });
  });

  group('when WebCrypto/IndexedDB are unavailable', () {
    test('OidcWebStoreEncryption.preferred falls back to a warned plaintext '
        'write', () async {
      const store = OidcWebStore(storagePrefix: 'fallback-preferred');
      OidcWebCrypto.debugForceUnavailable = true;
      await store.init();

      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {'k': 'plain-fallback-value'},
      );

      final raw = web.window.localStorage.getItem(
        'fallback-preferred.secureTokens.k',
      );
      expect(raw, 'plain-fallback-value');

      final result = await store.getMany(
        OidcStoreNamespace.secureTokens,
        keys: {'k'},
      );
      expect(result['k'], 'plain-fallback-value');
    });

    test(
      'OidcWebStoreEncryption.required throws instead of writing plaintext',
      () async {
        const store = OidcWebStore(
          storagePrefix: 'fallback-required',
          encryption: OidcWebStoreEncryption.required,
        );
        OidcWebCrypto.debugForceUnavailable = true;
        await store.init();

        await expectLater(
          store.setMany(
            OidcStoreNamespace.secureTokens,
            values: {'k': 'value'},
          ),
          throwsA(isA<OidcException>()),
        );

        expect(
          web.window.localStorage.getItem('fallback-required.secureTokens.k'),
          isNull,
        );
      },
    );
  });
}
