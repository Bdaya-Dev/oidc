import 'dart:async';
import 'dart:html';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('Oidc.OidcWeb');

/// The Web implementation of [OidcPlatform].
class OidcWeb extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith([Object? registrar]) {
    OidcPlatform.instance = OidcWeb();
  }

  String _calculatePopupOptions(OidcPlatformSpecificOptions_Web web) {
    final h = web.popupHeight;
    final w = web.popupWidth;
    final top =
        (window.outerHeight - h) / 2 + (window.screen?.available.top ?? 0);
    final left =
        (window.outerWidth - w) / 2 + (window.screen?.available.left ?? 0);

    final windowOpts =
        'width=$w,height=$h,toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';
    return windowOpts;
  }

  Future<Uri?> _getResponseUri({
    required OidcPlatformSpecificOptions_Web options,
    required Uri uri,
  }) async {
    final channel = BroadcastChannel(options.broadcastChannel);
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
      //
      if (!await canLaunchUrl(uri)) {
        _logger.warning(
          "Couldn't launch the request url: $uri, this might be a false positive.",
        );
      }

      //first prepare
      switch (options.navigationMode) {
        case OidcPlatformSpecificOptions_Web_NavigationMode.samePage:
          if (!await launchUrl(
            uri,
            webOnlyWindowName: '_self',
          )) {
            _logger.severe("Couldn't launch the request url: $uri");
          }
          // return null, since this mode can't be awaited.
          return null;
        case OidcPlatformSpecificOptions_Web_NavigationMode.newPage:
          if (!await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
          )) {
            _logger.severe("Couldn't launch the request url: $uri");
            return null;
          }
          //listen to response uri.
          return await c.future;
        case OidcPlatformSpecificOptions_Web_NavigationMode.popup:
          final windowOpts = _calculatePopupOptions(options);
          window.open(
            uri.toString(),
            'oidc_auth_popup',
            windowOpts,
          );
          return await c.future;
      }
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
  ) async {
    final endpoint = metadata.authorizationEndpoint;
    if (endpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.authorizationEndpoint}'",
      );
    }
    final respUri = await _getResponseUri(
      options: options.web,
      uri: request.generateUri(endpoint),
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: respUri,
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
  ) async {
    final endpoint = metadata.endSessionEndpoint;
    if (endpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.endSessionEndpoint}'.",
      );
    }

    final respUri = await _getResponseUri(
      options: options.web,
      uri: request.generateUri(endpoint),
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(respUri.queryParameters);
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    final logger = Logger('Oidc.OidcWeb.listenToFrontChannelLogoutRequests');
    final channel = BroadcastChannel(options.web.broadcastChannel);
    return channel.onMessage
        .map<OidcFrontChannelLogoutIncomingRequest?>((event) {
          final data = event.data;
          if (data is! String) {
            logger.finer('Received data: $data');
            return null;
          }
          final uri = Uri.tryParse(data);
          if (uri == null) {
            logger.finer('Parsed Received data: $uri');
            return null;
          }
          //listening on empty path, will listen on all paths.
          if (listenOn.pathSegments.isNotEmpty) {
            logger.finer(
              'listenOn has a path segment (${listenOn.path}), checking if it matches the input data.',
            );
            if (!listEquals(uri.pathSegments, listenOn.pathSegments)) {
              logger.finer(
                'listenOn has a different path segment (${listenOn.path}), than data (${uri.path}), '
                'skipping the event.',
              );
              // the paths don't match
              return null;
            }
          }
          if (listenOn.hasQuery) {
            logger.finer(
              'listenOn has a query segment (${listenOn.query}), checking if it matches the input data.',
            );
            // check if every queryParameter in listenOn is the same in uri
            if (!listenOn.queryParameters.entries.every(
              (element) => uri.queryParameters[element.key] == element.value,
            )) {
              logger.finer(
                'listenOn has a different query segment (${listenOn.query}), than data (${uri.query}), '
                'skipping the event.',
              );
              return null;
            }
          } else {
            logger.finer(
              'listenOn has NO query segment, checking if data contains requestType=front-channel-logout by default.',
            );
            //by default, if no query parameter exists, check that
            // requestType=front-channel-logout
            if (uri.queryParameters[OidcConstants_Store.requestType] !=
                OidcConstants_Store.frontChannelLogout) {
              logger.finer(
                'data has no requestType=front-channel-logout in its query segment (${uri.query}), '
                'skipping the event.',
              );
              return null;
            }
          }
          logger.fine('successfully matched data ($uri)');
          return OidcFrontChannelLogoutIncomingRequest.fromJson(
            uri.queryParameters,
          );
        })
        .whereNotNull()
        //close the broadcast channel when the user cancels the stream.
        .doOnCancel(channel.close);
  }
}
