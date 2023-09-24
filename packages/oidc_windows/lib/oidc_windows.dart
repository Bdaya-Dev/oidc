import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

final _logger = Logger('Oidc.Windows');

/// The Windows implementation of [OidcPlatform].
class OidcWindows extends OidcPlatform with OidcDesktop {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcWindows();
  }

  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) {
    return options.windows;
  }

  @override
  Logger get logger => _logger;

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return const Stream.empty();
  }
}
