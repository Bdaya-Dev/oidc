@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Gap #2 (audit #324 item 9): the SAME kid-miss-triggered forced JWKS
/// refetch (see `jwks_kid_rotation_test.dart` for gap #1) must also apply
/// when no [OidcStore] `cacheStore` is available to verify against — the
/// advanced/manual `OidcUser.fromIdToken(cacheStore: null)` API surface,
/// which otherwise falls back to jose_plus's long-lived, process-wide
/// default [JsonWebKeySetLoader] whose in-memory TTL cache can mask a
/// just-rotated signing key for its full cache lifetime.

final Uri _jwksUri = Uri.parse('https://op.example.com/jwks');

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

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(jwksForceRefetchTimestamps.clear);

  group('kid-miss JWKS refetch (cacheStore-less path)', () {
    test(
      'token signed by a NEW key not yet visible to the loader => forced '
      'refetch picks it up and verifies, with NO cacheStore supplied',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final oldKey = _withKid(JsonWebKey.generate('RS256'), 'kid-old');
          final newKey = _withKid(JsonWebKey.generate('RS256'), 'kid-new');
          var callCount = 0;
          final client = MockClient((req) async {
            callCount++;
            final keys = callCount == 1 ? [oldKey] : [oldKey, newKey];
            return http.Response(_jwksBody(keys), 200);
          });

          final idToken = await _signIdToken(newKey);
          final user = await OidcUser.fromIdToken(
            token: _tokenWith(idToken),
            keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
            // No cacheStore: exercises the gap #2 path.
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
          final client = MockClient((req) async {
            callCount++;
            return http.Response(_jwksBody([knownKey]), 200);
          });

          final bogusKey1 = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-bogus-1',
          );
          final idToken1 = await _signIdToken(bogusKey1);
          await expectLater(
            OidcUser.fromIdToken(
              token: _tokenWith(idToken1),
              keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
              allowedAlgorithms: const ['RS256'],
              httpClient: client,
            ),
            throwsA(anything),
          );
          expect(callCount, 2, reason: 'normal fetch + one forced retry');

          final bogusKey2 = _withKid(
            JsonWebKey.generate('RS256'),
            'kid-bogus-2',
          );
          final idToken2 = await _signIdToken(bogusKey2);
          await expectLater(
            OidcUser.fromIdToken(
              token: _tokenWith(idToken2),
              keystore: JsonWebKeyStore()..addKeySetUrl(_jwksUri),
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
