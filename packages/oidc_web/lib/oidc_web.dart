
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Web implementation of [OidcPlatform].
class OidcWeb extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith([Object? registrar]) {
    OidcPlatform.instance = OidcWeb();
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcStore store,
    OidcAuthorizePlatformOptions options,
  ) {
    final authEndpoint = metadata.authorizationEndpoint;
    if (authEndpoint == null) {
      throw const OidcException("The OpenId Provider doesn't provide the authorizationEndpoint");
    }
    final uri = request.generateUri(authEndpoint);
    switch (options.web.navigationMode) {
      case OidcAuthorizePlatformOptions_Web_NavigationMode.popup:
        //TODO: launch a popup, and get a window handle
        break;
      case OidcAuthorizePlatformOptions_Web_NavigationMode.samePage:

        //TODO: redirect to the new page in the same tab
        break;
      case OidcAuthorizePlatformOptions_Web_NavigationMode.newPage:
        //TODO: redirect to the new page in a new tab
        break;
      // case OidcAuthorizePlatformOptions_Web_NavigationMode.iframe:
      //   //TODO: redirect to the new page in a new tab
      //   break;
      default:
    }
  }

  // @override
  // Future<String?> getPlatformName() async => 'Web';
}
