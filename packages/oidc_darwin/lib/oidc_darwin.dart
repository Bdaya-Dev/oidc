import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The iOS + macOS ("darwin") implementation of [OidcPlatform].
///
/// Performs the authorization / end-session browser flow using the system
/// `ASWebAuthenticationSession` through the Pigeon-generated
/// [OidcAppleHostApi]. All OIDC logic (URL building, PKCE, `state`, `nonce`,
/// and response parsing) stays in pure-Dart `oidc_core`; the native side only
/// opens a URL and returns the redirect URI. This replaces the previous
/// `flutter_appauth`-based path and merges the former `oidc_ios` + `oidc_macos`
/// packages.
class OidcDarwin extends OidcPlatform {
  /// Creates the darwin platform implementation.
  ///
  /// [hostApi] is injectable for testing; production uses the default
  /// Pigeon-generated host API bound to the standard binary messenger.
  OidcDarwin({OidcAppleHostApi? hostApi})
    : _hostApi = hostApi ?? OidcAppleHostApi();

  /// Registers this class as the default instance of [OidcPlatform] on both
  /// iOS and macOS.
  static void registerWith() {
    OidcPlatform.instance = OidcDarwin();
  }

  /// The Pigeon host API that talks to the native iOS/macOS plugin.
  final OidcAppleHostApi _hostApi;

  /// Selects the Apple options for the platform the app is currently running
  /// on. The cross-platform options surface keeps `.ios` and `.macos` separate
  /// (they can differ legitimately), so each platform reads its own field.
  OidcNativeOptionsApple _appleOptions(OidcPlatformSpecificOptions options) =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? options.macos
      : options.ios;

  @override
  Stream<OidcNativeBrowserEvent> nativeBrowserEvents() => streamNativeEvents()
      .map(OidcNativeBrowserEvent.fromMap)
      .where((e) => e != null)
      .cast<OidcNativeBrowserEvent>();

  /// Whether to use an ephemeral `ASWebAuthenticationSession` (no shared
  /// cookies/cache), derived from the active platform's external-user-agent
  /// option.
  @visibleForTesting
  bool preferEphemeral(OidcPlatformSpecificOptions options) =>
      _appleOptions(options).prefersEphemeralWebBrowserSession;

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
    final responseUrl = await _guard(
      OidcNativeMethods.authorize,
      () => _hostApi.authorizeApple(
        url.toString(),
        request.redirectUri.toString(),
        request.redirectUri.scheme,
        preferEphemeral(options),
        // Serialized ASWebAuthenticationSession options
        // (additionalHeaderFields, callbackMode, rawSessionOptions); the native
        // side applies what it supports.
        _appleOptions(options).toJson(),
      ),
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
    final postLogout = request.postLogoutRedirectUri;
    final responseUrl = await _guard(
      OidcNativeMethods.endSession,
      () => _hostApi.endSessionApple(
        url.toString(),
        postLogout?.toString(),
        postLogout?.scheme,
        preferEphemeral(options),
        _appleOptions(options).toJson(),
      ),
    );
    if (responseUrl == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(
      Uri.parse(responseUrl).queryParameters,
    );
  }

  /// Invokes a native [OidcAppleHostApi] call and normalizes its failure modes:
  /// a `USER_CANCELLED` error becomes `null` (the shared null-means-cancelled
  /// contract); on end-session a `PRESENTATION_CONTEXT_INVALID` (the iOS+Azure
  /// "-3" case) also becomes `null` (the session simply ended); a missing
  /// native plugin (Pigeon's `channel-error`, or [MissingPluginException])
  /// becomes a clear [OidcException]; any other [PlatformException] is rethrown
  /// wrapped.
  Future<String?> _guard(String method, Future<String?> Function() call) async {
    try {
      return await call();
    } on MissingPluginException catch (e, st) {
      throw OidcException(
        'The native oidc_darwin plugin is not available on this platform. '
        'Ensure the app runs on iOS 13+ / macOS 10.15+ with the plugin '
        'registered.',
        internalException: e,
        internalStackTrace: st,
      );
    } on PlatformException catch (e, st) {
      // A cancelled flow is benign and maps to `null`.
      if (e.code == OidcNativeErrorCodes.userCancelled) {
        return null;
      }
      // On end-session, a closed presentation context (the iOS+Azure "-3"
      // case) simply means the session ended; treat it as a successful logout
      // with no response payload.
      if (method == OidcNativeMethods.endSession &&
          e.code == OidcNativeErrorCodes.presentationContextInvalid) {
        return null;
      }
      // Pigeon surfaces an unregistered host API as a `channel-error`.
      if (e.code == 'channel-error') {
        throw OidcException(
          'The native oidc_darwin plugin is not available on this platform. '
          'Ensure the app runs on iOS 13+ / macOS 10.15+ with the plugin '
          'registered.',
          internalException: e,
          internalStackTrace: st,
        );
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
