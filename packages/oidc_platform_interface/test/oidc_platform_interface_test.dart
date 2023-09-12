import 'package:flutter_test/flutter_test.dart';

import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OidcPlatformInterface', () {
    late OidcPlatform oidcPlatform;

    setUp(() {
      oidcPlatform = NoOpOidcPlatform();
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
