import 'dart:async';

import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Android implementation of [OidcPlatform].
///
/// Performs the authorization / end-session browser flow using Android Chrome
/// Custom Tabs through the Pigeon-generated [OidcAndroidHostApi]. All OIDC logic
/// (URL building, PKCE, `state`, `nonce`, and response parsing) stays in
/// pure-Dart `oidc_core`; the native side only opens a URL and returns the
/// redirect URI.
class OidcAndroid extends OidcPlatform {
  /// Creates the Android platform implementation.
  ///
  /// [hostApi] is injectable for testing; production uses the default
  /// Pigeon-generated host API bound to the standard binary messenger.
  OidcAndroid({OidcAndroidHostApi? hostApi})
      : _hostApi = hostApi ?? OidcAndroidHostApi();

  /// Registers this class as the default instance of [OidcPlatform].
  static void registerWith() {
    OidcPlatform.instance = OidcAndroid();
  }

  /// The Pigeon host API that talks to the native Android plugin.
  final OidcAndroidHostApi _hostApi;

  @override
  Stream<OidcNativeBrowserEvent> nativeBrowserEvents() => streamNativeEvents()
      .map(OidcNativeBrowserEvent.fromMap)
      .where((e) => e != null)
      .cast<OidcNativeBrowserEvent>();

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
    final responseUrl = await _guard(
      OidcNativeMethods.authorize,
      () => _hostApi.authorize(
        url.toString(),
        request.redirectUri.toString(),
        request.redirectUri.scheme,
        // Serialized Chrome Custom Tabs options; the native side applies the
        // ones it supports and ignores the rest.
        options.android.toJson(),
      ),
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
    final postLogout = request.postLogoutRedirectUri;
    final responseUrl = await _guard(
      OidcNativeMethods.endSession,
      () => _hostApi.endSession(
        url.toString(),
        postLogout?.toString(),
        postLogout?.scheme,
        options.android.toJson(),
      ),
    );
    if (responseUrl == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(
      Uri.parse(responseUrl).queryParameters,
    );
  }

  /// Invokes a native [OidcAndroidHostApi] call and normalizes its failure
  /// modes: a `USER_CANCELLED` error becomes `null` (the null-means-cancelled
  /// contract shared by all platforms), a missing native plugin (Pigeon's
  /// `channel-error`, or a [MissingPluginException]) becomes a clear
  /// [OidcException], and any other [PlatformException] is rethrown wrapped.
  Future<String?> _guard(
    String method,
    Future<String?> Function() call,
  ) async {
    try {
      return await call();
    } on MissingPluginException catch (e, st) {
      throw OidcException(
        'The native oidc_android plugin is not available. Ensure the app '
        'runs on Android with the plugin registered.',
        internalException: e,
        internalStackTrace: st,
      );
    } on PlatformException catch (e, st) {
      // A cancelled flow is benign and maps to `null`.
      if (e.code == OidcNativeErrorCodes.userCancelled) {
        return null;
      }
      // Pigeon surfaces an unregistered host API as a `channel-error`.
      if (e.code == 'channel-error') {
        throw OidcException(
          'The native oidc_android plugin is not available. Ensure the app '
          'runs on Android with the plugin registered.',
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
  ) =>
          const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) =>
      const Stream.empty();
}
