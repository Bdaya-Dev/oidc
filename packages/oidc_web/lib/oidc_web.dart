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
    OidcAuthorizePlatformSpecificOptions options,
  ) async {
    final authEndpoint = metadata.authorizationEndpoint;
    if (authEndpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide the authorizationEndpoint",
      );
    }
    final channel = BroadcastChannel('oidc_flutter_web/redirect');
    final c = Completer<Uri>();
    final sub = channel.onMessage.listen((event) {
      final data = event.data;
      if (data is! String) {
        return;
      }
      final parsed = Uri.tryParse(data);
      if (parsed == null) {
        return;
      }
      c.complete(parsed);
    });

    try {
      final uri = request.generateUri(authEndpoint);
      if (!await canLaunchUrl(uri)) {
        _logger.warning(
          "Couldn't launch the authorization request url: $uri, this might be a false positive.",
        );
      }

      //first prepare
      switch (options.web.navigationMode) {
        case OidcAuthorizePlatformOptions_Web_NavigationMode.samePage:
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
          if (!await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
          )) {
            _logger
                .severe("Couldn't launch the authorization request url: $uri");
            return null;
          }
          //listen to response uri.
          return await OidcEndpoints.parseAuthorizeResponse(
            responseUri: await c.future,
          );
        case OidcAuthorizePlatformOptions_Web_NavigationMode.popup:
          final h = options.web.popupHeight;
          final w = options.web.popupWidth;
          final top = (window.outerHeight - h) / 2 +
              (window.screen?.available.top ?? 0);
          final left = (window.outerWidth - w) / 2 +
              (window.screen?.available.left ?? 0);

          final windowOpts =
              'width=$w,height=$h,toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';

          window.open(
            uri.toString(),
            'oidc_auth_popup',
            windowOpts,
          );
          return await OidcEndpoints.parseAuthorizeResponse(
            responseUri: await c.future,
          );
      }
    } finally {
      await sub.cancel();
    }
  }
}
