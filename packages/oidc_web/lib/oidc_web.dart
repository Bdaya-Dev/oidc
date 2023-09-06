import 'dart:async';
import 'dart:html';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('Oidc.OidcWeb');

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
    OidcAuthorizePlatformSpecificOptions options,
  ) async {
    final authEndpoint = metadata.authorizationEndpoint;
    if (authEndpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide the authorizationEndpoint",
      );
    }
    final channel = BroadcastChannel('oidc_flutter_web/redirect');
    final sub = channel.onMessage.listen((event) {});
    try {
      final uri = request.generateUri(authEndpoint);
      if (!await canLaunchUrl(uri)) {
        _logger.warning(
          "Couldn't launch the authorization request url: $uri, this might be a false positive.",
        );
      }
      /*
    samePage:
    1. return null
    2. 
    ===========
    newPage
    popup
    iframe
    */

      //first prepare
      switch (options.web.navigationMode) {
        // case OidcAuthorizePlatformOptions_Web_NavigationMode.popup:
        //   //TODO(ahmednfwela): launch a popup, and get a window handle.
        //   break;
        case OidcAuthorizePlatformOptions_Web_NavigationMode.samePage:
          final state = OidcAuthorizeState.fromRequest(
            authority: authority,
            clientId: clientId,
            redirectUri: redirectUri,
            scope: scope,
          );
          await store.set(
            OidcStoreNamespace.state,
            key: /* get a state Id */ key,
            value: value,
          );
          if (!await launchUrl(
            uri,
            webOnlyWindowName: '_self',
          )) {
            _logger
                .severe("Couldn't launch the authorization request url: $uri");
          }
          // return null, since this mode can't be awaited.
          return null;
        case OidcAuthorizePlatformOptions_Web_NavigationMode.newPage:
          final c = Completer<Uri>();
          if (!await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
          )) {
            _logger
                .severe("Couldn't launch the authorization request url: $uri");
            return null;
          }
          //listen to
          // window.sessionStorage.;
          break;
        // case OidcAuthorizePlatformOptions_Web_NavigationMode.iframe:
        //   //TODO: redirect to the new page in a new tab
        //   break;
        case OidcAuthorizePlatformOptions_Web_NavigationMode.popup:
          // TODO: Handle this case.
          break;
        case OidcAuthorizePlatformOptions_Web_NavigationMode.iframe:
          // TODO: Handle this case.
          break;
      }
    } finally {
      await sub.cancel();
    }
  }

  // @override
  // Future<String?> getPlatformName() async => 'Web';
}
