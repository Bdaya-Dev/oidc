// ignore_for_file: prefer_single_quotes

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc/oidc.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mock_client.dart';

class MockOidcPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements OidcPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OidcPlatform oidcPlatform;

  const clientCredentials = OidcClientAuthentication.none(
    clientId: 'my_client_id',
  );
  final settings = OidcUserManagerSettings(
    redirectUri: Uri.parse('http://example.com/redirect.html'),
  );
  // Signature verification is always-strict now; every manager below is
  // constructed with a keyStore holding the mock id_tokens' HS256 signing
  // key (see mock_client.dart's `mockSigningKey`) so they verify.
  final managerKeyStore = JsonWebKeyStore()..addKey(mockSigningKey);

  setUp(() {
    oidcPlatform = MockOidcPlatform();
    // `init` subscribes to native browser events; stub the stream so the mock
    // platform doesn't return null for it.
    when(
      oidcPlatform.nativeBrowserEvents,
    ).thenAnswer((_) => const Stream.empty());
    OidcPlatform.instance = oidcPlatform;
  });

  group('OidcUserManager', () {
    group('init', () {
      late OidcProviderMetadata doc;
      late OidcStore store;
      late Client client;
      late OidcUserManager manager;
      setUp(() {
        doc = OidcProviderMetadata.fromJson(mockProviderMetadata);
        store = OidcMemoryStore();
        client = createMockOidcClient();
      });
      test('with document', () async {
        client = createMockOidcClient();
        manager = OidcUserManager(
          discoveryDocument: doc,
          clientCredentials: clientCredentials,
          store: store,
          settings: settings,
          httpClient: client,
          keyStore: managerKeyStore,
          id: 'test-manager',
        );
        expect(manager.didInit, isFalse);
        await manager.init();
        expect(manager.didInit, isTrue);
        expect(manager.discoveryDocument, doc);
        expect(manager.discoveryDocumentUri, isNull);
      });
      test('lazy', () async {
        manager = OidcUserManager.lazy(
          discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://example.com'),
          ),
          clientCredentials: clientCredentials,
          store: store,
          settings: settings,
          httpClient: client,
          keyStore: managerKeyStore,
        );
        expect(manager.didInit, isFalse);
        await manager.init();
        expect(manager.didInit, isTrue);
        expect(manager.discoveryDocument.src, mockProviderMetadata);
        expect(manager.discoveryDocumentUri, isNotNull);
      });

      for (final managerId in [null, 'test-manager']) {
        group('loadCachedToken, managerId: $managerId', () {
          final tokenCreatedAt = DateTime.utc(2024, 03);
          final tokenCreatedAtClock = Clock.fixed(tokenCreatedAt);
          late Clock nowClock;
          // The idToken is created
          late Map<String, dynamic> cachedTokenJson;
          setUp(() async {
            cachedTokenJson = withClock(tokenCreatedAtClock, () {
              return {
                "scope": OidcInternalUtilities.joinSpaceDelimitedList([
                  OidcConstants_Scopes.openid,
                  OidcConstants_Scopes.profile,
                  OidcConstants_Scopes.email,
                  "offline_access",
                ]),
                "access_token": "SlAV32hkKG",
                "token_type": "Bearer",
                "refresh_token": "8xLOxBtZp8",
                "expires_in": const Duration(hours: 1).inSeconds,
                "id_token": createIdToken(
                  claimsJson: defaultIdTokenClaimsJson(),
                ),
                "expiresInReferenceDate": clock.now().toIso8601String(),
                "session_state":
                    "YaSjXERcv7iG5F9euVQ_F4smjyt0jD3sYxARlJdBMVE.9A5536CDE44A8BE6D4F2A9E2ABD73ECF",
              };
            });
            await store.set(
              OidcStoreNamespace.secureTokens,
              key: OidcConstants_Store.currentToken,
              value: jsonEncode(cachedTokenJson),
              managerId: managerId,
            );
            manager = OidcUserManager(
              id: managerId,
              discoveryDocument: doc,
              clientCredentials: clientCredentials,
              store: store,
              settings: settings,
              httpClient: client,
              keyStore: managerKeyStore,
            );
          });

          test('with non-expired token should load the user normally', () async {
            final nowMock = tokenCreatedAt.add(const Duration(minutes: 1));
            nowClock = Clock.fixed(nowMock);

            await withClock(nowClock, () async {
              await manager.init();
            });
            expect(manager.didInit, isTrue);
            expect(manager.currentUser, isNotNull);

            final newToken = manager.currentUser?.token;
            expect(newToken, isNotNull);
            //no refresh is needed, so old token remains
            expect(newToken!.creationTime, tokenCreatedAt);
            final storedToken = await store.get(
              OidcStoreNamespace.secureTokens,
              key: OidcConstants_Store.currentToken,
              managerId: managerId,
            );
            //since no refresh happened AND token is valid, it should remain in the store.
            expect(storedToken, isNotNull);
            expect(jsonDecode(storedToken!), cachedTokenJson);
          });
          test('With expired token should refresh the token', () async {
            //
            final nowMock = tokenCreatedAt.add(const Duration(hours: 2));
            nowClock = Clock.fixed(nowMock);

            await withClock(nowClock, () async {
              await manager.init();
            });
            expect(manager.didInit, isTrue);
            expect(manager.currentUser, isNotNull);

            final newToken = manager.currentUser?.token;
            expect(newToken, isNotNull);
            // A refresh is needed, so creation time should reflect that.
            expect(newToken!.creationTime, nowMock);
            final storedToken = await store.get(
              OidcStoreNamespace.secureTokens,
              key: OidcConstants_Store.currentToken,
              managerId: managerId,
            );
            // a refresh happened, but new token should remain in the store.
            expect(storedToken, isNotNull);
            final decodedStoredToken =
                jsonDecode(storedToken!) as Map<String, dynamic>;

            expect(
              decodedStoredToken[OidcConstants_Store.expiresInReferenceDate],
              nowMock.toIso8601String(),
            );
          });
          test(
            'With expired token and refresh response without id_token should keep cached expired id_token',
            () async {
              client = createMockOidcClient(
                beforeDefault: (request) async {
                  final pathSegments = request.url.pathSegments;
                  if (pathSegments.length == 2 &&
                      pathSegments[0] == '.well-known' &&
                      pathSegments[1] == 'openid-configuration') {
                    return Response(jsonEncode(mockProviderMetadata), 200);
                  }
                  if (pathSegments.isNotEmpty &&
                      pathSegments.first == 'token') {
                    final tokenResponse = createMockTokenResponse(
                      claimsJson: defaultIdTokenClaimsJson(),
                    )..remove('id_token');
                    return Response(jsonEncode(tokenResponse), 200);
                  }
                  throw UnimplementedError(
                    "Don't know how to handle the request ${request.url}",
                  );
                },
              );
              manager = OidcUserManager(
                id: managerId,
                discoveryDocument: doc,
                clientCredentials: clientCredentials,
                store: store,
                settings: settings,
                httpClient: client,
                keyStore: managerKeyStore,
              );

              final nowMock = tokenCreatedAt.add(const Duration(hours: 2));
              nowClock = Clock.fixed(nowMock);

              await withClock(nowClock, () async {
                await manager.init();
              });

              expect(manager.didInit, isTrue);
              expect(manager.currentUser, isNotNull);

              final newToken = manager.currentUser!.token;
              expect(newToken.creationTime, nowMock);
              expect(newToken.idToken, cachedTokenJson['id_token']);
              expect(newToken.allowExpiredIdToken, isTrue);
              expect(newToken.accessToken, isNot(equals('SlAV32hkKG')));

              final storedToken = await store.get(
                OidcStoreNamespace.secureTokens,
                key: OidcConstants_Store.currentToken,
                managerId: managerId,
              );
              expect(storedToken, isNotNull);

              final decodedStoredToken =
                  jsonDecode(storedToken!) as Map<String, dynamic>;
              expect(
                decodedStoredToken[OidcConstants_AuthParameters.idToken],
                cachedTokenJson['id_token'],
              );
              expect(
                decodedStoredToken[OidcConstants_Store.allowExpiredIdToken],
                isTrue,
              );
            },
          );
          test(
            'Should reload a refreshed token without re-rejecting the reused expired id_token',
            () async {
              client = createMockOidcClient(
                beforeDefault: (request) async {
                  final pathSegments = request.url.pathSegments;
                  if (pathSegments.length == 2 &&
                      pathSegments[0] == '.well-known' &&
                      pathSegments[1] == 'openid-configuration') {
                    return Response(jsonEncode(mockProviderMetadata), 200);
                  }
                  if (pathSegments.isNotEmpty &&
                      pathSegments.first == 'token') {
                    final tokenResponse = createMockTokenResponse(
                      claimsJson: defaultIdTokenClaimsJson(),
                    )..remove('id_token');
                    return Response(jsonEncode(tokenResponse), 200);
                  }
                  throw UnimplementedError(
                    "Don't know how to handle the request ${request.url}",
                  );
                },
              );
              manager = OidcUserManager(
                id: managerId,
                discoveryDocument: doc,
                clientCredentials: clientCredentials,
                store: store,
                settings: settings,
                httpClient: client,
                keyStore: managerKeyStore,
              );

              final refreshedAt = tokenCreatedAt.add(const Duration(hours: 2));
              await withClock(Clock.fixed(refreshedAt), () async {
                await manager.init();
              });
              expect(manager.currentUser, isNotNull);

              client = createMockOidcClient(
                beforeDefault: (request) async {
                  throw StateError(
                    'Unexpected network request: ${request.url}',
                  );
                },
              );
              manager = OidcUserManager(
                id: managerId,
                discoveryDocument: doc,
                clientCredentials: clientCredentials,
                store: store,
                settings: settings,
                httpClient: client,
                keyStore: managerKeyStore,
              );

              final reloadAt = refreshedAt.add(const Duration(minutes: 30));
              await withClock(Clock.fixed(reloadAt), () async {
                await manager.init();
              });

              final reloadedToken = manager.currentUser?.token;
              expect(reloadedToken, isNotNull);
              expect(reloadedToken!.allowExpiredIdToken, isTrue);
              expect(reloadedToken.idToken, cachedTokenJson['id_token']);
              expect(reloadedToken.creationTime, refreshedAt);
            },
          );
          test(
            'Should not emit token expired when refresh succeeds without id_token',
            () async {
              final createdAt = DateTime.now().toUtc();
              cachedTokenJson = {
                "scope": OidcInternalUtilities.joinSpaceDelimitedList([
                  OidcConstants_Scopes.openid,
                  OidcConstants_Scopes.profile,
                  OidcConstants_Scopes.email,
                  "offline_access",
                ]),
                "access_token": "short-lived-token",
                "token_type": "Bearer",
                "refresh_token": "8xLOxBtZp8",
                "expires_in": const Duration(seconds: 1).inSeconds,
                "id_token": createIdToken(
                  claimsJson: defaultIdTokenClaimsJson(
                    iat: createdAt,
                    exp: createdAt.add(const Duration(hours: 1)),
                  ),
                ),
                "expiresInReferenceDate": createdAt.toIso8601String(),
                "session_state":
                    "YaSjXERcv7iG5F9euVQ_F4smjyt0jD3sYxARlJdBMVE.9A5536CDE44A8BE6D4F2A9E2ABD73ECF",
              };
              await store.set(
                OidcStoreNamespace.secureTokens,
                key: OidcConstants_Store.currentToken,
                value: jsonEncode(cachedTokenJson),
                managerId: managerId,
              );

              var refreshRequestCount = 0;
              client = createMockOidcClient(
                beforeDefault: (request) async {
                  final pathSegments = request.url.pathSegments;
                  if (pathSegments.length == 2 &&
                      pathSegments[0] == '.well-known' &&
                      pathSegments[1] == 'openid-configuration') {
                    return Response(jsonEncode(mockProviderMetadata), 200);
                  }
                  if (pathSegments.isNotEmpty &&
                      pathSegments.first == 'token') {
                    refreshRequestCount++;
                    final tokenResponse = createMockTokenResponse(
                      claimsJson: defaultIdTokenClaimsJson(),
                    )..remove('id_token');
                    return Response(jsonEncode(tokenResponse), 200);
                  }
                  throw UnimplementedError(
                    "Don't know how to handle the request ${request.url}",
                  );
                },
              );

              final eventSettings = OidcUserManagerSettings(
                redirectUri: settings.redirectUri,
                refreshBefore: (_) => const Duration(milliseconds: 700),
              );
              manager = OidcUserManager(
                id: managerId,
                discoveryDocument: doc,
                clientCredentials: clientCredentials,
                store: store,
                settings: eventSettings,
                httpClient: client,
                keyStore: managerKeyStore,
              );

              await manager.init();
              expect(manager.currentUser, isNotNull);

              final events = <OidcEvent>[];
              final sub = manager.events().listen(events.add);

              await Future<void>.delayed(const Duration(milliseconds: 450));

              expect(refreshRequestCount, equals(1));
              expect(events.whereType<OidcTokenExpiringEvent>(), hasLength(1));
              expect(events.whereType<OidcTokenExpiredEvent>(), isEmpty);
              expect(manager.currentUser, isNotNull);
              expect(manager.currentUser!.token.allowExpiredIdToken, isTrue);

              await Future<void>.delayed(const Duration(milliseconds: 750));

              expect(events.whereType<OidcTokenExpiredEvent>(), isEmpty);

              await sub.cancel();
              await manager.dispose();
            },
          );
          test(
            'With expired token and no refresh token available, should remove the token',
            () async {
              cachedTokenJson.remove('refresh_token');
              await store.set(
                OidcStoreNamespace.secureTokens,
                key: OidcConstants_Store.currentToken,
                value: jsonEncode(cachedTokenJson),
                managerId: managerId,
              );
              //
              final nowMock = tokenCreatedAt.add(const Duration(hours: 2));
              nowClock = Clock.fixed(nowMock);

              await withClock(nowClock, () async {
                await manager.init();
              });
              expect(manager.didInit, isTrue);
              expect(manager.currentUser, isNull);

              final storedToken = await store.get(
                OidcStoreNamespace.secureTokens,
                key: OidcConstants_Store.currentToken,
                managerId: managerId,
              );
              expect(storedToken, isNull);
            },
          );
        });
      }
    });
  });
}
