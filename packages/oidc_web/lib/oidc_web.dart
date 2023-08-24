import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Web implementation of [OidcPlatform].
class OidcWeb extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith([Object? registrar]) {
    OidcPlatform.instance = OidcWeb();
  }

  @override
  Future<String?> getPlatformName() async => 'Web';
}
