import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc/oidc.dart';
// import 'package:oidc/oidc.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOidcPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements OidcPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Oidc', () {
    late OidcPlatform oidcPlatform;

    setUp(() {
      oidcPlatform = MockOidcPlatform();
      OidcPlatform.instance = oidcPlatform;
    });

    group('OidcUserManager', () {
      test('with document', () {
        final manager = OidcUserManager(
          discoveryDocument: OidcProviderMetadata.fromJson({
            'issuer': 'https://server.example.com',
            'authorization_endpoint':
                'https://server.example.com/connect/authorize',
            'token_endpoint': 'https://server.example.com/connect/token',
            //...other metadata
          }),
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'my_client_id',
          ),
          store: OidcMemoryStore() /* or OidcDefaultStore() */,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('http://example.com/redirect.html'),
          ),
          //other optional parameters.
        );
      });
      test('lazy', () {
        final manager = OidcUserManager.lazy(
          // discoveryDocumentUri:
          //     Uri.parse('https://example.com/.well-known/openid-configuration'),
          //or
          discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://example.com'),
          ),
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'my_client_id',
          ),
          store: OidcMemoryStore() /* or OidcDefaultStore() */,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('http://example.com/redirect.html'),
          ),
          //other optional parameters.
        );
      });
    });
    // group('getPlatformName', () {
    //   test('returns correct name when platform implementation exists',
    //       () async {
    //     const platformName = '__test_platform__';
    //     when(
    //       () => oidcPlatform.getPlatformName(),
    //     ).thenAnswer((_) async => platformName);

    //     final actualPlatformName = await getPlatformName();
    //     expect(actualPlatformName, equals(platformName));
    //   });

    //   test('throws exception when platform implementation is missing',
    //       () async {
    //     when(
    //       () => oidcPlatform.getPlatformName(),
    //     ).thenAnswer((_) async => null);

    //     expect(getPlatformName, throwsException);
    //   });
    // });
  });
}
