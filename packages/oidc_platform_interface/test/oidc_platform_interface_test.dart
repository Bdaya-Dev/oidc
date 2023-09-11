import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:oidc_platform_interface/oidc_platform_interface.dart';

class OidcMock extends OidcPlatform {
  static const mockPlatformName = 'Mock';

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcAuthorizePlatformSpecificOptions options,
  ) {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OidcPlatformInterface', () {
    late OidcPlatform oidcPlatform;

    setUp(() {
      oidcPlatform = OidcMock();
      OidcPlatform.instance = oidcPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        // expect(
        //   await OidcPlatform.instance.getPlatformName(),
        //   equals(OidcMock.mockPlatformName),
        // );
      });
    });
  });
}
