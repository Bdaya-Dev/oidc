import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// {@template oidc_flutter_appauth}
/// Base Implementation connecting oidc_* packages with flutter_appauth
/// {@endtemplate}
mixin OidcFlutterAppauth on OidcPlatform {
  /// the FlutterAppAuth instance.
  @protected
  final appAuth = const FlutterAppAuth();

  /// gets the `preferEphemeralSession` parameter from options.
  bool getPreferEphemeralSession(
    OidcPlatformSpecificOptions options,
  ) =>
      false;

  /// gets the allowInsecureConnections
  bool getAllowInsecureConnections(
    OidcPlatformSpecificOptions options,
  ) =>
      false;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) =>
      {};

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    final authorizationEndpoint = metadata.authorizationEndpoint;
    if (authorizationEndpoint == null) {
      throw const OidcException(
        'OIDC provider MUST declare an '
        'authorization endpoint and a token endpoint',
      );
    }
    final resp = await appAuth.authorize(
      AuthorizationRequest(
        request.clientId,
        request.redirectUri.toString(),
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: authorizationEndpoint.toString(),
          tokenEndpoint: metadata.tokenEndpoint.toString(),
          endSessionEndpoint: metadata.endSessionEndpoint?.toString(),
        ),
        additionalParameters:
            request.extra.map((key, value) => MapEntry(key, value.toString())),
        issuer: metadata.issuer?.toString(),
        loginHint: request.loginHint,
        nonce: request.nonce,
        promptValues: request.prompt,
        scopes: request.scope,
        responseMode: request.responseMode,
        preferEphemeralSession: getPreferEphemeralSession(options),
        allowInsecureConnections: getAllowInsecureConnections(options),
      ),
    );
    if (resp == null) {
      return null;
    }
    return OidcAuthorizeResponse.fromJson({
      OidcConstants_AuthParameters.code: resp.authorizationCode,
      OidcConstants_AuthParameters.codeVerifier: resp.codeVerifier,
      OidcConstants_AuthParameters.nonce: resp.nonce,
      OidcConstants_AuthParameters.redirectUri: request.redirectUri.toString(),
      // add state here since appauth handles state itself
      OidcConstants_AuthParameters.state: request.state,
      ...?resp.authorizationAdditionalParameters,
    });
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
        'OIDC provider MUST declare an '
        'authorization endpoint, a token endpoint and an endSessionEndpoint',
      );
    }

    final resp = await appAuth.endSession(
      EndSessionRequest(
        additionalParameters:
            request.extra.map((key, value) => MapEntry(key, value.toString())),
        serviceConfiguration: AuthorizationServiceConfiguration(
          endSessionEndpoint: metadata.endSessionEndpoint?.toString(),
          authorizationEndpoint: metadata.authorizationEndpoint.toString(),
          tokenEndpoint: metadata.tokenEndpoint.toString(),
        ),
        idTokenHint: request.idTokenHint,
        allowInsecureConnections: getAllowInsecureConnections(options),
        preferEphemeralSession: getPreferEphemeralSession(options),
        state: request.state,
        issuer: metadata.issuer?.toString(),
        postLogoutRedirectUrl: request.postLogoutRedirectUri?.toString(),
      ),
    );
    if (resp == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson({
      if (resp.state != null) OidcConstants_AuthParameters.state: resp.state,
    });
  }

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
}
