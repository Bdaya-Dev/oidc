@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// OIDC Discovery 1.0 §4.3 / RFC 8414 §3.3: a discovery document whose
/// `issuer` is not identical to the issuer it was fetched for MUST NOT be used.
///
/// These tests run with the DEFAULT settings (no `strictIssuerValidation`
/// override): the conformance suite's
/// `oidcc-client-test-discovery-issuer-mismatch` module showed the RP warning
/// and then proceeding to `/authorize` with the mismatched document.
class _DiscoveryManager extends OidcUserManagerBase {
  _DiscoveryManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  }) : super.lazy();

  _DiscoveryManager.eager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
  });

  /// The authorization endpoint of every authorization request built.
  final authorizeEndpoints = <Uri?>[];

  @override
  bool get isWeb => false;
  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    authorizeEndpoints.add(metadata.authorizationEndpoint);
    return null;
  }

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

const _clientCreds = OidcClientAuthentication.none(clientId: 'client-1');
final Uri _redirect = Uri.parse('com.example.app://cb');

Map<String, dynamic> _doc(String? issuer) => {
  'issuer': ?issuer,
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
};

/// Serves [doc] for every request and records each requested URL.
http.Client _serving(Map<String, dynamic> doc, [List<Uri>? requests]) =>
    MockClient((req) async {
      requests?.add(req.url);
      return http.Response(
        jsonEncode(doc),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

_DiscoveryManager _lazy({
  required Uri wellKnown,
  required http.Client client,
  Uri? expectedIssuer,
  bool? strict,
  OidcStore? store,
  OidcInitMode initMode = OidcInitMode.blockingValidate,
}) => _DiscoveryManager.lazy(
  discoveryDocumentUri: wellKnown,
  clientCredentials: _clientCreds,
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  settings: strict == null
      ? OidcUserManagerSettings(
          redirectUri: _redirect,
          expectedIssuer: expectedIssuer,
          initMode: initMode,
        )
      : OidcUserManagerSettings(
          redirectUri: _redirect,
          expectedIssuer: expectedIssuer,
          initMode: initMode,
          strictIssuerValidation: strict,
        ),
);

Matcher _throwsMismatch() => throwsA(
  isA<OidcException>().having(
    (e) => e.message,
    'message',
    contains('Issuer mismatch'),
  ),
);

Uri _wk(String issuer) =>
    OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(issuer));

void main() {
  test('strictIssuerValidation defaults to true', () {
    expect(
      OidcUserManagerSettings(redirectUri: _redirect).strictIssuerValidation,
      isTrue,
    );
  });

  group('default settings, network-fetched document', () {
    test(
      'conformance shape: issuer mismatch => init throws, nothing persisted, '
      'no request beyond the discovery fetch',
      () async {
        const issuer = 'https://op.example.com/test/m3jg';
        final requests = <Uri>[];
        final m = _lazy(
          wellKnown: _wk(issuer),
          client: _serving(_doc('$issuer/INVALID'), requests),
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(requests, [_wk(issuer)]);
        expect(
          await m.store.get(
            OidcStoreNamespace.discoveryDocument,
            key: _wk(issuer).toString(),
          ),
          isNull,
        );
      },
    );

    test('a different host => init throws', () async {
      final m = _lazy(
        wellKnown: _wk('https://op.example.com'),
        client: _serving(_doc('https://attacker.example')),
      );
      await expectLater(m.init(), _throwsMismatch());
    });

    test('a missing issuer => init throws', () async {
      final m = _lazy(
        wellKnown: _wk('https://op.example.com'),
        client: _serving(_doc(null)),
      );
      await expectLater(m.init(), throwsA(isA<OidcException>()));
    });

    test(
      'identical issuer => init succeeds and the doc is persisted',
      () async {
        final m = _lazy(
          wellKnown: _wk('https://op.example.com/realm'),
          client: _serving(_doc('https://op.example.com/realm')),
        );
        await m.init();
        expect(m.didInit, isTrue);
        expect(
          await m.store.get(
            OidcStoreNamespace.discoveryDocument,
            key: _wk('https://op.example.com/realm').toString(),
          ),
          isNotNull,
        );
      },
    );

    // §4.1 strips a terminating "/" before appending the well-known suffix, so
    // `X` and `X/` share one well-known URL and the URL alone cannot tell which
    // one was meant. The conformance suite's own issuers end in "/".
    test(
      'derived expected issuer: a trailing-slash issuer (conformance suite) '
      '=> init succeeds',
      () async {
        final m = _lazy(
          wellKnown: _wk('https://op.example.com/test/m3jg'),
          client: _serving(_doc('https://op.example.com/test/m3jg/')),
        );
        await m.init();
        expect(m.didInit, isTrue);
      },
    );

    test(
      'derived expected issuer: a bare-origin issuer with "/" (Auth0 shape) '
      '=> init succeeds',
      () async {
        final m = _lazy(
          wellKnown: _wk('https://tenant.auth0.example'),
          client: _serving(_doc('https://tenant.auth0.example/')),
        );
        await m.init();
        expect(m.didInit, isTrue);
      },
    );

    test(
      'derived expected issuer: extra segment after the trailing slash => '
      'init throws',
      () async {
        final m = _lazy(
          wellKnown: _wk('https://op.example.com/test/m3jg'),
          client: _serving(_doc('https://op.example.com/test/m3jg/x')),
        );
        await expectLater(m.init(), _throwsMismatch());
      },
    );

    test(
      'explicit expectedIssuer: the trailing slash stays significant',
      () async {
        final m = _lazy(
          wellKnown: _wk('https://op.example.com/realm'),
          client: _serving(_doc('https://op.example.com/realm/')),
          expectedIssuer: Uri.parse('https://op.example.com/realm'),
        );
        await expectLater(m.init(), _throwsMismatch());
      },
    );

    test('RFC 8414 well-known layout: mismatch => init throws', () async {
      final wk = OidcUtils.getOAuthAuthServerWellKnownUri(
        Uri.parse('https://as.example.com/tenant1'),
      );
      final m = _lazy(
        wellKnown: wk,
        client: _serving(_doc('https://as.example.com/tenant2')),
      );
      await expectLater(m.init(), _throwsMismatch());
    });

    test('RFC 8414 well-known layout: identical => init succeeds', () async {
      final wk = OidcUtils.getOAuthAuthServerWellKnownUri(
        Uri.parse('https://as.example.com/tenant1'),
      );
      final m = _lazy(
        wellKnown: wk,
        client: _serving(_doc('https://as.example.com/tenant1')),
      );
      await m.init();
      expect(m.didInit, isTrue);
    });

    test('opting out (strictIssuerValidation: false) still works', () async {
      final m = _lazy(
        wellKnown: _wk('https://op.example.com'),
        client: _serving(_doc('https://attacker.example')),
        strict: false,
      );
      await m.init();
      expect(m.didInit, isTrue);
    });
  });

  group('cached document', () {
    const issuer = 'https://op.example.com';

    Future<OidcMemoryStore> seeded(String cachedIssuer) async {
      final store = OidcMemoryStore();
      await store.init();
      await store.setMany(
        OidcStoreNamespace.discoveryDocument,
        values: {
          _wk(issuer).toString(): jsonEncode(_doc(cachedIssuer)),
          '${_wk(issuer)}${OidcUserManagerBase.discoveryFetchedAtSuffix}': clock
              .now()
              .toUtc()
              .millisecondsSinceEpoch
              .toString(),
        },
      );
      return store;
    }

    test(
      'fresh (within TTL) cached doc with a bad issuer is discarded and '
      're-fetched; a good network doc replaces it',
      () async {
        final store = await seeded('https://attacker.example');
        final requests = <Uri>[];
        final m = _lazy(
          wellKnown: _wk(issuer),
          client: _serving(_doc(issuer), requests),
          store: store,
        );
        await m.init();
        expect(m.discoveryDocument.issuer, Uri.parse(issuer));
        expect(requests, [_wk(issuer)]);
        final persisted = await store.get(
          OidcStoreNamespace.discoveryDocument,
          key: _wk(issuer).toString(),
        );
        expect(jsonDecode(persisted!), containsPair('issuer', issuer));
      },
    );

    test(
      'fresh cached doc with a bad issuer and a bad network doc => throws',
      () async {
        final store = await seeded('https://attacker.example');
        final m = _lazy(
          wellKnown: _wk(issuer),
          client: _serving(_doc('https://attacker.example')),
          store: store,
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(
          await store.getMany(
            OidcStoreNamespace.discoveryDocument,
            keys: {
              _wk(issuer).toString(),
              '${_wk(issuer)}${OidcUserManagerBase.discoveryFetchedAtSuffix}',
            },
          ),
          isEmpty,
          reason: 'the rejected cached document must be removed from the store',
        );
      },
    );

    test('fresh cached doc with a good issuer is used offline', () async {
      final store = await seeded(issuer);
      final requests = <Uri>[];
      final m = _lazy(
        wellKnown: _wk(issuer),
        client: _serving(_doc('https://unused.example'), requests),
        store: store,
      );
      await m.init();
      expect(m.didInit, isTrue);
      expect(requests, isEmpty);
    });

    test(
      'cache-first init with a cached token: a bad cached doc is not used to '
      'restore the session',
      () async {
        final store = await seeded('https://attacker.example');
        await store.set(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_Store.currentToken,
          value: jsonEncode({'access_token': 'at'}),
        );
        final m = _lazy(
          wellKnown: _wk(issuer),
          client: _serving(_doc('https://attacker.example')),
          store: store,
          initMode: OidcInitMode.cacheFirst,
        );
        await expectLater(m.init(), _throwsMismatch());
      },
    );

    test(
      'cache-first init with a restorable cached session: a bad cached doc is '
      'discarded and the blocking path fetches the good one',
      () async {
        final store = await seeded('https://attacker.example');
        String b64(Map<String, dynamic> m) =>
            base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
        final now = clock.now().millisecondsSinceEpoch ~/ 1000;
        final idToken = [
          b64({'alg': 'RS256', 'typ': 'JWT'}),
          b64({
            'iss': 'https://attacker.example',
            'sub': 'user-1',
            'aud': 'client-1',
            'iat': now,
            'exp': now + 3600,
          }),
          'c2ln',
        ].join('.');
        await store.set(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_Store.currentToken,
          value: jsonEncode({
            'access_token': 'at',
            'id_token': idToken,
            'token_type': 'Bearer',
            'expires_in': 3600,
            OidcConstants_Store.expiresInReferenceDate: clock
                .now()
                .toUtc()
                .toIso8601String(),
          }),
        );
        final m = _lazy(
          wellKnown: _wk(issuer),
          client: _serving(_doc(issuer)),
          store: store,
          initMode: OidcInitMode.cacheFirst,
        );
        await m.init();
        expect(m.discoveryDocument.issuer, Uri.parse(issuer));
      },
    );
  });

  group('WebFinger issuer discovery (OIDC Discovery §2)', () {
    const wfIssuer = 'https://op.example.com/wf';

    http.Client wfClient(String discoveryIssuer) => MockClient((req) async {
      if (req.url.path == '/.well-known/webfinger') {
        return http.Response(
          jsonEncode({
            'subject': 'acct:joe@example.com',
            'links': [
              {
                'rel': OidcConstants_WebFinger.relOpenIdIssuer,
                'href': wfIssuer,
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/jrd+json'},
        );
      }
      return http.Response(
        jsonEncode(_doc(discoveryIssuer)),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    test(
      'discovered issuer differs from the WebFinger issuer => init throws',
      () async {
        final client = wfClient('https://evil.example.com/wf');
        final issuer = await OidcEndpoints.getIssuerViaWebFinger(
          'joe@example.com',
          client: client,
        );
        final m = _lazy(
          wellKnown: OidcUtils.getOpenIdConfigWellKnownUri(issuer),
          client: client,
        );
        await expectLater(m.init(), _throwsMismatch());
      },
    );

    test('discovered issuer equals the WebFinger issuer => ok', () async {
      final client = wfClient(wfIssuer);
      final issuer = await OidcEndpoints.getIssuerViaWebFinger(
        'joe@example.com',
        client: client,
      );
      final m = _lazy(
        wellKnown: OidcUtils.getOpenIdConfigWellKnownUri(issuer),
        client: client,
        expectedIssuer: issuer,
      );
      await m.init();
      expect(m.didInit, isTrue);
    });
  });

  group('Microsoft Entra ID multi-tenant (#168 / #389)', () {
    // What `.../common/v2.0/.well-known/openid-configuration` really returns.
    const template = 'https://login.microsoftonline.com/{tenantid}/v2.0';
    final commonWellKnown = _wk(
      'https://login.microsoftonline.com/common/v2.0',
    );

    test(
      'expectedIssuer pinned to a concrete tenant (the #389 setup) vs the '
      'templated discovery issuer => init succeeds',
      () async {
        final m = _lazy(
          wellKnown: commonWellKnown,
          client: _serving(_doc(template)),
          expectedIssuer: Uri.parse(
            'https://login.microsoftonline.com/'
            '9188040d-6c67-4c5b-b112-36a304b66dad/v2.0',
          ),
        );
        await m.init();
        expect(m.didInit, isTrue);
      },
    );

    test('unpinned `common` authority vs the template => ok', () async {
      final m = _lazy(
        wellKnown: commonWellKnown,
        client: _serving(_doc(template)),
      );
      await m.init();
      expect(m.didInit, isTrue);
    });

    test('the template does not cover a different host', () async {
      final m = _lazy(
        wellKnown: commonWellKnown,
        client: _serving(_doc('https://evil.example.com/{tenantid}/v2.0')),
      );
      await expectLater(m.init(), _throwsMismatch());
    });

    test('the template does not cover a different path suffix', () async {
      final m = _lazy(
        wellKnown: commonWellKnown,
        client: _serving(
          _doc('https://login.microsoftonline.com/{tenantid}/v1.0'),
        ),
      );
      await expectLater(m.init(), _throwsMismatch());
    });

    test(
      'Azure AD B2C-style mismatch needs an explicit expectedIssuer',
      () async {
        final wk = _wk(
          'https://contoso.b2clogin.example/contoso.onmicrosoft.com/b2c_1_signin/v2.0',
        );
        const b2cIssuer =
            'https://contoso.b2clogin.example/775527ff-9a37-4307-8b3d-cc311f58d925/v2.0/';
        await expectLater(
          _lazy(wellKnown: wk, client: _serving(_doc(b2cIssuer))).init(),
          _throwsMismatch(),
        );
        final pinned = _lazy(
          wellKnown: wk,
          client: _serving(_doc(b2cIssuer)),
          expectedIssuer: Uri.parse(b2cIssuer),
        );
        await pinned.init();
        expect(pinned.didInit, isTrue);
      },
    );
  });

  group('pre-fetched (eager) document', () {
    _DiscoveryManager eager(String issuer, {Uri? expectedIssuer}) =>
        _DiscoveryManager.eager(
          discoveryDocument: OidcProviderMetadata.fromJson(_doc(issuer)),
          clientCredentials: _clientCreds,
          store: OidcMemoryStore(),
          settings: OidcUserManagerSettings(
            redirectUri: _redirect,
            expectedIssuer: expectedIssuer,
          ),
        );

    test('no expectedIssuer => trusted as supplied (not broken)', () async {
      final m = eager('https://op.example.com');
      await m.init();
      expect(m.didInit, isTrue);
    });

    test('expectedIssuer mismatch => init throws', () async {
      final m = eager(
        'https://op.example.com',
        expectedIssuer: Uri.parse('https://other.example.com'),
      );
      await expectLater(m.init(), _throwsMismatch());
      expect(() => m.discoveryDocument, throwsA(isA<OidcException>()));
    });
  });

  group('OidcUtils.getIssuerFromWellKnownUri', () {
    test('OIDC §4.1 layout', () {
      expect(
        OidcUtils.getIssuerFromWellKnownUri(_wk('https://op.example.com/a/b')),
        Uri.parse('https://op.example.com/a/b'),
      );
    });

    test('RFC 8414 §3.1 layout', () {
      expect(
        OidcUtils.getIssuerFromWellKnownUri(
          Uri.parse(
            'https://as.example.com/.well-known/oauth-authorization-server/t1',
          ),
        ),
        Uri.parse('https://as.example.com/t1'),
      );
      expect(
        OidcUtils.getIssuerFromWellKnownUri(
          Uri.parse(
            'https://as.example.com/.well-known/oauth-authorization-server',
          ),
        ),
        Uri.parse('https://as.example.com'),
      );
    });

    test('anything else => null', () {
      expect(
        OidcUtils.getIssuerFromWellKnownUri(
          Uri.parse('https://op.example.com/custom/discovery.json'),
        ),
        isNull,
      );
    });
  });

  test(
    'discoveryIssuerMatches: malformed percent-encoding is a mismatch, not '
    'a FormatException',
    () {
      expect(
        OidcUtils.discoveryIssuerMatches(
          Uri.parse('https://op.example.com/common/v2.0'),
          Uri.parse('https://op.example.com/%FF/v2.0'),
        ),
        isFalse,
      );
    },
  );

  test(
    'malformed percent-encoding in the discovery issuer with strict off => '
    'init still succeeds (warns)',
    () async {
      final m = _lazy(
        wellKnown: _wk('https://op.example.com/common/v2.0'),
        client: _serving(_doc('https://op.example.com/%FF/v2.0')),
        strict: false,
      );
      await m.init();
      expect(m.didInit, isTrue);
    },
  );

  group('a rejected document is never used afterwards', () {
    const good = 'https://op.example.com';
    const evil = 'https://attacker.example';

    Map<String, dynamic> docAt(String issuer, String base) => {
      'issuer': issuer,
      'authorization_endpoint': '$base/authorize',
      'token_endpoint': '$base/token',
    };

    test(
      'blocking init: after "Issuer mismatch", discoveryDocument and the '
      'login flows refuse to run instead of using the rejected document',
      () async {
        final m = _lazy(
          wellKnown: _wk(good),
          client: _serving(docAt('$good/other', evil)),
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(
          () => m.discoveryDocument,
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('init() failed'),
            ),
          ),
        );
        // getAccessToken() used to return null here; it now throws too.
        await expectLater(m.getAccessToken(), throwsA(isA<OidcException>()));
        await expectLater(
          m.loginAuthorizationCodeFlow(),
          throwsA(isA<OidcException>()),
        );
        expect(m.authorizeEndpoints, isEmpty);
      },
    );

    test(
      'blocking init with a stale cached doc: a rejected network doc does '
      'not leave the unvalidated cache (or itself) in use',
      () async {
        final store = OidcMemoryStore();
        await store.init();
        await store.setMany(
          OidcStoreNamespace.discoveryDocument,
          values: {_wk(good).toString(): jsonEncode(docAt(evil, evil))},
        );
        final m = _lazy(
          wellKnown: _wk(good),
          client: _serving(docAt(evil, evil)),
          store: store,
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(() => m.discoveryDocument, throwsA(isA<OidcException>()));
      },
    );

    /// A store holding a STALE but valid cached document for [good] and a
    /// restorable cached session whose id_token cannot be verified (no
    /// jwks_uri, junk signature), so a real re-verification rejects it.
    Future<OidcMemoryStore> staleGoodCacheWithSession() async {
      final store = OidcMemoryStore();
      await store.init();
      final staleAt = clock
          .now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .millisecondsSinceEpoch;
      await store.setMany(
        OidcStoreNamespace.discoveryDocument,
        values: {
          _wk(good).toString(): jsonEncode(docAt(good, good)),
          '${_wk(good)}${OidcUserManagerBase.discoveryFetchedAtSuffix}': staleAt
              .toString(),
        },
      );
      String b64(Map<String, dynamic> m) =>
          base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      final now = clock.now().millisecondsSinceEpoch ~/ 1000;
      final idToken = [
        b64({'alg': 'RS256', 'typ': 'JWT'}),
        b64({
          'iss': good,
          'sub': 'user-1',
          'aud': 'client-1',
          'iat': now,
          'exp': now + 3600,
        }),
        'c2ln',
      ].join('.');
      await store.set(
        OidcStoreNamespace.secureTokens,
        key: OidcConstants_Store.currentToken,
        value: jsonEncode({
          'access_token': 'at',
          'refresh_token': 'rt',
          'id_token': idToken,
          'token_type': 'Bearer',
          'expires_in': 3600,
          OidcConstants_Store.expiresInReferenceDate: clock
              .now()
              .toUtc()
              .toIso8601String(),
        }),
      );
      return store;
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
    }

    test(
      'cache-first background refresh: a stale validated doc stays in use '
      'when the network serves a mismatched one',
      () async {
        final requests = <Uri>[];
        final m = _lazy(
          wellKnown: _wk(good),
          client: _serving(docAt(evil, evil), requests),
          store: await staleGoodCacheWithSession(),
          initMode: OidcInitMode.cacheFirst,
        );
        await m.init();
        // Let the background revalidation (stale => network fetch) settle.
        await settle();
        expect(requests, contains(_wk(good)));
        expect(m.discoveryDocument.issuer, Uri.parse(good));
        expect(m.discoveryDocument.tokenEndpoint, Uri.parse('$good/token'));
        await m.loginAuthorizationCodeFlow();
        expect(m.authorizeEndpoints, [Uri.parse('$good/authorize')]);
        expect(requests.where((u) => u.host == 'attacker.example'), isEmpty);
      },
    );

    // A rejected refresh must behave like an unreachable network: the restored
    // (unverified) session is still re-verified against the kept document.
    test(
      'cache-first background refresh: a rejected document still lets the '
      'restored session be re-verified (and dropped when it fails)',
      () async {
        final m = _lazy(
          wellKnown: _wk(good),
          client: _serving(docAt(evil, evil)),
          store: await staleGoodCacheWithSession(),
          initMode: OidcInitMode.cacheFirst,
        );
        await m.init();
        expect(m.currentUser, isNotNull, reason: 'restored locally first');
        await settle();
        expect(m.currentUser, isNull);
      },
    );

    test(
      'cache-first background refresh while offline: same outcome (the '
      'reference behavior for the rejected case above)',
      () async {
        final m = _lazy(
          wellKnown: _wk(good),
          client: MockClient((req) async => http.Response('', 503)),
          store: await staleGoodCacheWithSession(),
          initMode: OidcInitMode.cacheFirst,
        );
        await m.init();
        await settle();
        expect(m.currentUser, isNull);
      },
    );

    // With a metadataSeed the published fallback is a new (seeded) object, so
    // an identity-based "un-publish on failure" would miss it.
    test(
      'blocking init, stale bad cache, offline, metadataSeed set: the '
      'rejected fallback is not left published',
      () async {
        final store = OidcMemoryStore();
        await store.init();
        await store.setMany(
          OidcStoreNamespace.discoveryDocument,
          values: {_wk(good).toString(): jsonEncode(docAt(evil, evil))},
        );
        final m = _DiscoveryManager.lazy(
          discoveryDocumentUri: _wk(good),
          clientCredentials: _clientCreds,
          store: store,
          httpClient: MockClient((req) async => http.Response('', 503)),
          settings: OidcUserManagerSettings(
            redirectUri: _redirect,
            initMode: OidcInitMode.blockingValidate,
            metadataSeed: OidcProviderMetadata.fromJson(const {
              'scopes_supported': ['openid'],
            }),
          ),
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(() => m.discoveryDocument, throwsA(isA<OidcException>()));
        await expectLater(
          m.loginAuthorizationCodeFlow(),
          throwsA(isA<OidcException>()),
        );
        expect(m.authorizeEndpoints, isEmpty);
      },
    );

    test(
      'blocking init, stale bad cache, offline: the fallback is checked '
      'before it is published',
      () async {
        final store = OidcMemoryStore();
        await store.init();
        await store.setMany(
          OidcStoreNamespace.discoveryDocument,
          values: {_wk(good).toString(): jsonEncode(docAt(evil, evil))},
        );
        final m = _lazy(
          wellKnown: _wk(good),
          client: MockClient((req) async => http.Response('', 503)),
          store: store,
        );
        await expectLater(m.init(), _throwsMismatch());
        expect(() => m.discoveryDocument, throwsA(isA<OidcException>()));
        await expectLater(
          m.loginAuthorizationCodeFlow(),
          throwsA(isA<OidcException>()),
        );
        expect(m.authorizeEndpoints, isEmpty);
      },
    );

    test(
      'a flow called while init() is still running says so (not "failed")',
      () async {
        final gate = Completer<void>();
        final m = _lazy(
          wellKnown: _wk(good),
          client: MockClient((req) async {
            await gate.future;
            return http.Response(
              jsonEncode(docAt(good, good)),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }),
        );
        final init = m.init();
        expect(
          () => m.discoveryDocument,
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('still running'),
            ),
          ),
        );
        gate.complete();
        await init;
        expect(m.discoveryDocument.issuer, Uri.parse(good));
      },
    );
  });
}
