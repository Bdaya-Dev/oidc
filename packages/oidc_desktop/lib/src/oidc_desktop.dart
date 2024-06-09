import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';

/// {@template oidc_desktop}
/// Base Implementation for oidc_* desktop plugins (mainly windows/linux)
/// {@endtemplate}
mixin OidcDesktop on OidcPlatform {
  /// the logger.
  @protected
  Logger get logger;

  /// gets the platform options from the options object.
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  );

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) =>
      {};

  /// starts a listener and gets a response Uri.
  ///
  /// override this in mock implementations.
  @protected
  Future<Uri?> startListenerAndGetUri({
    required Uri originalRedirectUri,
    required String redirectUriKey,
    required OidcPlatformSpecificOptions options,
    required Uri endpoint,
    required Map<String, dynamic> requestParameters,
    required String logRequestDesc,
    required Completer<Uri> actualRedirectUriCompleter,
  }) async {
    final platformOpts = getNativeOptions(options);
    final listener = OidcLoopbackListener(
      path: originalRedirectUri.path,
      port: originalRedirectUri.port,
      successfulPageResponse: platformOpts.successfulPageResponse,
      methodMismatchResponse: platformOpts.methodMismatchResponse,
      notFoundResponse: platformOpts.notFoundResponse,
    );
    final serverCompleter = Completer<HttpServer>();
    //don't await the responseUriFuture until we launch the url.
    final responseUriFuture = listener.listenForSingleResponse(
      serverCompleter: serverCompleter,
    );
    // wait until the server starts listening and we get a port.
    final server = await serverCompleter.future;
    if (server.port != originalRedirectUri.port) {
      //replace the port in the redirectUri with the actual port.
      originalRedirectUri = originalRedirectUri.replace(port: server.port);
    }
    actualRedirectUriCompleter.complete(originalRedirectUri);
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        // ignore: invalid_use_of_internal_member
        ...OidcInternalUtilities.serializeQueryParameters(requestParameters),
        // override the redirect uri.
        redirectUriKey: originalRedirectUri.toString(),
      },
    );

    if (!await canLaunchUrl(uri)) {
      logger.warning(
        'Might not be able to launch the $logRequestDesc request url: $uri',
      );
    }

    // launch the uri
    await launchUrl(uri);

    // wait for a response from the server listener.
    final responseUri = await responseUriFuture;
    if (responseUri == null) {
      return null;
    }
    try {
      await WindowToFront.activate();
    } catch (e) {
      //try bringing the window to front, swallow errors if it fails.
    }
    return responseUri;
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    final authEndpoint = metadata.authorizationEndpoint;
    if (authEndpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.authorizationEndpoint}'",
      );
    }
    final redirectUriCompleter = Completer<Uri>();
    final responseUri = await startListenerAndGetUri(
      originalRedirectUri: request.redirectUri,
      redirectUriKey: OidcConstants_AuthParameters.redirectUri,
      endpoint: authEndpoint,
      logRequestDesc: 'authorization',
      options: options,
      requestParameters: request.toMap(),
      actualRedirectUriCompleter: redirectUriCompleter,
    );

    if (responseUri == null) {
      return null;
    }
    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: responseUri,
      overrides: {
        OidcConstants_AuthParameters.redirectUri:
            (await redirectUriCompleter.future).toString(),
      },
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    final endSessionEndpoint = metadata.endSessionEndpoint;
    if (endSessionEndpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.endSessionEndpoint}'",
      );
    }

    final postLogoutRedirectUri = request.postLogoutRedirectUri;
    if (postLogoutRedirectUri == null) {
      return null;
    }

    final redirectUriCompleter = Completer<Uri>();
    final responseUri = await startListenerAndGetUri(
      originalRedirectUri: postLogoutRedirectUri,
      redirectUriKey: OidcConstants_AuthParameters.postLogoutRedirectUri,
      endpoint: endSessionEndpoint,
      logRequestDesc: 'end session',
      options: options,
      requestParameters: request.toMap(),
      actualRedirectUriCompleter: redirectUriCompleter,
    );

    if (responseUri == null) {
      return null;
    }

    // wait for a response from the server listener.
    return OidcEndSessionResponse.fromJson(responseUri.queryParameters);
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    // TODO(ahmednfwela): listen to loopback
    return const Stream.empty();
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return const Stream.empty();
  }
}
