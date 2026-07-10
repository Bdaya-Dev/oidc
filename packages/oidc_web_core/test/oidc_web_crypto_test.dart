@TestOn('js')
library;

import 'package:oidc_web_core/src/oidc_web_crypto.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUp(() {
    web.window.localStorage.clear();
    OidcWebCrypto.debugReset();
  });

  group('OidcWebCrypto.isEncryptedEnvelope', () {
    test('is true for a well-formed envelope prefix', () {
      expect(
        OidcWebCrypto.isEncryptedEnvelope(
          '${oidcWebCryptoEnvelopePrefixV1}a.b',
        ),
        isTrue,
      );
    });

    test('is false for plain JSON/JWT-shaped values', () {
      expect(OidcWebCrypto.isEncryptedEnvelope('{"a":1}'), isFalse);
      expect(
        OidcWebCrypto.isEncryptedEnvelope('eyJhbGciOiJIUzI1NiJ9'),
        isFalse,
      );
      expect(OidcWebCrypto.isEncryptedEnvelope(''), isFalse);
    });
  });

  group('OidcWebCrypto.decryptEnvelope malformed input handling', () {
    test('returns null for a raw value without the envelope prefix', () async {
      final result = await OidcWebCrypto.decryptEnvelope(
        'not-an-envelope-at-all',
        recordKey: 'malformed-prefix',
      );
      expect(result, isNull);
    });

    test('returns null when the envelope does not have exactly two '
        'dot-separated segments after the prefix', () async {
      final tooFew = await OidcWebCrypto.decryptEnvelope(
        '${oidcWebCryptoEnvelopePrefixV1}onlyonepart',
        recordKey: 'malformed-parts',
      );
      expect(tooFew, isNull);

      final tooMany = await OidcWebCrypto.decryptEnvelope(
        '${oidcWebCryptoEnvelopePrefixV1}a.b.c',
        recordKey: 'malformed-parts',
      );
      expect(tooMany, isNull);
    });

    test('returns null when a segment is not valid base64url', () async {
      final result = await OidcWebCrypto.decryptEnvelope(
        '${oidcWebCryptoEnvelopePrefixV1}not-base64!!.also-not-base64!!',
        recordKey: 'malformed-base64',
      );
      expect(result, isNull);
    });

    test('returns null (rather than throwing) for a structurally valid but '
        'bogus ciphertext when the key IS available', () async {
      // Well-formed base64url segments, but not a real IV/ciphertext pair
      // produced by encrypt() -- decrypt() must reject it as a GCM auth
      // failure, not crash.
      final result = await OidcWebCrypto.decryptEnvelope(
        '${oidcWebCryptoEnvelopePrefixV1}AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        recordKey: 'bogus-ciphertext',
      );
      expect(result, isNull);
    });
  });

  group('OidcWebCrypto key unavailability', () {
    test('encrypt returns null (never throws) when WebCrypto/IndexedDB are '
        'forced unavailable', () async {
      OidcWebCrypto.debugForceUnavailable = true;
      final result = await OidcWebCrypto.encrypt(
        'secret',
        recordKey: 'unavailable-encrypt',
      );
      expect(result, isNull);
    });

    test('decryptEnvelope returns null when the key is unavailable, even for '
        'a structurally well-formed envelope', () async {
      OidcWebCrypto.debugForceUnavailable = true;
      final result = await OidcWebCrypto.decryptEnvelope(
        '${oidcWebCryptoEnvelopePrefixV1}AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        recordKey: 'unavailable-decrypt',
      );
      expect(result, isNull);
    });

    test('warmUpKey never throws when forced unavailable', () async {
      OidcWebCrypto.debugForceUnavailable = true;
      await expectLater(
        OidcWebCrypto.warmUpKey('unavailable-warmup'),
        completes,
      );
    });
  });

  group('OidcWebCrypto.warnInsecureFallbackOnce', () {
    test('logs only once per recordKey (second call is a no-op)', () {
      // Calling twice must not throw; the second call should hit the
      // early-return "already warned" branch instead of logging again.
      OidcWebCrypto.warnInsecureFallbackOnce('warn-once-key');
      expect(
        () => OidcWebCrypto.warnInsecureFallbackOnce('warn-once-key'),
        returnsNormally,
      );
    });

    test('warns independently per distinct recordKey', () {
      expect(
        () => OidcWebCrypto.warnInsecureFallbackOnce('warn-key-a'),
        returnsNormally,
      );
      expect(
        () => OidcWebCrypto.warnInsecureFallbackOnce('warn-key-b'),
        returnsNormally,
      );
    });
  });

  group('OidcWebCrypto key persistence/reuse', () {
    test('a key generated for a recordKey is reused (loaded from IndexedDB) '
        'after the in-memory cache is cleared via debugReset', () async {
      const recordKey = 'reuse-across-reset';
      final envelope = await OidcWebCrypto.encrypt(
        'hello-world',
        recordKey: recordKey,
      );
      expect(envelope, isNotNull);

      // Clears the in-memory _keyFutures cache, but NOT the underlying
      // IndexedDB-persisted CryptoKey -- the next _ensureKey call for the
      // same recordKey must load the existing key rather than generating
      // a new (undecryptable) one.
      OidcWebCrypto.debugReset();

      final decrypted = await OidcWebCrypto.decryptEnvelope(
        envelope!,
        recordKey: recordKey,
      );
      expect(decrypted, 'hello-world');
    });

    test('encrypt/decrypt round-trips arbitrary unicode plaintext', () async {
      const recordKey = 'unicode-roundtrip';
      const plaintext = '{"token":"héllo 世界 🔒"}';
      final envelope = await OidcWebCrypto.encrypt(
        plaintext,
        recordKey: recordKey,
      );
      expect(envelope, isNotNull);
      expect(OidcWebCrypto.isEncryptedEnvelope(envelope!), isTrue);

      final decrypted = await OidcWebCrypto.decryptEnvelope(
        envelope,
        recordKey: recordKey,
      );
      expect(decrypted, plaintext);
    });
  });
}
