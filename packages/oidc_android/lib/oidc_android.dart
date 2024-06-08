import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_flutter_appauth/oidc_flutter_appauth.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Android implementation of [OidcPlatform].
class OidcAndroid extends OidcPlatform with OidcFlutterAppauth {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcAndroid();
  }

  @override
  bool getAllowInsecureConnections(
    OidcPlatformSpecificOptions options,
  ) {
    return options.android.allowInsecureConnections;
  }
}
