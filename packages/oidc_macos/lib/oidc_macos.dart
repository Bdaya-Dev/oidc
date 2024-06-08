import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_flutter_appauth/oidc_flutter_appauth.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The MacOS implementation of [OidcPlatform].
class OidcMacOS extends OidcPlatform with OidcFlutterAppauth {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcMacOS();
  }

  @override
  bool getPreferEphemeralSession(OidcPlatformSpecificOptions options) {
    return options.macos.preferEphemeralSession;
  }
}
