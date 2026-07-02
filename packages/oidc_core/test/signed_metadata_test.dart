@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Concrete manager exposing the lazy (URL-derived) discovery path.
class _DiscoveryManager extends OidcUserManagerBase {
  _DiscoveryManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
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

const _clientCreds = OidcClientAuthentication.none(clientId: 'client-1');
final Uri _redirect = Uri.parse('com.example.app://cb');
const _issuer = 'https://op.example.com';
final Uri _jwksUri = Uri.parse('https://op.example.com/jwks');
final _signingKey = JsonWebKey.generate('RS256');

String _jwks([JsonWebKey? key]) =>
    jsonEncode(JsonWebKeySet.fromKeys([key ?? _signingKey]).toJson());

String _sign(
  Map<String, dynamic> claims, {
  JsonWebKey? key,
  String alg = 'RS256',
}) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(key ?? _signingKey, algorithm: alg))
        .build()
        .toCompactSerialization();

String _unsigned(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.${seg(claims)}.';
}

Map<String, dynamic> _doc({
  String? signedMetadata,
  String tokenEndpoint = 'https://op.example.com/token',
  bool withJwksUri = true,
  List<String> algs = const ['RS256'],
}) => {
  'issuer': _issuer,
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': tokenEndpoint,
  if (withJwksUri) 'jwks_uri': _jwksUri.toString(),
  'id_token_signing_alg_values_supported': algs,
  'signed_metadata': ?signedMetadata,
};

/// Routing MockClient: serves the discovery doc and the JWKS, recording every
/// requested Uri so tests can assert whether the jwks_uri was fetched.
http.Client _serving({
  required Map<String, dynamic> doc,
  required List<Uri> hits,
  String? jwks,
}) => MockClient((req) async {
  hits.add(req.url);
  if (req.url.path.endsWith('openid-configuration')) {
    return http.Response(
      jsonEncode(doc),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  if (req.url.path.endsWith('/jwks')) {
    return http.Response(
      jwks ?? _jwks(),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
  return http.Response('not found', 404);
});

_DiscoveryManager _manager({
  required Uri wellKnown,
  required http.Client client,
  bool verify = true,
  List<String>? allowedSignedMetadataAlgorithms,
  OidcStore? store,
}) => _DiscoveryManager.lazy(
  discoveryDocumentUri: wellKnown,
  clientCredentials: _clientCreds,
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  settings: OidcUserManagerSettings(
    redirectUri: _redirect,
    verifySignedMetadata: verify,
    allowedSignedMetadataAlgorithms: allowedSignedMetadataAlgorithms,
  ),
);

bool _jwksWasFetched(List<Uri> hits) =>
    hits.any((u) => u.path.endsWith('/jwks'));

void main() {
  final wellKnown = OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(_issuer));

  group('manager integration', () {
    test(
      'absent signed_metadata (verify=true): no merge, no JWKS fetch',
      () async {
        final hits = <Uri>[];
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(doc: _doc(), hits: hits),
        );
        await m.init();
        expect(
          m.discoveryDocument.tokenEndpoint.toString(),
          'https://op.example.com/token',
        );
        expect(_jwksWasFetched(hits), isFalse);
      },
    );

    test(
      'valid signed_metadata but verify=false: ignored, no JWKS fetch',
      () async {
        final hits = <Uri>[];
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: signed),
            hits: hits,
          ),
          verify: false,
        );
        await m.init();
        // Plain value retained (no merge).
        expect(
          m.discoveryDocument.tokenEndpoint.toString(),
          'https://op.example.com/token',
        );
        expect(_jwksWasFetched(hits), isFalse);
      },
    );

    test(
      'valid signed_metadata overrides a plain value (RFC 8414 §3.2)',
      () async {
        final hits = <Uri>[];
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: signed),
            hits: hits,
          ),
        );
        await m.init();
        expect(
          m.discoveryDocument.tokenEndpoint.toString(),
          'https://op.example.com/token-signed',
        );
        expect(_jwksWasFetched(hits), isTrue);
      },
    );

    test(
      'tampered signature + strict => init throws, doc NOT persisted',
      () async {
        final hits = <Uri>[];
        final valid = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final parts = valid.split('.');
        final tamperedPayload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'iss': _issuer,
                  'token_endpoint': 'https://attacker.example/token',
                }),
              ),
            )
            .replaceAll('=', '');
        final tampered = '${parts[0]}.$tamperedPayload.${parts[2]}';
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: tampered),
            hits: hits,
          ),
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
        final persisted = await m.store.get(
          OidcStoreNamespace.discoveryDocument,
          key: wellKnown.toString(),
        );
        expect(persisted, isNull);
      },
    );

    test(
      'alg:none signed_metadata (none advertised) => rejected (strict)',
      () async {
        final unsigned = _unsigned({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: unsigned, algs: const ['RS256', 'none']),
            hits: <Uri>[],
          ),
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
      },
    );

    test(
      'allowedSignedMetadataAlgorithms pins ES256, JWT RS256 => rejected',
      () async {
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: signed),
            hits: <Uri>[],
          ),
          allowedSignedMetadataAlgorithms: const ['ES256'],
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
      },
    );

    test('missing iss claim => rejected (strict)', () async {
      final signed = _sign({
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      final m = _manager(
        wellKnown: wellKnown,
        client: _serving(
          doc: _doc(signedMetadata: signed),
          hits: <Uri>[],
        ),
      );
      await expectLater(m.init(), throwsA(isA<OidcException>()));
    });

    test('iss mismatches expected issuer => rejected (strict)', () async {
      final signed = _sign({
        'iss': 'https://attacker.example',
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      final m = _manager(
        wellKnown: wellKnown,
        client: _serving(
          doc: _doc(signedMetadata: signed),
          hits: <Uri>[],
        ),
      );
      await expectLater(m.init(), throwsA(isA<OidcException>()));
    });

    test(
      'signed_metadata present but no jwks_uri => rejected (strict)',
      () async {
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: signed, withJwksUri: false),
            hits: <Uri>[],
          ),
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
      },
    );

    test('present-and-expired exp => rejected (strict)', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
          'exp':
              clock
                  .now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        });
        final m = _manager(
          wellKnown: wellKnown,
          client: _serving(
            doc: _doc(signedMetadata: signed),
            hits: <Uri>[],
          ),
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
      });
    });

    test('signed_metadata WITHOUT exp => accepted', () async {
      final signed = _sign({
        'iss': _issuer,
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      final m = _manager(
        wellKnown: wellKnown,
        client: _serving(
          doc: _doc(signedMetadata: signed),
          hits: <Uri>[],
        ),
      );
      await m.init();
      expect(
        m.discoveryDocument.tokenEndpoint.toString(),
        'https://op.example.com/token-signed',
      );
    });

    test('persistence: verified+merged doc is the one persisted', () async {
      final signed = _sign({
        'iss': _issuer,
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      final m = _manager(
        wellKnown: wellKnown,
        client: _serving(
          doc: _doc(signedMetadata: signed),
          hits: <Uri>[],
        ),
      );
      await m.init();
      final persisted = await m.store.get(
        OidcStoreNamespace.discoveryDocument,
        key: wellKnown.toString(),
      );
      expect(persisted, isNotNull);
      final parsed = OidcProviderMetadata.fromJson(
        jsonDecode(persisted!) as Map<String, dynamic>,
      );
      expect(
        parsed.tokenEndpoint.toString(),
        'https://op.example.com/token-signed',
      );
    });
  });

  group('pure helper', () {
    OidcProviderMetadata meta({
      String? signedMetadata,
      bool withJwksUri = true,
    }) => OidcProviderMetadata.fromJson(
      _doc(
        signedMetadata: signedMetadata,
        withJwksUri: withJwksUri,
      ),
    );

    http.Client jwksClient([String? jwks]) => MockClient(
      (req) async => http.Response(
        jwks ?? _jwks(),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );

    Future<OidcStore> store() async {
      final s = OidcMemoryStore();
      await s.init();
      return s;
    }

    test('no signed_metadata => returns metadata unchanged', () async {
      final input = meta();
      final out = await OidcEndpoints.verifyAndMergeSignedMetadata(
        metadata: input,
        expectedIssuer: Uri.parse(_issuer),
        cacheStore: await store(),
        client: jwksClient(),
      );
      expect(identical(out, input), isTrue);
    });

    test('valid JWT => returns merged metadata (override)', () async {
      final signed = _sign({
        'iss': _issuer,
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      final out = await OidcEndpoints.verifyAndMergeSignedMetadata(
        metadata: meta(signedMetadata: signed),
        expectedIssuer: Uri.parse(_issuer),
        allowedAlgorithms: const ['RS256'],
        cacheStore: await store(),
        client: jwksClient(),
      );
      expect(
        out.tokenEndpoint.toString(),
        'https://op.example.com/token-signed',
      );
    });

    test('bad signature => throws OidcException', () async {
      final foreign = JsonWebKey.generate('RS256');
      final signed = _sign({
        'iss': _issuer,
        'token_endpoint': 'https://op.example.com/token-signed',
      }, key: foreign);
      await expectLater(
        OidcEndpoints.verifyAndMergeSignedMetadata(
          metadata: meta(signedMetadata: signed),
          expectedIssuer: Uri.parse(_issuer),
          allowedAlgorithms: const ['RS256'],
          cacheStore: await store(),
          client: jwksClient(), // serves the genuine key, not `foreign`
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test(
      'alg:none with a NULL allow-list => rejected '
      '(jose_plus rejects `none` even when no algorithms are pinned)',
      () async {
        // The security of signed_metadata rests on `none` being rejected on
        // BOTH the null and non-null allow-list paths. The non-null path is
        // covered by the manager-integration `alg:none` test; this asserts the
        // null path (allowedAlgorithms omitted) so a regression cannot silently
        // open an alg:none metadata-spoof bypass.
        final unsigned = _unsigned({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-none',
        });
        await expectLater(
          OidcEndpoints.verifyAndMergeSignedMetadata(
            metadata: meta(signedMetadata: unsigned),
            expectedIssuer: Uri.parse(_issuer),
            // allowedAlgorithms intentionally omitted (null).
            cacheStore: await store(),
            client: jwksClient(),
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test('missing iss => throws OidcException', () async {
      final signed = _sign({
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      await expectLater(
        OidcEndpoints.verifyAndMergeSignedMetadata(
          metadata: meta(signedMetadata: signed),
          expectedIssuer: Uri.parse(_issuer),
          allowedAlgorithms: const ['RS256'],
          cacheStore: await store(),
          client: jwksClient(),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('iss mismatch => throws OidcException', () async {
      final signed = _sign({
        'iss': 'https://attacker.example',
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      await expectLater(
        OidcEndpoints.verifyAndMergeSignedMetadata(
          metadata: meta(signedMetadata: signed),
          expectedIssuer: Uri.parse(_issuer),
          allowedAlgorithms: const ['RS256'],
          cacheStore: await store(),
          client: jwksClient(),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('no jwks_uri => throws OidcException', () async {
      final signed = _sign({
        'iss': _issuer,
        'token_endpoint': 'https://op.example.com/token-signed',
      });
      await expectLater(
        OidcEndpoints.verifyAndMergeSignedMetadata(
          metadata: meta(signedMetadata: signed, withJwksUri: false),
          expectedIssuer: Uri.parse(_issuer),
          allowedAlgorithms: const ['RS256'],
          cacheStore: await store(),
          client: jwksClient(),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('expired exp => throws OidcException', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 1, 1, 12)), () async {
        final signed = _sign({
          'iss': _issuer,
          'token_endpoint': 'https://op.example.com/token-signed',
          'exp':
              clock
                  .now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        });
        await expectLater(
          OidcEndpoints.verifyAndMergeSignedMetadata(
            metadata: meta(signedMetadata: signed),
            expectedIssuer: Uri.parse(_issuer),
            allowedAlgorithms: const ['RS256'],
            cacheStore: await store(),
            client: jwksClient(),
          ),
          throwsA(isA<OidcException>()),
        );
      });
    });
  });
}
