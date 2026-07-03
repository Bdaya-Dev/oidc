import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

class _TestUserManager extends OidcUserManagerBase {
  _TestUserManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) {
    return <String, dynamic>{};
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    return const Stream.empty();
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return const Stream.empty();
  }
}

String _signedJwt({
  required JsonWebKey signingKey,
  required String issuer,
  required String audience,
  required String subject,
  required int issuedAt,
  required int expiresAt,
}) {
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': issuer,
          'aud': audience,
          'sub': subject,
          'iat': issuedAt,
          'exp': expiresAt,
        }
        ..addRecipient(signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

void main() {
  group('OidcUserManagerBase.loginDeviceCodeFlow', () {
    // This test exercises ONLY the poll-backoff timing (authorization_pending
    // then slow_down), never the success path — under `fakeAsync`. Real
    // id_token signature verification (always-strict now) is NOT exercised
    // here: `jose_plus`'s key resolution goes through an `async*` Stream that
    // does not settle under `fakeAsync` (a pre-existing jose_plus/fake_async
    // interaction, unrelated to what this test exercises). The success +
    // verification path is covered separately, with real async, below.
    test(
      'polls with authorization_pending/slow_down backoff timing',
      () {
        fakeAsync((async) {
          const issuer = 'https://server.example.com';
          final deviceEndpoint = Uri.parse('$issuer/device');
          final tokenEndpoint = Uri.parse('$issuer/token');

          final metadata = OidcProviderMetadata.fromJson({
            'issuer': issuer,
            'token_endpoint': tokenEndpoint.toString(),
            'device_authorization_endpoint': deviceEndpoint.toString(),
          });

          var tokenCalls = 0;
          final tokenCallOffsets = <Duration>[];
          var verificationCalls = 0;

          final client = MockClient((request) async {
            if (request.url == deviceEndpoint) {
              return http.Response(
                jsonEncode({
                  'device_code': 'device-code',
                  'user_code': 'user-code',
                  'verification_uri': '$issuer/verify',
                  'expires_in': 60,
                  'interval': 1,
                }),
                200,
              );
            }

            if (request.url == tokenEndpoint) {
              tokenCalls++;
              tokenCallOffsets.add(async.elapsed);
              if (tokenCalls == 2) {
                return http.Response(jsonEncode({'error': 'slow_down'}), 400);
              }
              // Stays pending on every other call (including the 3rd) — this
              // test only cares about the interval/backoff timing, never
              // reaches id_token verification.
              return http.Response(
                jsonEncode({'error': 'authorization_pending'}),
                400,
              );
            }

            return http.Response('Not found', 404);
          });

          final settings = OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example:/callback'),
            userInfoSettings: const OidcUserInfoSettings(
              sendUserInfoRequest: false,
            ),
          );

          final manager = _TestUserManager(
            discoveryDocument: metadata,
            clientCredentials: const OidcClientAuthentication.none(
              clientId: 'client',
            ),
            store: OidcMemoryStore(),
            settings: settings,
            httpClient: client,
          );

          unawaited(
            manager.init().then(
              (_) => manager.loginDeviceCodeFlow(
                onVerification: (resp) async {
                  verificationCalls++;
                  expect(resp.deviceCode, 'device-code');
                  expect(resp.userCode, 'user-code');
                  expect(resp.interval, const Duration(seconds: 1));
                },
              ),
            ),
          );

          async
            ..flushMicrotasks()
            // First poll interval.
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks()
            // Second poll interval.
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks()
            // After slow_down, interval increases by 5 seconds.
            ..elapse(const Duration(seconds: 6))
            ..flushMicrotasks();

          expect(verificationCalls, 1);
          expect(tokenCalls, 3);

          expect(tokenCallOffsets, hasLength(3));
          expect(
            tokenCallOffsets[1] - tokenCallOffsets[0],
            const Duration(seconds: 1),
          );
          expect(
            tokenCallOffsets[2] - tokenCallOffsets[1],
            const Duration(seconds: 6),
          );

          unawaited(manager.dispose());
          async.flushMicrotasks();
        });
      },
    );

    test(
      'completes with a verified user when the device flow succeeds',
      () async {
        const issuer = 'https://server.example.com';
        final deviceEndpoint = Uri.parse('$issuer/device');
        final tokenEndpoint = Uri.parse('$issuer/token');

        // Signature verification is always-strict now, so the id_token must
        // be real. The signing key is added directly to the manager's
        // keyStore (rather than served from a mocked `jwks_uri`) so
        // verification resolves it synchronously from memory — see the note
        // on the backoff-timing test above for why this test uses real async
        // instead of `fakeAsync`.
        final signingKey = JsonWebKey.generate('RS256');
        final nowSeconds =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final idToken = _signedJwt(
          signingKey: signingKey,
          issuer: issuer,
          audience: 'client',
          subject: 'user',
          issuedAt: nowSeconds,
          expiresAt: nowSeconds + 3600,
        );

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': issuer,
          'token_endpoint': tokenEndpoint.toString(),
          'device_authorization_endpoint': deviceEndpoint.toString(),
        });

        final client = MockClient((request) async {
          if (request.url == deviceEndpoint) {
            return http.Response(
              jsonEncode({
                'device_code': 'device-code',
                'user_code': 'user-code',
                'verification_uri': '$issuer/verify',
                'expires_in': 60,
                'interval': 0,
              }),
              200,
            );
          }

          if (request.url == tokenEndpoint) {
            return http.Response(
              jsonEncode({
                'access_token': 'access-token',
                'id_token': idToken,
                'token_type': 'Bearer',
                'expires_in': 3600,
              }),
              200,
            );
          }

          return http.Response('Not found', 404);
        });

        final settings = OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example:/callback'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        );

        final manager = _TestUserManager(
          discoveryDocument: metadata,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client',
          ),
          store: OidcMemoryStore(),
          settings: settings,
          httpClient: client,
          keyStore: JsonWebKeyStore()..addKey(signingKey),
        );

        await manager.init();
        final result = await manager.loginDeviceCodeFlow();

        expect(result, isNotNull);
        expect(result!.token.accessToken, 'access-token');
        expect(result.parsedIdToken.isVerified, isTrue);

        await manager.dispose();
      },
    );

    test('returns null on access_denied', () {
      fakeAsync((async) {
        const issuer = 'https://server.example.com';
        final deviceEndpoint = Uri.parse('$issuer/device');
        final tokenEndpoint = Uri.parse('$issuer/token');

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': issuer,
          'token_endpoint': tokenEndpoint.toString(),
          'device_authorization_endpoint': deviceEndpoint.toString(),
        });

        var tokenCalls = 0;
        final client = MockClient((request) async {
          if (request.url == deviceEndpoint) {
            return http.Response(
              jsonEncode({
                'device_code': 'device-code',
                'user_code': 'user-code',
                'verification_uri': '$issuer/verify',
                'expires_in': 60,
                'interval': 1,
              }),
              200,
            );
          }
          if (request.url == tokenEndpoint) {
            tokenCalls++;
            return http.Response(jsonEncode({'error': 'access_denied'}), 400);
          }
          return http.Response('Not found', 404);
        });

        final settings = OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example:/callback'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        );

        final manager = _TestUserManager(
          discoveryDocument: metadata,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client',
          ),
          store: OidcMemoryStore(),
          settings: settings,
          httpClient: client,
        );

        OidcUser? result;
        Object? error;

        unawaited(
          manager
              .init()
              .then((_) => manager.loginDeviceCodeFlow())
              .then<void>((u) => result = u)
              .catchError((Object e) => error = e),
        );

        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(error, isNull);
        expect(result, isNull);
        expect(tokenCalls, 1);

        unawaited(manager.dispose());
        async.flushMicrotasks();
      });
    });

    test('returns null when device_code expires while still pending', () {
      fakeAsync((async) {
        const issuer = 'https://server.example.com';
        final deviceEndpoint = Uri.parse('$issuer/device');
        final tokenEndpoint = Uri.parse('$issuer/token');

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': issuer,
          'token_endpoint': tokenEndpoint.toString(),
          'device_authorization_endpoint': deviceEndpoint.toString(),
        });

        var tokenCalls = 0;
        final client = MockClient((request) async {
          if (request.url == deviceEndpoint) {
            return http.Response(
              jsonEncode({
                'device_code': 'device-code',
                'user_code': 'user-code',
                'verification_uri': '$issuer/verify',
                'expires_in': 2,
                'interval': 1,
              }),
              200,
            );
          }
          if (request.url == tokenEndpoint) {
            tokenCalls++;
            return http.Response(
              jsonEncode({'error': 'authorization_pending'}),
              400,
            );
          }
          return http.Response('Not found', 404);
        });

        final settings = OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example:/callback'),
          userInfoSettings: const OidcUserInfoSettings(
            sendUserInfoRequest: false,
          ),
        );

        final manager = _TestUserManager(
          discoveryDocument: metadata,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client',
          ),
          store: OidcMemoryStore(),
          settings: settings,
          httpClient: client,
        );

        OidcUser? result;
        Object? error;

        unawaited(
          manager
              .init()
              .then((_) => manager.loginDeviceCodeFlow())
              .then<void>((u) => result = u)
              .catchError((Object e) => error = e),
        );

        // Two poll attempts occur before expiry.
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        expect(error, isNull);
        expect(result, isNull);
        expect(tokenCalls, 2);

        unawaited(manager.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
