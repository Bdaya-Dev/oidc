import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The macOS implementation of [OidcPlatform].
///
/// Performs the authorization / end-session browser flow using the system
/// `ASWebAuthenticationSession` through a platform [MethodChannel]. All OIDC
/// logic (URL building, PKCE, `state`, `nonce`, and response parsing) stays in
/// pure-Dart `oidc_core`; the native side only opens a URL and returns the
/// redirect URI. This replaces the previous `flutter_appauth`-based path.
class OidcMacOS extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform].
  static void registerWith() {
    OidcPlatform.instance = OidcMacOS();
  }

  /// The platform channel that talks to the native macOS plugin.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(OidcNativeChannels.macos);

  /// Whether to use an ephemeral `ASWebAuthenticationSession` (no shared
  /// cookies/cache), derived from the macOS external-user-agent option.
  @visibleForTesting
  bool preferEphemeral(OidcPlatformSpecificOptions options) =>
      options.macos.externalUserAgent ==
      OidcAppAuthExternalUserAgent.ephemeralAsWebAuthenticationSession;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) => const {};

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
      method: OidcNativeMethods.authorize,
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
        OidcConstants_AuthParameters.redirectUri: request.redirectUri
            .toString(),
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
      method: OidcNativeMethods.endSession,
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
    } on MissingPluginException catch (e, st) {
      // The native macOS plugin isn't registered. Surface a clear, actionable
      // error instead of leaking the raw exception.
      throw OidcException(
        'The native oidc_macos plugin is not available on this platform. '
        'Ensure the app runs on macOS 10.15+ with the plugin registered.',
        internalException: e,
        internalStackTrace: st,
      );
    } on PlatformException catch (e, st) {
      // A cancelled flow is benign and maps to `null`.
      if (e.code == OidcNativeErrorCodes.userCancelled) {
        return null;
      }
      // On end-session, a closed presentation context simply means the session
      // ended; treat it as a successful logout with no response payload.
      if (method == OidcNativeMethods.endSession &&
          e.code == OidcNativeErrorCodes.presentationContextInvalid) {
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
  ) => const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) => const Stream.empty();
}
