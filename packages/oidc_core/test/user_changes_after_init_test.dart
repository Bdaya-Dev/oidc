@TestOn('vm')
library;

// #453: `userChanges()` replays its seed `null` before `init()` completes, so a
// listener attached early (e.g. alongside `events()`, which must be subscribed
// before `init()` to observe a startup `invalid_grant`) cannot tell "not
// initialized yet" from "signed out". `userChangesAfterInit()` holds its first
// emission until `init()` has completed, so every `null` it emits means
// signed out.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _issuer = 'https://op.example.com';
final Uri _wellKnown = Uri.parse('$_issuer/.well-known/openid-configuration');
final JsonWebKey _signingKey = JsonWebKey.generate('RS256');

String _signIdToken() {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': now + 3600,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

Map<String, dynamic> _metadataJson() => {
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
  'id_token_signing_alg_values_supported': ['RS256'],
};

class _Manager extends OidcUserManagerBase {
  _Manager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) => const {};

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) => const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) => const Stream.empty();
}

/// Answers discovery and userinfo; [discoveryGate], when given, holds the
/// discovery response so a test can observe the manager mid-`init()`.
http.Client _client({
  Future<void>? discoveryGate,
  bool failDiscovery = false,
}) => MockClient((req) async {
  final path = req.url.path;
  if (path.endsWith('openid-configuration')) {
    if (discoveryGate != null) {
      await discoveryGate;
    }
    if (failDiscovery) {
      throw const SocketException('offline');
    }
    return http.Response(
      jsonEncode(_metadataJson()),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  if (path.endsWith('/userinfo')) {
    return http.Response(
      jsonEncode({'sub': 'user-1'}),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('{}', 404);
});

Future<OidcMemoryStore> _store({bool withCachedUser = false}) async {
  final store = OidcMemoryStore();
  await store.init();
  if (withCachedUser) {
    await store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {
        OidcConstants_Store.currentToken: jsonEncode(
          OidcToken(
            creationTime: clock.now().toUtc(),
            idToken: _signIdToken(),
            accessToken: 'at-cached',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
          ).toJson(),
        ),
      },
    );
  }
  return store;
}

_Manager _manager({
  required OidcStore store,
  required http.Client client,
  OidcInitMode initMode = OidcInitMode.cacheFirst,
}) => _Manager.lazy(
  discoveryDocumentUri: _wellKnown,
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store,
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('app://cb'),
    initMode: initMode,
  ),
);

/// Runs [body] in a zone that keeps a [WeakReference] to every callback
/// registered through it, so a test can tell whether those callbacks (and
/// whatever they closed over, such as a [StreamController]) are still
/// reachable afterwards.
///
/// `Future.then`, `Future.any`, `Stream.listen` and friends all register
/// their callbacks with [Zone.current] when it is not the root zone, so this
/// sees every closure `userChangesAfterInit()` attaches to a future on behalf
/// of a listener — including ones that capture that listener's controller.
List<WeakReference<Function>> _trackRegisteredCallbacks(void Function() body) {
  final refs = <WeakReference<Function>>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      registerCallback: <R>(self, parent, zone, f) {
        refs.add(WeakReference(f));
        return parent.registerCallback(zone, f);
      },
      registerUnaryCallback: <R, T>(self, parent, zone, f) {
        refs.add(WeakReference(f));
        return parent.registerUnaryCallback(zone, f);
      },
      registerBinaryCallback: <R, T1, T2>(self, parent, zone, f) {
        refs.add(WeakReference(f));
        return parent.registerBinaryCallback(zone, f);
      },
    ),
  );
  return refs;
}

/// The number of [refs] still reachable after driving the garbage collector.
///
/// `package:test` runs without a VM service, so there is no direct "force a
/// full GC" call; instead this allocates throwaway garbage (enough to trigger
/// young- AND old-generation collections) until at most [atMost] targets
/// survive, giving up after a bounded number of rounds. A genuinely retained
/// target is never collected however many rounds run, so a leak still fails
/// deterministically; only the time spent proving it varies.
Future<int> _aliveAfterGc(
  List<WeakReference<Function>> refs, {
  required int atMost,
}) async {
  // Count DISTINCT survivors: static tear-offs the stream internals register
  // (e.g. the default no-op done/error handlers) are canonical, never
  // collected, and identical across rounds, so they collapse to one each
  // instead of masquerading as a per-round leak.
  int alive() =>
      (Set<Object>.identity()
            ..addAll(refs.map((r) => r.target).whereType<Object>()))
          .length;
  for (var round = 0; round < 60 && alive() > atMost; round++) {
    var junk = <List<int>>[];
    for (var i = 0; i < 4000; i++) {
      junk.add(List<int>.filled(512, i));
    }
    junk = const [];
    await Future<void>.delayed(Duration.zero);
  }
  return alive();
}

/// Runs [body] in an error zone and returns every error that escaped it
/// uncaught (e.g. a `StateError` from adding to a closed controller inside a
/// fire-and-forget callback), after letting queued microtasks drain.
Future<List<Object>> _runGuarded(Future<void> Function() body) async {
  final uncaught = <Object>[];
  final finished = Completer<void>();
  runZonedGuarded(() {
    unawaited(body().whenComplete(finished.complete));
  }, (e, st) => uncaught.add(e));
  await finished.future.timeout(const Duration(seconds: 5));
  await pumpEventQueue();
  return uncaught;
}

/// A fresh error zone whose uncaught errors are appended to [uncaught]; run
/// code in it later with [Zone.run].
Zone _errorZone(List<Object> uncaught) {
  late Zone zone;
  runZonedGuarded(() => zone = Zone.current, (e, st) => uncaught.add(e));
  return zone;
}

void main() {
  group('userChangesAfterInit (#453)', () {
    test(
      'emits nothing while init() is in flight, unlike userChanges()',
      () async {
        final gate = Completer<void>();
        final manager = _manager(
          store: await _store(),
          client: _client(discoveryGate: gate.future),
        );
        final raw = <OidcUser?>[];
        final afterInit = <OidcUser?>[];
        manager.userChanges().listen(raw.add);
        manager.userChangesAfterInit().listen(afterInit.add);

        final init = manager.init();
        await pumpEventQueue();

        // The legacy stream already replayed its seed null; the new one holds.
        expect(raw, [null]);
        expect(afterInit, isEmpty);

        gate.complete();
        await init;
        await pumpEventQueue();

        // No cached user: the settled value really is "signed out".
        expect(afterInit, [null]);
        await manager.dispose();
      },
    );

    for (final mode in OidcInitMode.values) {
      test(
        '${mode.name}: a cached user is the FIRST emission (no leading null)',
        () async {
          final manager = _manager(
            store: await _store(withCachedUser: true),
            client: _client(),
            initMode: mode,
          );
          final afterInit = <OidcUser?>[];
          manager.userChangesAfterInit().listen(afterInit.add);

          await manager.init();
          await pumpEventQueue();

          expect(afterInit, isNotEmpty);
          expect(afterInit, everyElement(isNotNull));
          expect(afterInit.first!.claims.subject, 'user-1');
          await manager.dispose();
        },
      );
    }

    test('subscribing after init() replays the current user at once', () async {
      final manager = _manager(
        store: await _store(withCachedUser: true),
        client: _client(),
        initMode: OidcInitMode.blockingValidate,
      );
      await manager.init();

      final first = await manager.userChangesAfterInit().first;
      expect(first, same(manager.currentUser));
      expect(first, isNotNull);
      await manager.dispose();
    });

    test('forwards later changes (sign-out emits null)', () async {
      final manager = _manager(
        store: await _store(withCachedUser: true),
        client: _client(),
        initMode: OidcInitMode.blockingValidate,
      );
      final afterInit = <OidcUser?>[];
      manager.userChangesAfterInit().listen(afterInit.add);
      await manager.init();
      await pumpEventQueue();
      expect(afterInit, hasLength(1));
      expect(afterInit.single, isNotNull);

      await manager.forgetUser();
      await pumpEventQueue();

      expect(afterInit, hasLength(2));
      expect(afterInit.last, isNull);
      await manager.dispose();
    });

    test('is multi-subscription, like userChanges()', () async {
      final manager = _manager(store: await _store(), client: _client());
      await manager.init();
      final stream = manager.userChangesAfterInit();

      expect(await stream.first, isNull);
      expect(await stream.first, isNull);
      await manager.dispose();
    });

    test('closes without emitting when disposed before init()', () async {
      final manager = _manager(store: await _store(), client: _client());
      final afterInit = <OidcUser?>[];
      final done = Completer<void>();
      manager.userChangesAfterInit().listen(
        afterInit.add,
        onDone: done.complete,
      );

      await manager.dispose();

      await done.future.timeout(const Duration(seconds: 5));
      expect(afterInit, isEmpty);
    });

    test('surfaces an init() failure as a stream error, then closes', () async {
      final manager = _manager(
        store: await _store(),
        client: _client(failDiscovery: true),
      );
      final stream = manager.userChangesAfterInit();
      final errors = <Object>[];
      final done = Completer<void>();
      stream.listen(
        (_) => fail('must not emit a user when init() failed'),
        onError: errors.add,
        onDone: done.complete,
      );

      await expectLater(manager.init(), throwsA(anything));
      await done.future.timeout(const Duration(seconds: 5));

      expect(errors, hasLength(1));
      await manager.dispose();
    });

    // Regression test: `userChangesAfterInit()` used to race `initFuture`
    // against a shared future that only ever completed inside `dispose()`
    // (`Future.any([initFuture, _disposeSignal.future])`). Since that future
    // stayed pending for the manager's entire lifetime, every listener's
    // `.then` callback — and the `StreamController` it closed over — stayed
    // permanently attached to it, even long after the listener had cancelled
    // or `initFuture` had already settled. A caller that repeatedly
    // subscribed to and cancelled this stream (e.g. once per rebuild) leaked
    // one retained closure/controller per round for as long as the manager
    // lived. `debugPendingUserChangesAfterInitListenerCount` exposes the
    // number of listeners still pinned like this; it must drop back to 0
    // once a listener cancels or `initFuture` settles, instead of only ever
    // growing until `dispose()`.
    test(
      'does not retain userChangesAfterInit listeners past settle/cancel '
      '(#453 leak)',
      () async {
        final manager = _manager(store: await _store(), client: _client());

        // Subscribe twice *before* init() completes, then cancel one and let
        // init() settle for the other — neither should remain pending once
        // init() has settled.
        final earlySub1 = manager.userChangesAfterInit().listen((_) {});
        final earlySub2 = manager.userChangesAfterInit().listen((_) {});
        await pumpEventQueue();
        expect(manager.debugPendingUserChangesAfterInitListenerCount, 2);

        await earlySub1.cancel();
        expect(manager.debugPendingUserChangesAfterInitListenerCount, 1);

        await manager.init();
        await pumpEventQueue();
        expect(
          manager.debugPendingUserChangesAfterInitListenerCount,
          0,
          reason:
              'a settled initFuture must release every listener that was '
              'waiting on it, not just the ones that happened to cancel',
        );

        // Post-init, repeated subscribe/cancel rounds must not accumulate:
        // each round's listener resolves against the already-settled
        // initFuture and releases itself right away.
        for (var i = 0; i < 50; i++) {
          final sub = manager.userChangesAfterInit().listen((_) {});
          await sub.cancel();
        }
        await pumpEventQueue();
        expect(
          manager.debugPendingUserChangesAfterInitListenerCount,
          0,
          reason:
              'subscribe/cancel rounds after init() must not leak a pending '
              'listener per round',
        );

        await earlySub2.cancel();
        await manager.dispose();
      },
    );
    // Real-retention regression (#453): the debug counter above only checks
    // the manager's own bookkeeping, so it passes even if a listener's
    // closure stays attached to some long-lived future. These tests instead
    // hold a WeakReference to every callback a subscribe/cancel round
    // registers and require (almost) all of them to be garbage-collectable
    // once the round is over. With N rounds, a per-round leak leaves ~N (or
    // 2N) survivors; the fixed implementation attaches nothing per listener,
    // so only a handful of shared/incidental callbacks may survive.
    const rounds = 50;
    const allowedSurvivors = 4;

    test(
      'subscribe/cancel BEFORE init() retains nothing per round (#453)',
      () async {
        final manager = _manager(store: await _store(), client: _client());

        final refs = _trackRegisteredCallbacks(() {
          for (var i = 0; i < rounds; i++) {
            unawaited(manager.userChangesAfterInit().listen((_) {}).cancel());
          }
        });
        await pumpEventQueue();
        expect(refs.length, greaterThanOrEqualTo(rounds));

        expect(
          await _aliveAfterGc(refs, atMost: allowedSurvivors),
          lessThanOrEqualTo(allowedSurvivors),
          reason:
              'a cancelled listener must not stay reachable from initFuture '
              'while init() has not run yet',
        );
        await manager.dispose();
      },
    );

    test(
      'subscribe/cancel AFTER init() retains nothing per round (#453)',
      () async {
        final manager = _manager(store: await _store(), client: _client());
        await manager.init();

        final refs = _trackRegisteredCallbacks(() {
          for (var i = 0; i < rounds; i++) {
            unawaited(manager.userChangesAfterInit().listen((_) {}).cancel());
          }
        });
        await pumpEventQueue();
        expect(refs.length, greaterThanOrEqualTo(rounds));

        expect(
          await _aliveAfterGc(refs, atMost: allowedSurvivors),
          lessThanOrEqualTo(allowedSurvivors),
          reason:
              'a cancelled listener must not stay reachable from any future '
              'that outlives it (e.g. one that only completes on dispose)',
        );
        await manager.dispose();
      },
    );

    // B-1: dispose() closes every pending listener's controller, but a
    // listener only observes that (as a done event) a microtask later — or
    // never, while paused. An init() failure delivered in that window must
    // not be added to the already-closed controller (StateError: Cannot add
    // event after closing), which would surface as an uncaught zone error.
    group('init() failure after dispose() raises no uncaught error', () {
      test('app disposes in its own catch around init()', () async {
        final gate = Completer<void>();
        final manager = _manager(
          store: await _store(),
          client: _client(discoveryGate: gate.future, failDiscovery: true),
        );
        final events = <String>[];
        final uncaught = await _runGuarded(() async {
          // The app awaits init() first, so its catch — and the dispose()
          // inside it — runs before the listener's own reaction to the
          // same failed future.
          final app = () async {
            try {
              await manager.init();
            } on Object catch (_) {
              await manager.dispose();
            }
          }();
          final done = Completer<void>();
          manager.userChangesAfterInit().listen(
            (_) => events.add('data'),
            onError: (Object _) => events.add('error'),
            onDone: () {
              events.add('done');
              done.complete();
            },
          );
          gate.complete();
          await app;
          await done.future;
        });

        expect(uncaught, isEmpty);
        // Whether the error lands before the dispose() closed the stream
        // depends on callback order; either way the stream must terminate
        // exactly once and never emit a user.
        expect(events, anyOf(equals(['done']), equals(['error', 'done'])));
      });

      test('paused listener, dispose mid-init, init fails later', () async {
        final gate = Completer<void>();
        final manager = _manager(
          store: await _store(),
          client: _client(discoveryGate: gate.future, failDiscovery: true),
        );
        final events = <String>[];
        final uncaught = await _runGuarded(() async {
          final sub = manager.userChangesAfterInit().listen(
            (_) => events.add('data'),
            onError: (Object _) => events.add('error'),
            onDone: () => events.add('done'),
          )..pause();
          final init = manager.init().then<void>((_) {}, onError: (_) {});
          await pumpEventQueue();

          await manager.dispose();
          gate.complete();
          await init;
          await pumpEventQueue();

          sub.resume();
          await pumpEventQueue();
          await sub.cancel();
        });

        expect(uncaught, isEmpty);
        expect(events, ['done']);
      });

      test(
        'failed init() error queued in the same turn as dispose()',
        () async {
          final store = await _store();
          final events = <String>[];
          final uncaught = await _runGuarded(() async {
            // The manager is created, init() fails, and the listener lives
            // all in one error zone, so only the closed-controller hazard is
            // under test here (see the cross-zone test below for the other).
            final manager = _manager(
              store: store,
              client: _client(failDiscovery: true),
            );
            await expectLater(manager.init(), throwsA(anything));
            manager.userChangesAfterInit().listen(
              (_) => events.add('data'),
              onError: (Object _) => events.add('error'),
              onDone: () => events.add('done'),
            );
            // Same synchronous turn: the failed initFuture's callbacks are
            // queued but have not run yet.
            await manager.dispose();
            await pumpEventQueue();
          });

          expect(uncaught, isEmpty);
          // Whether the error lands before the dispose() closed the stream
          // depends on callback order; either way the stream must terminate
          // exactly once and never emit a user.
          expect(events, anyOf(equals(['done']), equals(['error', 'done'])));
        },
      );
    });

    // A future's error is never handed to a handler registered in a different
    // error zone (it is reported as uncaught in the future's own zone). An app
    // that subscribes inside runZonedGuarded but calls init() outside it must
    // still see the failure on the stream, not as an uncaught error.
    // The manager's AsyncMemoizer (and so initFuture) is created in the zone
    // the manager is CONSTRUCTED in. Once initFuture has failed, any handler
    // attached to it from another error zone never sees the error — Dart
    // reports it as uncaught in the construction zone instead. Late
    // subscribers must still get the failure, wherever each zone lives.
    test(
      'init() failure reaches late subscribers when the manager was built, '
      'init() was run, and each listener subscribed in different zones',
      () async {
        final store = await _store();
        final inC = <Object>[];
        final inA = <Object>[];
        final inB = <Object>[];
        final zoneC = _errorZone(inC);
        final zoneA = _errorZone(inA);
        final zoneB = _errorZone(inB);

        final manager = zoneC.run(
          () => _manager(store: store, client: _client(failDiscovery: true)),
        );
        var initThrew = false;
        await zoneA.run(() async {
          try {
            await manager.init();
          } on Object catch (_) {
            initThrew = true;
          }
        });
        expect(initThrew, isTrue);

        final eventsA = <String>[];
        final eventsB = <String>[];
        final doneA = Completer<void>();
        final doneB = Completer<void>();
        void subscribe(Zone zone, List<String> events, Completer<void> done) {
          zone.run(
            () => manager.userChangesAfterInit().listen(
              (_) => events.add('data'),
              onError: (Object _) => events.add('error'),
              onDone: () {
                events.add('done');
                done.complete();
              },
            ),
          );
        }

        subscribe(zoneA, eventsA, doneA);
        subscribe(zoneB, eventsB, doneB);
        await Future.wait([
          doneA.future,
          doneB.future,
        ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
        await pumpEventQueue();

        expect(eventsA, ['error', 'done']);
        expect(eventsB, ['error', 'done']);
        expect(inC, isEmpty, reason: 'construction zone');
        expect(inA, isEmpty, reason: 'init() zone');
        expect(inB, isEmpty, reason: 'other subscriber zone');
        expect(manager.debugPendingUserChangesAfterInitListenerCount, 0);
        await manager.dispose();
      },
    );

    // Observing init() on behalf of userChangesAfterInit() must not mark a
    // failed init() as handled: an un-awaited init() that fails is still
    // reported as an uncaught error, exactly as it is without this API —
    // also when a listener subscribed during init() and then cancelled.
    for (final withCancelledListener in [false, true]) {
      test(
        'a failed, un-awaited init() is still reported uncaught '
        '(${withCancelledListener ? 'listener subscribed then cancelled' : 'no listener'})',
        () async {
          final gate = Completer<void>();
          final manager = _manager(
            store: await _store(),
            client: _client(discoveryGate: gate.future, failDiscovery: true),
          );
          final uncaught = <Object>[];
          _errorZone(uncaught).run(() => unawaited(manager.init()));
          await pumpEventQueue();

          if (withCancelledListener) {
            final sub = manager.userChangesAfterInit().listen(
              (_) {},
              onError: (Object _) {},
            );
            await pumpEventQueue();
            await sub.cancel();
          }

          gate.complete();
          for (var i = 0; i < 50 && uncaught.isEmpty; i++) {
            await pumpEventQueue();
          }
          await pumpEventQueue();

          expect(uncaught, hasLength(1));
          expect(uncaught.single, isA<OidcException>());
          await manager.dispose();
        },
      );
    }

    test(
      'init() failure reaches a listener subscribed in another error zone',
      () async {
        final gate = Completer<void>();
        final manager = _manager(
          store: await _store(),
          client: _client(discoveryGate: gate.future, failDiscovery: true),
        );
        final events = <String>[];
        final done = Completer<void>();
        final uncaught = await _runGuarded(() async {
          manager.userChangesAfterInit().listen(
            (_) => events.add('data'),
            onError: (Object _) => events.add('error'),
            onDone: () {
              events.add('done');
              done.complete();
            },
          );
        });

        final init = manager.init().then<void>((_) {}, onError: (_) {});
        gate.complete();
        await init;
        await done.future.timeout(const Duration(seconds: 5));

        expect(uncaught, isEmpty);
        expect(events, ['error', 'done']);
        await manager.dispose();
      },
    );

    test('closes without emitting when disposed mid-init()', () async {
      final gate = Completer<void>();
      final manager = _manager(
        store: await _store(),
        client: _client(discoveryGate: gate.future),
      );
      final events = <String>[];
      final done = Completer<void>();
      manager.userChangesAfterInit().listen(
        (_) => events.add('data'),
        onError: (Object _) => events.add('error'),
        onDone: () {
          events.add('done');
          done.complete();
        },
      );
      final init = manager.init().then<void>((_) {}, onError: (_) {});
      await pumpEventQueue();

      await manager.dispose();
      await done.future.timeout(const Duration(seconds: 5));
      gate.complete();
      await init;
      await pumpEventQueue();

      expect(events, ['done']);
    });

    test('closes at once when subscribed after dispose()', () async {
      final manager = _manager(store: await _store(), client: _client());
      await manager.dispose();
      final events = <String>[];
      final done = Completer<void>();
      manager.userChangesAfterInit().listen(
        (_) => events.add('data'),
        onDone: () {
          events.add('done');
          done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 5));
      expect(events, ['done']);
    });

    for (final cancelFirst in [true, false]) {
      test(
        'cancel racing dispose() (${cancelFirst ? 'cancel' : 'dispose'} '
        'first) is clean',
        () async {
          final manager = _manager(store: await _store(), client: _client());
          final uncaught = await _runGuarded(() async {
            final sub = manager.userChangesAfterInit().listen((_) {});
            if (cancelFirst) {
              final cancel = sub.cancel();
              await manager.dispose();
              await cancel;
            } else {
              final dispose = manager.dispose();
              await sub.cancel();
              await dispose;
            }
          });
          expect(uncaught, isEmpty);
          expect(manager.debugPendingUserChangesAfterInitListenerCount, 0);
        },
      );
    }
  });
}
