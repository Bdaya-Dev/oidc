@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _issuer = 'https://op.example.com';
final _signingKey = JsonWebKey.generate('RS256');

String _signIdToken({
  String subject = 'user-1',
  Duration expiresIn = const Duration(hours: 1),
  String issuer = _issuer,
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

/// A concrete manager exposing the `@protected` `validateAndSaveUser` surface
/// so the #432 UserInfo-failure log-level fix can be driven directly from a
/// VM test, mirroring the harness in `userinfo_401_reaction_test.dart`.
class _M extends OidcUserManagerBase {
  _M({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  /// Validates a freshly-issued login token; a UserInfo failure here is the
  /// plain (non-401) path that #432 is about.
  Future<OidcUser?> triggerValidate(OidcUser user) =>
      validateAndSaveUser(user: user, metadata: discoveryDocument);

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

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
});

OidcToken _token() => OidcToken(
  creationTime: clock.now(),
  idToken: _signIdToken(),
  accessToken: 'at-seed',
  refreshToken: 'rt-seed',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
);

Future<OidcUser> _seedUser() => OidcUser.fromIdToken(token: _token());

_M _make({required http.Client client}) => _M(
  discoveryDocument: _metadata(),
  clientCredentials: const OidcClientAuthentication.none(clientId: 'client-1'),
  store: OidcMemoryStore(),
  httpClient: client,
  keyStore: JsonWebKeyStore()..addKey(_signingKey),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('com.example.app://cb'),
  ),
);

void main() {
  hierarchicalLoggingEnabled = true;
  Logger('OidcUserManagerBase').level = Level.ALL;

  group('UserInfo failure log level (#432)', () {
    test(
      'a SocketException (device offline) logs WARNING, not SEVERE',
      () async {
        final client = MockClient((req) async {
          if (req.url.path.endsWith('/userinfo')) {
            throw const SocketException('Network is unreachable');
          }
          return http.Response('{}', 404);
        });
        final manager = _make(client: client);
        await manager.init();

        final records = <LogRecord>[];
        final sub = Logger('OidcUserManagerBase').onRecord.listen(
          records.add,
        );

        final result = await manager.triggerValidate(await _seedUser());
        await pumpEventQueue();

        expect(result, isNotNull);
        expect(records.where((r) => r.level == Level.SEVERE), isEmpty);
        expect(
          records.where(
            (r) =>
                r.level == Level.WARNING &&
                r.message.contains('UserInfo endpoint threw an exception!'),
          ),
          hasLength(1),
        );

        await sub.cancel();
        await manager.dispose();
      },
    );

    test('a FormatException (unclassified) still logs SEVERE', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/userinfo')) {
          throw const FormatException('malformed response');
        }
        return http.Response('{}', 404);
      });
      final manager = _make(client: client);
      await manager.init();

      final records = <LogRecord>[];
      final sub = Logger('OidcUserManagerBase').onRecord.listen(records.add);

      final result = await manager.triggerValidate(await _seedUser());
      await pumpEventQueue();

      expect(result, isNotNull);
      expect(
        records.where(
          (r) =>
              r.level == Level.SEVERE &&
              r.message.contains('UserInfo endpoint threw an exception!'),
        ),
        hasLength(1),
      );

      await sub.cancel();
      await manager.dispose();
    });
  });
}
