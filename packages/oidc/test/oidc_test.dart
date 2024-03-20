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

  setUp(() {
    oidcPlatform = MockOidcPlatform();
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
        );
        expect(manager.didInit, isFalse);
        await manager.init();
        expect(manager.didInit, isTrue);
        expect(manager.discoveryDocument.src, mockProviderMetadata);
        expect(manager.discoveryDocumentUri, isNotNull);
      });
      group('loadCachedToken', () {
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
                "offline_access"
              ]),
              "access_token": "SlAV32hkKG",
              "token_type": "Bearer",
              "refresh_token": "8xLOxBtZp8",
              "expires_in": const Duration(hours: 1).inSeconds,
              "id_token": createIdToken(claimsJson: defaultIdTokenClaimsJson()),
              "expiresInReferenceDate": clock.now().toIso8601String(),
              "session_state":
                  "YaSjXERcv7iG5F9euVQ_F4smjyt0jD3sYxARlJdBMVE.9A5536CDE44A8BE6D4F2A9E2ABD73ECF"
            };
          });
          await store.set(
            OidcStoreNamespace.secureTokens,
            key: OidcConstants_Store.currentToken,
            value: jsonEncode(cachedTokenJson),
          );
          manager = OidcUserManager(
            discoveryDocument: doc,
            clientCredentials: clientCredentials,
            store: store,
            settings: settings,
            httpClient: client,
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
            'With expired token and no refresh token available, should remove the token',
            () async {
          cachedTokenJson.remove('refresh_token');
          await store.set(
            OidcStoreNamespace.secureTokens,
            key: OidcConstants_Store.currentToken,
            value: jsonEncode(cachedTokenJson),
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
          );
          expect(storedToken, isNull);
        });
      });
    });
  });
}
