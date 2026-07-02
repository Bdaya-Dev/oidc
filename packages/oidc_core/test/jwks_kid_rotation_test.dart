@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Gap #1 (audit #324 item 9): on an id_token verification failure, the
/// manager should force exactly ONE cache-busting JWKS refetch (rate-limited
/// per issuer) and retry once before giving up — instead of trusting a
/// possibly-stale JWKS view forever within a single verification call. See
/// `OidcUser.fromIdToken` / `OidcJwksStoreLoader.forceFresh`.
///
/// These tests exercise the path where a [cacheStore] IS supplied (the
/// `OidcUserManager`-managed flow). The `cacheStore`-less path is covered
/// separately.

final _jwksUri = Uri.parse('https://op.example.com/jwks');

JsonWebKey _withKid(JsonWebKey key, String kid) =>
    JsonWebKey.fromJson({...key.toJson(), 'kid': kid})!;

String _jwksBody(Iterable<JsonWebKey> keys) =>
    jsonEncode(JsonWebKeySet.fromKeys(keys).toJson());

Future<String> _signIdToken(JsonWebKey key) async {
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = {
      'iss': 'https://op.example.com',
      'sub': 'user-1',
      'aud': 'client-1',
      'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    }
    ..addRecipient(key, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

OidcToken _tokenWith(String idToken) => OidcToken(
  idToken: idToken,
  accessToken: 'at',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
  creationTime: clock.now(),
);

Future<OidcStore> _store() async {
  final store = OidcMemoryStore();
  await store.init();
  return store;
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    // The per-issuer cooldown tracker is process-lifetime global state; reset
    // it between tests so they don't interfere with each other.
    jwksForceRefetchTimestamps.clear();
  });

  group('kid-miss JWKS refetch (cacheStore path)', () {
    test(
      'token signed by a NEW key not yet in the cached JWKS => forced '
      'refetch picks it up and verifies',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final oldKey = _withKid(JsonWebKey.generate('RS256'), 'kid-old');
          final newKey = _withKid(JsonWebKey.generate('RS256'), 'kid-new');
          var callCount = 0;
          final client = MockClient((req) async {
            callCount++;
            // First fetch returns the "stale" view (only the old key); any
            // later (forced/cache-busted) fetch returns the rotated set —
            // simulating a key that was published after our first read.
            final keys = callCount == 1 ? [oldKey] : [oldKey, newKey];
            return http.Response(_jwksBody(keys), 200);
          });

          final idToken = await _signIdToken(newKey);
          final user = await OidcUser.fromIdToken(
            token: _tokenWith(idToken),
            keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
            cacheStore: await _store(),
            allowedAlgorithms: const ['RS256'],
            httpClient: client,
          );

          expect(user.parsedIdToken.isVerified, isTrue);
          expect(user.claims.subject, 'user-1');
          expect(callCount, 2, reason: 'one normal fetch + one forced retry');
        });
      },
    );

    test(
      'a second verification failure for the same issuer within the '
      'cooldown does NOT trigger a second forced refetch (fails closed)',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final knownKey = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-known',
          );
          var callCount = 0;
          // The signing keys used by the bogus tokens below are never
          // present in the served JWKS, however many times it's fetched.
          final client = MockClient((req) async {
            callCount++;
            return http.Response(_jwksBody([knownKey]), 200);
          });

          final store = await _store();
          final bogusKey1 = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-bogus-1',
          );
          final idToken1 = await _signIdToken(bogusKey1);
          await expectLater(
            OidcUser.fromIdToken(
              token: _tokenWith(idToken1),
              keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
              cacheStore: store,
              allowedAlgorithms: const ['RS256'],
              httpClient: client,
            ),
            throwsA(anything),
          );
          expect(callCount, 2, reason: 'normal fetch + one forced retry');

          // A different bogus kid, same issuer, well within the 5-minute
          // cooldown window (the clock hasn't moved).
          final bogusKey2 = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-bogus-2',
          );
          final idToken2 = await _signIdToken(bogusKey2);
          await expectLater(
            OidcUser.fromIdToken(
              token: _tokenWith(idToken2),
              keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
              cacheStore: store,
              allowedAlgorithms: const ['RS256'],
              httpClient: client,
            ),
            throwsA(anything),
          );
          expect(
            callCount,
            3,
            reason:
                'only ONE additional (normal) fetch — no second forced '
                'retry while the per-issuer cooldown is active',
          );
        });
      },
    );

    test(
      'a genuinely bogus kid triggers exactly one forced retry and still '
      'fails (fail-closed)',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final knownKey = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-known',
          );
          var callCount = 0;
          final client = MockClient((req) async {
            callCount++;
            return http.Response(_jwksBody([knownKey]), 200);
          });

          final bogusKey = _withKid(JsonWebKey.generate('RS256'), 'kid-bogus');
          final idToken = await _signIdToken(bogusKey);
          await expectLater(
            OidcUser.fromIdToken(
              token: _tokenWith(idToken),
              keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
              cacheStore: await _store(),
              allowedAlgorithms: const ['RS256'],
              httpClient: client,
            ),
            throwsA(anything),
          );
          expect(
            callCount,
            2,
            reason: 'exactly one normal fetch + one forced retry, no more',
          );
        });
      },
    );
  });
}
