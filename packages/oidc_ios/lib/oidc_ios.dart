import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The iOS implementation of [OidcPlatform].
///
/// Performs the authorization / end-session browser flow using
/// `ASWebAuthenticationSession` through a platform [MethodChannel]. All OIDC
/// logic (URL building, PKCE, `state`, `nonce`, and response parsing) stays in
/// pure-Dart `oidc_core`; the native side only opens a URL and returns the
/// redirect URI.
class OidcIOS extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform].
  static void registerWith() {
    OidcPlatform.instance = OidcIOS();
  }

  /// The platform channel that talks to the native iOS plugin.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('oidc_ios');

  /// Whether to use an ephemeral `ASWebAuthenticationSession` (no shared
  /// cookies/cache), derived from the iOS external-user-agent option.
  @visibleForTesting
  bool preferEphemeral(OidcPlatformSpecificOptions options) =>
      options.ios.externalUserAgent ==
      OidcAppAuthExternalUserAgent.ephemeralAsWebAuthenticationSession;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) =>
      const {};

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
        "The OpenId Provider doesn't provide an `authorization_endpoint`.",
      );
    }
    final url = request.generateUri(authorizationEndpoint);
    final responseUrl = await _authenticate(
      method: 'authorize',
      url: url,
      redirectUri: request.redirectUri,
      options: options,
    );
    if (responseUrl == null) {
      return null;
    }
    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: Uri.parse(responseUrl),
      overrides: {
        OidcConstants_AuthParameters.redirectUri:
            request.redirectUri.toString(),
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
        "The OpenId Provider doesn't provide an `end_session_endpoint`.",
      );
    }
    final url = request.generateUri(endSessionEndpoint);
    final responseUrl = await _authenticate(
      method: 'endSession',
      url: url,
      redirectUri: request.postLogoutRedirectUri,
      options: options,
    );
    if (responseUrl == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(
      Uri.parse(responseUrl).queryParameters,
    );
  }

  Future<String?> _authenticate({
    required String method,
    required Uri url,
    required Uri? redirectUri,
    required OidcPlatformSpecificOptions options,
  }) async {
    try {
      return await channel.invokeMethod<String>(method, <String, dynamic>{
        'url': url.toString(),
        'preferEphemeral': preferEphemeral(options),
        if (redirectUri != null) ...{
          'redirectUri': redirectUri.toString(),
          'callbackScheme': redirectUri.scheme,
        },
      });
    } on PlatformException catch (e, st) {
      // A cancelled flow is benign and maps to `null`.
      if (e.code == 'USER_CANCELLED') {
        return null;
      }
      // On end-session, a closed presentation context (the iOS+Azure "-3"
      // case) simply means the session ended; treat it as a successful logout
      // with no response payload.
      if (method == 'endSession' && e.code == 'PRESENTATION_CONTEXT_INVALID') {
        return null;
      }
      throw OidcException(
        'Native $method failed (${e.code}): ${e.message}',
        internalException: e,
        internalStackTrace: st,
      );
    }
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) =>
          const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) =>
      const Stream.empty();
}
