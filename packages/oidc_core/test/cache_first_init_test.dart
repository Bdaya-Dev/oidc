@TestOn('vm')
library;

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
final Uri _wellKnown = Uri.parse(
  '$_issuer/.well-known/openid-configuration',
);
final JsonWebKey _signingKey = JsonWebKey.generate('RS256');

String _signIdToken({
  String subject = 'user-1',
  String issuer = _issuer,
  Duration expiresIn = const Duration(hours: 1),
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': issuer,
          'sub': subject,
          'aud': 'client-1',
          'exp': now + expiresIn.inSeconds,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

Map<String, dynamic> _metadataJson({
  String issuer = _issuer,
  bool includeUserinfo = true,
  Map<String, dynamic> extra = const {},
}) => {
  'issuer': issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  if (includeUserinfo) 'userinfo_endpoint': '$_issuer/userinfo',
  // No `jwks_uri`: the tests inject the signing key into the manager keyStore
  // directly, so id_token verification never needs a network JWKS fetch.
  'id_token_signing_alg_values_supported': ['RS256'],
  ...extra,
};

/// A concrete manager built via the `.lazy` constructor so the tests can drive
/// `init()` end-to-end against a discovery URL.
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

/// A MockClient that records every request path and answers the standard
/// discovery / userinfo / token endpoints.
http.Client _client(
  List<String> log, {
  bool failDiscovery = false,
  Map<String, dynamic>? metadata,
}) => MockClient((req) async {
  log.add(req.url.path);
  final path = req.url.path;
  if (path.endsWith('openid-configuration')) {
    if (failDiscovery) {
      throw const SocketException('offline');
    }
    return http.Response(
      jsonEncode(metadata ?? _metadataJson()),
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
  if (path.endsWith('/token')) {
    return http.Response(
      jsonEncode({
        'access_token': 'at-refreshed',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'id_token': _signIdToken(),
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('{}', 404);
});

String _tokenJson({
  String? idToken,
  String accessToken = 'at-cached',
  String? refreshToken,
  Duration expiresIn = const Duration(hours: 1),
  DateTime? creationTime,
}) => jsonEncode(
  OidcToken(
    creationTime: creationTime ?? clock.now().toUtc(),
    idToken: idToken ?? _signIdToken(),
    accessToken: accessToken,
    tokenType: 'Bearer',
    expiresIn: expiresIn,
    refreshToken: refreshToken,
  ).toJson(),
);

Future<OidcMemoryStore> _seededStore({
  String? discoveryMetadata,
  int? discoveryTimestampMs,
  String? tokenJson,
}) async {
  final store = OidcMemoryStore();
  await store.init();
  if (discoveryMetadata != null) {
    await store.setMany(
      OidcStoreNamespace.discoveryDocument,
      values: {
        _wellKnown.toString(): discoveryMetadata,
        if (discoveryTimestampMs != null)
          '$_wellKnown::oidc_discovery_fetched_at': discoveryTimestampMs
              .toString(),
      },
    );
  }
  if (tokenJson != null) {
    await store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {OidcConstants_Store.currentToken: tokenJson},
    );
  }
  return store;
}

_Manager _lazyManager({
  required OidcStore store,
  required http.Client client,
  OidcUserManagerSettings? settings,
}) => _Manager.lazy(
  discoveryDocumentUri: _wellKnown,
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: store,
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings:
      settings ?? OidcUserManagerSettings(redirectUri: Uri.parse('app://cb')),
);

void main() {
  group('cacheFirst init (new default)', () {
    test(
      'restores the cached user with ZERO network calls, then '
      'revalidates in the background',
      () async {
        final net = <String>[];
        final verifiedSeq = <bool?>[];

        // Seed a fresh cached discovery document + a valid cached token.
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(),
        );
        final manager = _lazyManager(store: store, client: _client(net));
        manager.userChanges().listen((u) {
          if (u != null) {
            verifiedSeq.add(u.parsedIdToken.isVerified);
          }
        });

        await manager.init();

        // init() itself performed NO network I/O: the cached user was restored
        // by a pure local deserialize. The background revalidation is gated on
        // the completed initFuture and has only read the store so far.
        expect(net, isEmpty);
        expect(manager.currentUser, isNotNull);
        // The restored user is not yet verified against the network.
        expect(manager.currentUser!.parsedIdToken.isVerified, isNull);

        // Drive the background revalidation to completion.
        await pumpEventQueue();

        // The first surfaced user was the local (unverified => isVerified null)
        // restore; the background pass replaced it with a verified user.
        expect(verifiedSeq.first, isNull);
        expect(verifiedSeq.last, isTrue);
        expect(manager.currentUser!.parsedIdToken.isVerified, isTrue);
        // Fresh discovery => no discovery fetch; the only network call the
        // background made was the userinfo request.
        expect(net.where((p) => p.endsWith('openid-configuration')), isEmpty);
        expect(net.where((p) => p.endsWith('/userinfo')).length, 1);
        await manager.dispose();
      },
    );

    test('with no cached user, falls back to the network path', () async {
      final net = <String>[];
      // No cached discovery, no cached token.
      final store = await _seededStore();
      final manager = _lazyManager(store: store, client: _client(net));

      await manager.init();

      // The blocking network path fetched the discovery document.
      expect(net.where((p) => p.endsWith('openid-configuration')).length, 1);
      expect(manager.currentUser, isNull);
      await manager.dispose();
    });

    test(
      'a locally-restored (unverified) user is available immediately after '
      'init() returns, before any network I/O',
      () async {
        final net = <String>[];
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(),
        );
        final manager = _lazyManager(store: store, client: _client(net));

        await manager.init();

        // Right after init() resolves, the background revalidation has not yet
        // performed any network request (it is gated on the completed
        // initFuture and only reads the store first).
        expect(net, isEmpty);
        expect(manager.currentUser, isNotNull);
        // Locally restored, not yet verified against the network.
        expect(manager.currentUser!.parsedIdToken.isVerified, isNull);
        await manager.dispose();
      },
    );
  });

  group('blockingValidate init (escape hatch)', () {
    test('fully verifies the cached user before init() completes', () async {
      final net = <String>[];
      final store = await _seededStore(
        discoveryMetadata: jsonEncode(_metadataJson()),
        discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
        tokenJson: _tokenJson(),
      );
      final manager = _lazyManager(
        store: store,
        client: _client(net),
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('app://cb'),
          initMode: OidcInitMode.blockingValidate,
        ),
      );

      await manager.init();

      // The user is already verified when init() returns (no background pass),
      // and userinfo was called synchronously as part of init().
      expect(manager.currentUser, isNotNull);
      expect(manager.currentUser!.parsedIdToken.isVerified, isTrue);
      expect(net.where((p) => p.endsWith('/userinfo')).length, 1);
      await manager.dispose();
    });
  });

  group('discovery document TTL cache', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);

    test('within TTL skips the network fetch', () async {
      await withClock(Clock.fixed(t0), () async {
        final net = <String>[];
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: t0.millisecondsSinceEpoch,
        );
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('app://cb'),
            initMode: OidcInitMode.blockingValidate,
          ),
        );

        await manager.init();

        expect(net.where((p) => p.endsWith('openid-configuration')), isEmpty);
        expect(manager.discoveryDocument.issuer.toString(), _issuer);
        await manager.dispose();
      });
    });

    test('beyond TTL re-fetches and refreshes the timestamp', () async {
      final net = <String>[];
      final store = await _seededStore(
        discoveryMetadata: jsonEncode(_metadataJson()),
        // Seeded 2 days ago -> stale against the 1-day default.
        discoveryTimestampMs: t0
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
      );
      await withClock(Clock.fixed(t0), () async {
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('app://cb'),
            initMode: OidcInitMode.blockingValidate,
          ),
        );

        await manager.init();

        expect(
          net.where((p) => p.endsWith('openid-configuration')).length,
          1,
        );
        await manager.dispose();
      });
      // The sidecar timestamp was refreshed to "now".
      final sidecar = await store.get(
        OidcStoreNamespace.discoveryDocument,
        key: '$_wellKnown::oidc_discovery_fetched_at',
      );
      expect(sidecar, t0.millisecondsSinceEpoch.toString());
    });

    test('beyond TTL but offline serves the stale cached document', () async {
      final net = <String>[];
      final store = await _seededStore(
        discoveryMetadata: jsonEncode(_metadataJson()),
        discoveryTimestampMs: t0
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
      );
      await withClock(Clock.fixed(t0), () async {
        final manager = _lazyManager(
          store: store,
          client: _client(net, failDiscovery: true),
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('app://cb'),
            initMode: OidcInitMode.blockingValidate,
          ),
        );

        // A failing refresh does not throw: the stale cache is served.
        await manager.init();

        expect(
          net.where((p) => p.endsWith('openid-configuration')).length,
          1,
        );
        expect(manager.discoveryDocument.issuer.toString(), _issuer);
        await manager.dispose();
      });
    });
  });

  group('loaded-token validity callbacks (#205)', () {
    OidcUserManagerSettings settings({
      OidcIsLoadedTokenAcceptableCallback? isAcceptable,
      OidcShouldRemoveInvalidTokenCallback? shouldRemove,
    }) => OidcUserManagerSettings(
      redirectUri: Uri.parse('app://cb'),
      initMode: OidcInitMode.blockingValidate,
      userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
      isLoadedTokenAcceptable: isAcceptable,
      shouldRemoveInvalidToken: shouldRemove,
    );

    test(
      'isLoadedTokenAcceptable=true accepts an expired token without '
      'refreshing',
      () async {
        final net = <String>[];
        // Expired id_token WITH a refresh token: default policy would refresh.
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(expiresIn: const Duration(hours: -1)),
            refreshToken: 'rt-cached',
          ),
        );
        List<Exception>? seenErrors;
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: settings(
            isAcceptable: (user, errors) {
              seenErrors = errors;
              return true;
            },
          ),
        );

        await manager.init();

        expect(manager.currentUser, isNotNull);
        // The callback saw the expiry error...
        expect(seenErrors, isNotNull);
        expect(seenErrors, isNotEmpty);
        // ...and accepting short-circuited the refresh (no /token call).
        expect(net.where((p) => p.endsWith('/token')), isEmpty);
        await manager.dispose();
      },
    );

    test(
      'isLoadedTokenAcceptable=false discards and (by default) removes the '
      'tokens',
      () async {
        final net = <String>[];
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(),
        );
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: settings(isAcceptable: (user, errors) => false),
        );

        await manager.init();

        expect(manager.currentUser, isNull);
        final remaining = await store.get(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_Store.currentToken,
        );
        expect(remaining, isNull);
        await manager.dispose();
      },
    );

    test(
      'shouldRemoveInvalidToken=false keeps the discarded tokens',
      () async {
        final net = <String>[];
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(),
        );
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: settings(
            isAcceptable: (user, errors) => false,
            shouldRemove: (user, errors) => false,
          ),
        );

        await manager.init();

        expect(manager.currentUser, isNull);
        // The developer kept the tokens despite the rejection.
        final remaining = await store.get(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_Store.currentToken,
        );
        expect(remaining, isNotNull);
        await manager.dispose();
      },
    );

    test(
      'null callbacks preserve the default behavior (invalid token removed)',
      () async {
        final net = <String>[];
        // A wrong-issuer id_token fails validation; default policy removes it.
        final store = await _seededStore(
          discoveryMetadata: jsonEncode(_metadataJson()),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(issuer: 'https://evil.example.com'),
          ),
        );
        final manager = _lazyManager(
          store: store,
          client: _client(net),
          settings: settings(),
        );

        await manager.init();

        expect(manager.currentUser, isNull);
        final remaining = await store.get(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_Store.currentToken,
        );
        expect(remaining, isNull);
        await manager.dispose();
      },
    );
  });

  group('metadataSeed merge order', () {
    test(
      'fetched values override the seed; seed-only members survive',
      () async {
        final net = <String>[];
        // Fetched document has NO end_session_endpoint and a different issuer.
        final store = await _seededStore();
        final seed = OidcProviderMetadata.fromJson({
          'issuer': 'https://seed.example.com',
          'end_session_endpoint': '$_issuer/logout',
        });
        final manager = _lazyManager(
          store: store,
          client: _client(net, metadata: _metadataJson()),
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('app://cb'),
            initMode: OidcInitMode.blockingValidate,
            metadataSeed: seed,
          ),
        );

        await manager.init();

        // Fetched issuer overrides the seed's issuer.
        expect(manager.discoveryDocument.issuer.toString(), _issuer);
        // Seed-only member is preserved (fetched doc omitted it).
        expect(
          manager.discoveryDocument.endSessionEndpoint.toString(),
          '$_issuer/logout',
        );
        // A fetched-only member is present too.
        expect(
          manager.discoveryDocument.tokenEndpoint.toString(),
          '$_issuer/token',
        );
        await manager.dispose();
      },
    );
  });
}
