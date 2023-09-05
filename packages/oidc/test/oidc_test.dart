import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// import 'package:oidc/oidc.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
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
