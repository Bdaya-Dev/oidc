import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

class _TestUserManager extends OidcUserManagerBase {
  _TestUserManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
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

String _b64UrlJson(Map<String, Object?> json) {
  final bytes = utf8.encode(jsonEncode(json));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _unsignedJwt({
  required String issuer,
  required String audience,
  required String subject,
  required int issuedAt,
  required int expiresAt,
}) {
  final header = <String, Object?>{'alg': 'none', 'typ': 'JWT'};
  final payload = <String, Object?>{
    'iss': issuer,
    'aud': audience,
    'sub': subject,
    'iat': issuedAt,
    'exp': expiresAt,
  };
  // Compact JWS has 3 parts; with `alg=none` the signature can be empty.
  return '${_b64UrlJson(header)}.${_b64UrlJson(payload)}.';
}

void main() {
  group('OidcUserManagerBase.loginDeviceCodeFlow', () {
    test(
      'polls until success; handles authorization_pending and slow_down',
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

          final nowSeconds =
              DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          final idToken = _unsignedJwt(
            issuer: issuer,
            audience: 'client',
            subject: 'user',
            issuedAt: nowSeconds,
            expiresAt: nowSeconds + 3600,
          );

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
              if (tokenCalls == 1) {
                return http.Response(
                  jsonEncode({'error': 'authorization_pending'}),
                  400,
                );
              }
              if (tokenCalls == 2) {
                return http.Response(jsonEncode({'error': 'slow_down'}), 400);
              }

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
          );

          OidcUser? result;
          Object? error;

          unawaited(
            manager
                .init()
                .then((_) {
                  return manager.loginDeviceCodeFlow(
                    onVerification: (resp) async {
                      verificationCalls++;
                      expect(resp.deviceCode, 'device-code');
                      expect(resp.userCode, 'user-code');
                      expect(resp.interval, const Duration(seconds: 1));
                    },
                  );
                })
                .then<void>((u) => result = u)
                .catchError((Object e) => error = e),
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

          expect(error, isNull);
          expect(result, isNotNull);
          expect(result!.token.accessToken, 'access-token');

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
