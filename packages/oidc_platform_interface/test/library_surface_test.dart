import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

// `native_channel_constants.dart` is exported by the public barrel, but no
// other test in this package ever references `OidcNativeMethods` /
// `OidcNativeErrorCodes` directly, so its documented values are never
// asserted against. These constants must stay byte-for-byte in sync with the
// native Kotlin/Swift plugins (see the file's own doc comment), so a drift
// here is a real cross-platform break.
void main() {
  group('oidc_platform_interface library surface', () {
    test(
      'OidcNativeMethods match the Pigeon OidcAndroidHostApi method names',
      () {
        expect(OidcNativeMethods.authorize, 'authorize');
        expect(OidcNativeMethods.endSession, 'endSession');
        expect(OidcNativeMethods.cancel, 'cancel');
      },
    );

    test(
      "OidcNativeErrorCodes match the native plugins' PlatformException "
      'codes',
      () {
        expect(OidcNativeErrorCodes.userCancelled, 'USER_CANCELLED');
        expect(
          OidcNativeErrorCodes.presentationContextInvalid,
          'PRESENTATION_CONTEXT_INVALID',
        );
      },
    );
  });
}
