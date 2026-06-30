@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _jwksBody = '{"keys":[]}';
final Uri _jwksUri = Uri.parse('https://op.example.com/jwks');
String get _sidecarKey => '$_jwksUri::oidc_jwks_fetched_at';

http.Client _serving(String body) => MockClient(
  (req) async =>
      http.Response(body, 200, headers: const {'content-type': 'text/plain'}),
);

http.Client _failing() =>
    MockClient((req) async => throw const SocketException('offline'));

Future<OidcStore> _store() async {
  final store = OidcMemoryStore();
  await store.init();
  return store;
}

Future<void> _seed(
  OidcStore store, {
  required String jwks,
  int? timestampMs,
}) => store.setMany(
  OidcStoreNamespace.discoveryDocument,
  values: {
    _jwksUri.toString(): jwks,
    if (timestampMs != null) _sidecarKey: timestampMs.toString(),
  },
);

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t0Ms = t0.millisecondsSinceEpoch;

  group('OidcJwksStoreLoader TTL', () {
    test('successful fetch persists JWKS + sidecar timestamp', () async {
      final store = await _store();
      await withClock(Clock.fixed(t0), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _serving(_jwksBody),
        );
        final result = await loader.readAsString(_jwksUri);
        expect(result, _jwksBody);
      });
      final vals = await store.getMany(
        OidcStoreNamespace.discoveryDocument,
        keys: {_jwksUri.toString(), _sidecarKey},
      );
      expect(vals[_jwksUri.toString()], _jwksBody);
      expect(vals[_sidecarKey], t0Ms.toString());
    });

    test('offline within TTL serves the cached JWKS', () async {
      final store = await _store();
      await _seed(store, jwks: _jwksBody, timestampMs: t0Ms);
      await withClock(Clock.fixed(t0.add(const Duration(hours: 6))), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
        );
        expect(await loader.readAsString(_jwksUri), _jwksBody);
      });
    });

    test('offline past TTL rethrows (does NOT serve stale cache)', () async {
      final store = await _store();
      await _seed(store, jwks: _jwksBody, timestampMs: t0Ms);
      await withClock(
        Clock.fixed(t0.add(const Duration(days: 1, seconds: 1))),
        () async {
          final loader = OidcJwksStoreLoader(
            store: store,
            httpClient: _failing(),
          );
          await expectLater(
            loader.readAsString(_jwksUri),
            throwsA(isA<SocketException>()),
          );
        },
      );
    });

    test('legacy entry without timestamp fails-closed (rethrow)', () async {
      final store = await _store();
      // Seed only the JWKS (no sidecar) — simulates a pre-upgrade entry.
      await _seed(store, jwks: _jwksBody);
      await withClock(Clock.fixed(t0), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
        );
        await expectLater(
          loader.readAsString(_jwksUri),
          throwsA(isA<SocketException>()),
        );
      });
    });

    test('no cache at all rethrows the original error', () async {
      final store = await _store();
      await withClock(Clock.fixed(t0), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
        );
        await expectLater(
          loader.readAsString(_jwksUri),
          throwsA(isA<SocketException>()),
        );
      });
    });

    test('custom staleCacheMaxAge honored', () async {
      final store = await _store();
      await _seed(store, jwks: _jwksBody, timestampMs: t0Ms);
      // age 2h > 1h => rethrow
      await withClock(Clock.fixed(t0.add(const Duration(hours: 2))), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
          staleCacheMaxAge: const Duration(hours: 1),
        );
        await expectLater(
          loader.readAsString(_jwksUri),
          throwsA(isA<SocketException>()),
        );
      });
      // age 30m < 1h => cached
      await withClock(
        Clock.fixed(t0.add(const Duration(minutes: 30))),
        () async {
          final loader = OidcJwksStoreLoader(
            store: store,
            httpClient: _failing(),
            staleCacheMaxAge: const Duration(hours: 1),
          );
          expect(await loader.readAsString(_jwksUri), _jwksBody);
        },
      );
    });

    test('staleCacheMaxAge=Duration.zero disables fallback (age 0)', () async {
      final store = await _store();
      await _seed(store, jwks: _jwksBody, timestampMs: t0Ms);
      await withClock(Clock.fixed(t0), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
          staleCacheMaxAge: Duration.zero,
        );
        await expectLater(
          loader.readAsString(_jwksUri),
          throwsA(isA<SocketException>()),
        );
      });
    });

    test('successful fetch refreshes the timestamp', () async {
      final store = await _store();
      // Seed an OLD (stale) timestamp.
      final oldMs = t0
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      await _seed(store, jwks: 'old-jwks', timestampMs: oldMs);
      // A successful fetch overwrites the JWKS + timestamp at t0.
      await withClock(Clock.fixed(t0), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _serving(_jwksBody),
        );
        expect(await loader.readAsString(_jwksUri), _jwksBody);
      });
      final vals = await store.getMany(
        OidcStoreNamespace.discoveryDocument,
        keys: {_jwksUri.toString(), _sidecarKey},
      );
      expect(vals[_sidecarKey], t0Ms.toString());
      // A subsequent offline read within TTL now serves the refreshed JWKS.
      await withClock(Clock.fixed(t0.add(const Duration(hours: 1))), () async {
        final loader = OidcJwksStoreLoader(
          store: store,
          httpClient: _failing(),
        );
        expect(await loader.readAsString(_jwksUri), _jwksBody);
      });
    });
  });

  group('integration', () {
    // A non-http(s)/data scheme makes DefaultJsonWebKeySetLoader.readAsString
    // throw deterministically (no network), exercising the offline fallback
    // path inside OidcUser.fromIdToken / validateLogoutToken which do not allow
    // injecting a mock http client into their internal loader.
    final offlineJwksUri = Uri.parse('unsupported://op.example.com/jwks');
    final offlineSidecar = '$offlineJwksUri::oidc_jwks_fetched_at';

    final signingKey = JsonWebKey.generate('RS256');
    final jwks = jsonEncode(JsonWebKeySet.fromKeys([signingKey]).toJson());

    Future<String> signIdToken() async {
      final builder = JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': 'https://op.example.com',
          'sub': 'user-1',
          'aud': 'client-1',
          'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
          'exp':
              clock
                  .now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }
        ..addRecipient(signingKey, algorithm: 'RS256');
      return builder.build().toCompactSerialization();
    }

    Future<OidcStore> seededStore({required int timestampMs}) async {
      final store = OidcMemoryStore();
      await store.init();
      await store.setMany(
        OidcStoreNamespace.discoveryDocument,
        values: {
          offlineJwksUri.toString(): jwks,
          offlineSidecar: timestampMs.toString(),
        },
      );
      return store;
    }

    test(
      'OidcUser.fromIdToken: STALE cached JWKS + failing fetch + strict => '
      'fails-closed',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final idToken = await signIdToken();
          // Cached JWKS is older than jwksCacheMaxAge (1h here).
          final store = await seededStore(
            timestampMs: t0
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
          );
          await expectLater(
            OidcUser.fromIdToken(
              token: OidcToken(
                idToken: idToken,
                creationTime: clock.now(),
              ),
              keystore: JsonWebKeyStore()..addKeySetUrl(offlineJwksUri),
              cacheStore: store,
              allowedAlgorithms: const ['RS256'],
              jwksCacheMaxAge: const Duration(hours: 1),
            ),
            throwsA(anything),
          );
        });
      },
    );

    test(
      'OidcUser.fromIdToken: FRESH cached JWKS (within TTL) verifies offline',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final idToken = await signIdToken();
          // Cached JWKS is within jwksCacheMaxAge.
          final store = await seededStore(
            timestampMs: t0
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          );
          final user = await OidcUser.fromIdToken(
            token: OidcToken(
              idToken: idToken,
              creationTime: clock.now(),
            ),
            keystore: JsonWebKeyStore()..addKeySetUrl(offlineJwksUri),
            cacheStore: store,
            allowedAlgorithms: const ['RS256'],
            jwksCacheMaxAge: const Duration(hours: 1),
          );
          expect(user.parsedIdToken.isVerified, isTrue);
          expect(user.claims.subject, 'user-1');
        });
      },
    );

    test(
      'validateLogoutToken honors jwksCacheMaxAge: stale cache + failing fetch '
      '=> throws',
      () async {
        await withClock(Clock.fixed(t0), () async {
          final logoutToken =
              (JsonWebSignatureBuilder()
                    ..jsonContent = {
                      'iss': 'https://op.example.com',
                      'aud': 'client-1',
                      'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
                      'exp':
                          clock
                              .now()
                              .add(const Duration(hours: 1))
                              .millisecondsSinceEpoch ~/
                          1000,
                      'sub': 'user-1',
                      'jti': 'jti-1',
                      'events': {
                        OidcConstants_JWTClaims.backchannelLogoutEvent:
                            <String, dynamic>{},
                      },
                    }
                    ..addRecipient(signingKey, algorithm: 'RS256'))
                  .build()
                  .toCompactSerialization();
          final store = await seededStore(
            timestampMs: t0
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
          );
          await expectLater(
            OidcEndpoints.validateLogoutToken(
              logoutToken: logoutToken,
              keyStore: JsonWebKeyStore()..addKeySetUrl(offlineJwksUri),
              issuer: Uri.parse('https://op.example.com'),
              clientId: 'client-1',
              allowedAlgorithms: const ['RS256'],
              cacheStore: store,
              jwksCacheMaxAge: const Duration(hours: 1),
            ),
            throwsA(isA<OidcException>()),
          );
        });
      },
    );
  });
}
