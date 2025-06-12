import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

final _logger = Logger('Oidc.Linux');

/// The Linux implementation of [OidcPlatform].
class OidcLinux extends OidcPlatform with OidcDesktop {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcLinux();
  }

  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) =>
      options.linux;

  @override
  Logger get logger => _logger;
}
