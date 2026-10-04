import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_ios/oidc_ios.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

import 'duende_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcIOS', () {
    late OidcIOS oidc;
    late List<MethodCall> log;
    const methodChannel =
        MethodChannel('crossingthestreams.io/flutter_appauth');
    const mockAuthResponse = {
      'authorizationCode': '1234',
      'codeVerifier': '12344321',
      'nonce': 'abcd',
      'authorizationAdditionalParameters': {
        'hello': 'world',
      },
    };
    final metadata = OidcProviderMetadata.fromJson(testDiscoveryRaw);

    setUp(() async {
      oidc = OidcIOS();

      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'authorize':
            return mockAuthResponse;
          default:
            throw UnimplementedError();
        }
      });
    });
    tearDown(() => log.clear());

    test('can be registered', () {
      OidcIOS.registerWith();
      expect(OidcPlatform.instance, isA<OidcIOS>());
    });

    test('getAuthorizationResponse', () async {
      final response = await oidc.getAuthorizationResponse(
        metadata,
        OidcAuthorizeRequest(
          responseType: ['code'],
          clientId: 'someClientId',
          redirectUri: Uri.parse('hello:/world'),
          scope: ['openid'],
        ),
        const OidcPlatformSpecificOptions(),
        {},
      );
      expect(response, isNotNull);
      expect(response!.code, mockAuthResponse['authorizationCode']);
      expect(response.codeVerifier, mockAuthResponse['codeVerifier']);
      expect(response.nonce, mockAuthResponse['nonce']);
      expect(
        response.src['hello'],
        (mockAuthResponse['authorizationAdditionalParameters']
            as Map<String, dynamic>?)?['hello'],
      );
    });
  });
}
