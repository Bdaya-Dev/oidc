// ignore_for_file: camel_case_extensions

import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_web_core/oidc_web_core.dart';

///
extension OidcPlatformSpecificOptions_WebCore_Mapper
    on OidcPlatformSpecificOptions_Web {
  /// maps to oidc_web_core models
  OidcPlatformSpecificOptions_WebCore mapToWebCore() {
    return OidcPlatformSpecificOptions_WebCore(
      broadcastChannel: broadcastChannel,
      hiddenIframeTimeout: hiddenIframeTimeout,
      navigationMode: navigationMode.mapToWebCore(),
      popupHeight: popupHeight,
      popupWidth: popupWidth,
    );
  }
}

///
extension OidcPlatformSpecificOptions_WebCore_NavigationMode_Mapper
    on OidcPlatformSpecificOptions_Web_NavigationMode {
  /// maps to oidc_web_core models
  OidcPlatformSpecificOptions_WebCore_NavigationMode mapToWebCore() {
    return OidcPlatformSpecificOptions_WebCore_NavigationMode.values[index];
  }
}

///
extension OidcFrontChannelRequestListeningOptions_WebCore_Mapper
    on OidcFrontChannelRequestListeningOptions_Web {
  /// maps to oidc_web_core models
  OidcFrontChannelRequestListeningOptions_WebCore mapToWebCore() {
    return OidcFrontChannelRequestListeningOptions_WebCore(
      broadcastChannel: broadcastChannel,
    );
  }
}
