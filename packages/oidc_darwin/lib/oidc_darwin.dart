import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

/// The iOS + macOS ("darwin") implementation of [OidcPlatform].
///
/// Performs the authorization / end-session browser flow using the system
/// `ASWebAuthenticationSession` through the Pigeon-generated
/// [OidcAppleHostApi]. All OIDC logic (URL building, PKCE, `state`, `nonce`,
/// and response parsing) stays in pure-Dart `oidc_core`; the native side only
/// opens a URL and returns the redirect URI. This replaces the previous
/// `flutter_appauth`-based path and merges the former `oidc_ios` + `oidc_macos`
/// packages.
///
/// On **macOS**, when
/// [OidcNativeOptionsApple.navigationMode] is
/// [OidcAppleNavigationMode.loopbackSystemBrowser], the flow instead skips
/// `ASWebAuthenticationSession` entirely: it opens the authorization URL in the
/// user's default system browser (`url_launcher`) and captures the redirect on
/// an [RFC 8252 §7.3](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3)
/// loopback listener (`http://127.0.0.1:{port}`), reusing the same
/// `oidc_loopback_listener` transport as `oidc_desktop`. iOS ignores the mode.
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

  /// Whether the current flow should run through the default system browser +
  /// loopback listener instead of `ASWebAuthenticationSession`.
  ///
  /// Only honored on macOS; iOS always uses `ASWebAuthenticationSession`
  /// (there is no iOS equivalent of opening the default system browser and
  /// binding a loopback interface).
  @visibleForTesting
  bool useLoopbackSystemBrowser(OidcPlatformSpecificOptions options) =>
      defaultTargetPlatform == TargetPlatform.macOS &&
      _appleOptions(options).navigationMode ==
          OidcAppleNavigationMode.loopbackSystemBrowser;

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
    if (useLoopbackSystemBrowser(options)) {
      final redirectUriCompleter = Completer<Uri>();
      final responseUri = await _startLoopbackListenerAndGetUri(
        originalRedirectUri: request.redirectUri,
        redirectUriKey: OidcConstants_AuthParameters.redirectUri,
        appleOptions: _appleOptions(options),
        endpoint: authorizationEndpoint,
        requestParameters: request.toMap(),
        logRequestDesc: 'authorization',
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
    final postLogout = request.postLogoutRedirectUri;
    if (useLoopbackSystemBrowser(options)) {
      // With no post-logout redirect there is nothing to capture on the
      // loopback listener, so there is no browser round-trip to await
      // (mirrors `oidc_desktop`).
      if (postLogout == null) {
        return null;
      }
      final redirectUriCompleter = Completer<Uri>();
      final responseUri = await _startLoopbackListenerAndGetUri(
        originalRedirectUri: postLogout,
        redirectUriKey: OidcConstants_AuthParameters.postLogoutRedirectUri,
        appleOptions: _appleOptions(options),
        endpoint: endSessionEndpoint,
        requestParameters: request.toMap(),
        logRequestDesc: 'end session',
        actualRedirectUriCompleter: redirectUriCompleter,
      );
      if (responseUri == null) {
        return null;
      }
      return OidcEndSessionResponse.fromJson(responseUri.queryParameters);
    }
    final url = request.generateUri(endSessionEndpoint);
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

  /// Runs the macOS default-system-browser + loopback flow and returns the
  /// captured redirect [Uri] (or `null` when the flow ends without one).
  ///
  /// Mirrors `oidc_desktop`'s loopback orchestration: bind an
  /// [OidcLoopbackListener] on the redirect's host/port (port `0` binds an
  /// ephemeral port), rewrite `[originalRedirectUri]`'s port to the bound one,
  /// build the provider URL with that redirect, open it in the default browser,
  /// then await the single loopback redirect bounded by
  /// [OidcNativeOptionsApple.flowTimeoutSeconds].
  ///
  /// The actual (port-rewritten) redirect URI is published through
  /// [actualRedirectUriCompleter] so the caller can pass it as the
  /// `redirect_uri` override when parsing the response.
  Future<Uri?> _startLoopbackListenerAndGetUri({
    required Uri originalRedirectUri,
    required String redirectUriKey,
    required OidcNativeOptionsApple appleOptions,
    required Uri endpoint,
    required Map<String, dynamic> requestParameters,
    required String logRequestDesc,
    required Completer<Uri> actualRedirectUriCompleter,
  }) async {
    final listener = OidcLoopbackListener(
      path: originalRedirectUri.path,
      port: originalRedirectUri.port,
      successfulPageResponse: appleOptions.successfulPageResponse,
      methodMismatchResponse: appleOptions.methodMismatchResponse,
      notFoundResponse: appleOptions.notFoundResponse,
    );
    final serverCompleter = Completer<HttpServer>();
    final ts = appleOptions.flowTimeoutSeconds;
    final timeout = (ts != null && ts > 0) ? Duration(seconds: ts) : null;
    // Don't await the response future until after the url is launched.
    final responseUriFuture = listener.listenForSingleResponse(
      serverCompleter: serverCompleter,
      timeout: timeout,
    );
    // Wait until the server starts listening and we get a (possibly ephemeral)
    // port.
    final server = await serverCompleter.future;
    var redirectUri = originalRedirectUri;
    if (server.port != redirectUri.port) {
      // Replace the port in the redirectUri with the actual bound port.
      redirectUri = redirectUri.replace(port: server.port);
    }
    actualRedirectUriCompleter.complete(redirectUri);
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        // ignore: invalid_use_of_internal_member
        ...OidcInternalUtilities.serializeQueryParameters(requestParameters),
        // Override the redirect uri with the port-rewritten loopback address.
        redirectUriKey: redirectUri.toString(),
      },
    );

    final didLaunch = await _launchLoopbackUrl(uri, appleOptions: appleOptions);
    if (!didLaunch) {
      debugPrint(
        'oidc_darwin: failed to launch the $logRequestDesc request url: $uri',
      );
    }
    // Wait for a response from the loopback listener.
    final Uri? responseUri;
    try {
      responseUri = await responseUriFuture;
    } on TimeoutException catch (e, st) {
      throw OidcException(
        'The $logRequestDesc flow timed out after $ts seconds without '
        'receiving a redirect on the loopback listener.',
        internalException: e,
        internalStackTrace: st,
      );
    }
    return responseUri;
  }

  /// Opens [uri] for the loopback flow.
  ///
  /// When [OidcNativeOptionsApple.launchUrl] is set (a test seam) it is used
  /// verbatim; otherwise the default system browser is opened through
  /// `package:url_launcher`.
  Future<bool> _launchLoopbackUrl(
    Uri uri, {
    required OidcNativeOptionsApple appleOptions,
  }) async {
    if (appleOptions.launchUrl case final urlLauncher?) {
      return urlLauncher(uri);
    }
    if (!await canLaunchUrl(uri)) {
      debugPrint('oidc_darwin: might not be able to launch the url: $uri');
    }
    return launchUrl(uri);
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
