import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc/oidc.dart';
// import 'package:oidc/oidc.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mock_client.dart';

class MockOidcPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements OidcPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Oidc', () {
    late OidcPlatform oidcPlatform;
    final client = createMockOidcClient();
    final store = OidcMemoryStore();
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
      test('with document', () async {
        final doc = OidcProviderMetadata.fromJson({
          'issuer': 'https://server.example.com',
          'authorization_endpoint':
              'https://server.example.com/connect/authorize',
          'token_endpoint': 'https://server.example.com/connect/token',
        });
        final manager = OidcUserManager(
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
        final manager = OidcUserManager.lazy(
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
        expect(manager.discoveryDocument, isNotNull);
        expect(manager.discoveryDocumentUri, isNotNull);
      });
    });
  });
}
