import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_linux/oidc_linux.dart';

// `oidc_linux_test.dart`'s only test overrides `options.linux` explicitly,
// so `getNativeOptions`' default-passthrough branch (the un-overridden
// `OidcPlatformSpecificOptions.linux` default) is never asserted, and
// `OidcLinux`'s `with OidcDesktop` mixin wiring is never asserted directly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('oidc_linux library surface', () {
    test(
        'OidcLinux mixes in OidcDesktop (shares the desktop redirect-flow '
        'implementation)', () {
      expect(OidcLinux(), isA<OidcDesktop>());
    });

    test(
      'getNativeOptions reads options.linux specifically, not '
      'options.windows/android (default, un-overridden options)',
      () {
        final result = OidcLinux().getNativeOptions(
          const OidcPlatformSpecificOptions(),
        );
        expect(result, const OidcPlatformSpecificOptions_Native());
      },
    );
  });
}
