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
  });
}
