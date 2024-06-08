import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_linux/oidc_linux.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcLinux', () {
    test('can be registered', () {
      OidcLinux.registerWith();

      const fakeOptions = OidcPlatformSpecificOptions(
        linux: OidcPlatformSpecificOptions_Native(
          successfulPageResponse: 'hello linux',
        ),
      );

      expect(
        OidcPlatform.instance,
        isA<OidcLinux>()
            .having(
              (p0) => p0.getNativeOptions(fakeOptions).successfulPageResponse,
              'getNativeOptions',
              equals(fakeOptions.linux.successfulPageResponse),
            )
            .having(
              (p0) => p0.logger,
              'logger',
              isNotNull,
            ),
      );
    });
  });
}
