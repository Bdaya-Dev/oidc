import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_web/oidc_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcWeb', () {
    // const kPlatformName = 'Web';
    late OidcWeb oidc;

    setUp(() async {
      oidc = OidcWeb();
    });

    test('can be registered', () {
      OidcWeb.registerWith();
      expect(OidcPlatform.instance, isA<OidcWeb>());
      expect(OidcPlatform.instance, oidc);
    });
  });
}
