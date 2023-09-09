import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('Oidc.Linux');

/// The Linux implementation of [OidcPlatform].
class OidcLinux extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_linux');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcLinux();
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcStore store,
    OidcAuthorizeState? stateData,
    OidcAuthorizePlatformSpecificOptions options,
  ) async {
    final authEndpoint = metadata.authorizationEndpoint;
    if (authEndpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide the authorizationEndpoint",
      );
    }

    var redirectUri = request.redirectUri;
    final listener = OidcLoopbackListener(
      path: redirectUri.path,
      port: redirectUri.port,
      successfulPageResponse: options.linux.successfulPageResponse,
      methodMismatchResponse: options.linux.methodMismatchResponse,
      notFoundResponse: options.linux.notFoundResponse,
    );
    final serverCompleter = Completer<HttpServer>();
    //don't await the responseUriFuture until we launch the url.
    final responseUriFuture = listener.listenForSingleResponse(
      serverCompleter: serverCompleter,
    );
    // wait until the server starts listening and we get a port.
    final server = await serverCompleter.future;
    if (server.port != request.redirectUri.port) {
      //replace the port in the redirectUri with the actual port.
      redirectUri = redirectUri.replace(port: server.port);
    }
    final uri = authEndpoint.replace(
      queryParameters: {
        ...authEndpoint.queryParameters,
        ...request.toMap(),
        // override the redirect uri.
        OidcConstants_AuthParameters.redirectUri: redirectUri.toString(),
      },
    );

    if (!await canLaunchUrl(uri)) {
      _logger.warning(
        "Couldn't launch the authorization request url: $uri, this might be a "
        'false positive.',
      );
    }

    // launch the uri
    if (!await launchUrl(uri)) {
      return null;
    }

    // wait for a response from the server listener.
    final responseUri = await responseUriFuture;
    if (responseUri == null) {
      return null;
    }

    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: responseUri,
      store: store,
      overrides: {
        OidcConstants_AuthParameters.redirectUri: redirectUri.toString(),
      },
    );
  }
}
