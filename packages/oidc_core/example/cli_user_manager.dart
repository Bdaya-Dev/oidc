// ignore_for_file: avoid_print, omit_local_variable_types

import 'dart:async';
import 'dart:io';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';

/// An example user manager that can be used in a Cli environment, and is based on package:oidc_loopback_listener.
/// The code here uses the same logic as in package:oidc_desktop, but modified to not depend on flutter.
class CliUserManager extends OidcUserManagerBase {
  CliUserManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.settings,
    required super.store,
    super.httpClient,
    super.keyStore,
  }) : super();

  CliUserManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  /// starts a listener and gets a response Uri.
  /// The user needs to click on the printed link to complete the login.
  Future<Uri?> startListenerAndGetUri({
    required Uri originalRedirectUri,
    required String redirectUriKey,
    required Uri endpoint,
    required Map<String, dynamic> requestParameters,
    required String logRequestDesc,
    required Completer<Uri> actualRedirectUriCompleter,
    required Future<void> Function(Uri) printFunction,
  }) async {
    final listener = OidcLoopbackListener(
      path: originalRedirectUri.path,
      port: originalRedirectUri.port,
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

    await printFunction(uri);

    // wait for a response from the server listener.
    final responseUri = await responseUriFuture;
    if (responseUri == null) {
      return null;
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
        "The OpenId Provider doesn't provide the authorizationEndpoint",
      );
    }
    final redirectUriCompleter = Completer<Uri>();
    final responseUri = await startListenerAndGetUri(
      originalRedirectUri: request.redirectUri,
      redirectUriKey: OidcConstants_AuthParameters.redirectUri,
      endpoint: authEndpoint,
      logRequestDesc: 'authorization',
      requestParameters: request.toMap(),
      actualRedirectUriCompleter: redirectUriCompleter,
      printFunction: (uri) async =>
          print('please open the following link: $uri'),
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
        "The OpenId Provider doesn't provide the endSessionEndpoint",
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
      requestParameters: request.toMap(),
      actualRedirectUriCompleter: redirectUriCompleter,
      printFunction: (uri) async =>
          print('please open the following link: $uri'),
    );

    if (responseUri == null) {
      return null;
    }

    // wait for a response from the server listener.
    return OidcEndSessionResponse.fromJson(responseUri.queryParameters);
  }

  @override
  bool get isWeb => false;

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    return const Stream.empty();
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return const Stream.empty();
  }

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) {
    return {};
  }
}
