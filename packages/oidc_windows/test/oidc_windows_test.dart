import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_windows/oidc_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcWindows', () {
    test('can be registered', () {
      const fakeOptions = OidcPlatformSpecificOptions(
        windows: OidcPlatformSpecificOptions_Native(
          successfulPageResponse: 'hello windows',
        ),
      );

      OidcWindows.registerWith();

      expect(
        OidcPlatform.instance,
        isA<OidcWindows>()
            .having(
              (p0) => p0.getNativeOptions(fakeOptions).successfulPageResponse,
              'getNativeOptions',
              equals(fakeOptions.windows.successfulPageResponse),
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
