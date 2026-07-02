@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Concrete manager exposing both the lazy (URL-derived) and eager
/// (document-supplied) discovery paths.
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

Map<String, dynamic> _doc({String? issuer}) => {
  'issuer': ?issuer,
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
};

http.Client _serving(Map<String, dynamic> doc) => MockClient(
  (req) async => http.Response(
    jsonEncode(doc),
    200,
    headers: const {'content-type': 'application/json'},
  ),
);

http.Client _offline() => MockClient((req) async => http.Response('', 503));

_DiscoveryManager _lazy({
  required Uri wellKnown,
  required http.Client client,
  bool strict = false,
  Uri? expectedIssuer,
  OidcStore? store,
}) => _DiscoveryManager.lazy(
  discoveryDocumentUri: wellKnown,
  clientCredentials: _clientCreds,
  store: store ?? OidcMemoryStore(),
  httpClient: client,
  settings: OidcUserManagerSettings(
    redirectUri: _redirect,
    strictIssuerValidation: strict,
    expectedIssuer: expectedIssuer,
  ),
);

_DiscoveryManager _eager({
  required String issuer,
  bool strict = false,
  Uri? expectedIssuer,
}) => _DiscoveryManager.eager(
  discoveryDocument: OidcProviderMetadata.fromJson(_doc(issuer: issuer)),
  clientCredentials: _clientCreds,
  store: OidcMemoryStore(),
  settings: OidcUserManagerSettings(
    redirectUri: _redirect,
    strictIssuerValidation: strict,
    expectedIssuer: expectedIssuer,
  ),
);

Future<List<LogRecord>> _capture(Future<void> Function() action) async {
  final records = <LogRecord>[];
  final prev = Logger.root.level;
  Logger.root.level = Level.ALL;
  final sub = Logger.root.onRecord.listen(records.add);
  try {
    await action();
  } finally {
    await sub.cancel();
    Logger.root.level = prev;
  }
  return records;
}

void main() {
  final opWellKnown = OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse('https://op.example.com'),
  );

  group('strict ON', () {
    test('matching issuer => init succeeds and the doc is persisted', () async {
      final m = _lazy(
        wellKnown: opWellKnown,
        client: _serving(_doc(issuer: 'https://op.example.com')),
        strict: true,
      );
      await m.init();
      expect(m.discoveryDocument.issuer.toString(), 'https://op.example.com');
      final persisted = await m.store.get(
        OidcStoreNamespace.discoveryDocument,
        key: opWellKnown.toString(),
      );
      expect(persisted, isNotNull);
    });

    test(
      'mismatched issuer => init throws "Issuer mismatch" and the doc is NOT '
      'persisted',
      () async {
        final m = _lazy(
          wellKnown: opWellKnown,
          client: _serving(_doc(issuer: 'https://attacker.example')),
          strict: true,
        );
        await expectLater(
          m.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('Issuer mismatch'),
            ),
          ),
        );
        final persisted = await m.store.get(
          OidcStoreNamespace.discoveryDocument,
          key: opWellKnown.toString(),
        );
        expect(
          persisted,
          isNull,
          reason: 'a mismatched doc must not be stored',
        );
      },
    );

    test('issuer omitted/null => throws "missing required issuer"', () async {
      final m = _lazy(
        wellKnown: opWellKnown,
        client: _serving(_doc()),
        strict: true,
      );
      await expectLater(
        m.init(),
        throwsA(
          isA<OidcException>().having(
            (e) => e.message,
            'message',
            contains('missing the required `issuer`'),
          ),
        ),
      );
    });

    test('case-folding scheme/host => identical => init succeeds', () async {
      // Explicit expectedIssuer with uppercase host vs lowercase doc issuer.
      final m = _lazy(
        wellKnown: opWellKnown,
        client: _serving(_doc(issuer: 'https://op.example.com')),
        strict: true,
        expectedIssuer: Uri.parse('https://OP.Example.com'),
      );
      await m.init();
      expect(m.didInit, isTrue);
    });

    test(
      'trailing-slash difference is significant => throws (needs explicit '
      'expectedIssuer)',
      () async {
        final m = _lazy(
          wellKnown: opWellKnown,
          client: _serving(_doc(issuer: 'https://op.example.com/realm/')),
          strict: true,
          expectedIssuer: Uri.parse('https://op.example.com/realm'),
        );
        await expectLater(
          m.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('Issuer mismatch'),
            ),
          ),
        );
      },
    );
  });

  group('strict OFF (default)', () {
    test(
      'mismatched issuer => init succeeds, doc persisted, exactly one warning',
      () async {
        late _DiscoveryManager m;
        final records = await _capture(() async {
          m = _lazy(
            wellKnown: opWellKnown,
            client: _serving(_doc(issuer: 'https://attacker.example')),
          );
          await m.init();
        });
        expect(m.didInit, isTrue);
        final persisted = await m.store.get(
          OidcStoreNamespace.discoveryDocument,
          key: opWellKnown.toString(),
        );
        expect(persisted, isNotNull);
        final mismatchWarnings = records.where(
          (r) =>
              r.level == Level.WARNING && r.message.contains('Issuer mismatch'),
        );
        expect(mismatchWarnings, hasLength(1));
      },
    );
  });

  group('explicit expectedIssuer overrides derivation', () {
    test('expectedIssuer matches doc issuer => pass (strict)', () async {
      final m = _lazy(
        wellKnown: opWellKnown,
        client: _serving(_doc(issuer: 'https://op.example.com')),
        strict: true,
        expectedIssuer: Uri.parse('https://op.example.com'),
      );
      await m.init();
      expect(m.didInit, isTrue);
    });

    test('expectedIssuer differs from doc issuer => throw (strict)', () async {
      final m = _lazy(
        wellKnown: opWellKnown,
        client: _serving(_doc(issuer: 'https://op.example.com')),
        strict: true,
        expectedIssuer: Uri.parse('https://other.example.com'),
      );
      await expectLater(m.init(), throwsA(isA<OidcException>()));
    });
  });

  group('Microsoft Entra multi-tenant', () {
    final entraWellKnown = OidcUtils.getOpenIdConfigWellKnownUri(
      Uri.parse('https://login.microsoftonline.com/common/v2.0'),
    );
    const tenantIssuer = 'https://login.microsoftonline.com/tenant-abc/v2.0';

    test(
      'strict OFF => succeeds + warns (out-of-the-box non-breakage)',
      () async {
        late _DiscoveryManager m;
        final records = await _capture(() async {
          m = _lazy(
            wellKnown: entraWellKnown,
            client: _serving(_doc(issuer: tenantIssuer)),
          );
          await m.init();
        });
        expect(m.didInit, isTrue);
        expect(
          records.where(
            (r) =>
                r.level == Level.WARNING &&
                r.message.contains('Issuer mismatch'),
          ),
          hasLength(1),
        );
      },
    );

    test(
      'strict ON, no expectedIssuer => throws (documents the tradeoff)',
      () async {
        final m = _lazy(
          wellKnown: entraWellKnown,
          client: _serving(_doc(issuer: tenantIssuer)),
          strict: true,
        );
        await expectLater(m.init(), throwsA(isA<OidcException>()));
      },
    );

    test(
      'strict ON with expectedIssuer set => succeeds (escape hatch)',
      () async {
        final m = _lazy(
          wellKnown: entraWellKnown,
          client: _serving(_doc(issuer: tenantIssuer)),
          strict: true,
          expectedIssuer: Uri.parse(tenantIssuer),
        );
        await m.init();
        expect(m.didInit, isTrue);
      },
    );
  });

  group('eager constructor (discoveryDocumentUri == null)', () {
    test('strict ON, no expectedIssuer => warning, no throw', () async {
      late _DiscoveryManager m;
      final records = await _capture(() async {
        m = _eager(issuer: 'https://op.example.com', strict: true);
        await m.init();
      });
      expect(m.didInit, isTrue);
      expect(
        records.where(
          (r) =>
              r.level == Level.WARNING &&
              r.message.contains('no expected issuer could be determined'),
        ),
        hasLength(1),
      );
    });

    test(
      'strict ON, expectedIssuer matches the supplied doc => pass',
      () async {
        final m = _eager(
          issuer: 'https://op.example.com',
          strict: true,
          expectedIssuer: Uri.parse('https://op.example.com'),
        );
        await m.init();
        expect(m.didInit, isTrue);
      },
    );

    test('strict ON, expectedIssuer mismatches => throw', () async {
      final m = _eager(
        issuer: 'https://op.example.com',
        strict: true,
        expectedIssuer: Uri.parse('https://attacker.example'),
      );
      await expectLater(m.init(), throwsA(isA<OidcException>()));
    });
  });

  group('poisoned cache + offline', () {
    test(
      'cached doc with a bad issuer + network unreachable + strict ON => '
      'throws before re-persisting',
      () async {
        final store = OidcMemoryStore();
        await store.init();
        // Seed a poisoned cached discovery document.
        await store.setMany(
          OidcStoreNamespace.discoveryDocument,
          values: {
            opWellKnown.toString(): jsonEncode(
              _doc(issuer: 'https://attacker.example'),
            ),
          },
        );
        final m = _lazy(
          wellKnown: opWellKnown,
          client: _offline(),
          strict: true,
          store: store,
        );
        await expectLater(
          m.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('Issuer mismatch'),
            ),
          ),
        );
      },
    );
  });
}
