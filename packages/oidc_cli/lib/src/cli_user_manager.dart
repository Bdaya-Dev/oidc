import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart' as mason;
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';

/// An OIDC user manager for CLI apps based on `oidc_loopback_listener`.
///
/// This uses the same flow as `oidc_desktop`, but without a Flutter dependency.
class CliUserManager extends OidcUserManagerBase {
  /// Creates a [CliUserManager].
  CliUserManager({
    required this.cliLogger,
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.settings,
    required super.store,
    super.httpClient,
    super.keyStore,
  }) : super();

  /// Creates a [CliUserManager] using lazy discovery.
  CliUserManager.lazy({
    required this.cliLogger,
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  /// Logger used for user-facing output.
  final mason.Logger cliLogger;

  /// starts a listener and gets a response Uri.
  /// The user needs to click on the printed link to complete the login.
  ///
  /// When [options] carries a positive `flowTimeoutSeconds` for the current
  /// desktop OS, the loopback wait is bounded: an abandoned browser flow
  /// (the user closes the tab, or none opens) surfaces an [OidcException]
  /// instead of hanging the CLI forever and leaking the bound loopback socket.
  /// `null`/non-positive means unbounded, matching `oidc_desktop`'s default.
  Future<Uri?> startListenerAndGetUri({
    required Uri originalRedirectUri,
    required String redirectUriKey,
    required Uri endpoint,
    required Map<String, dynamic> requestParameters,
    required String logRequestDesc,
    required Completer<Uri> actualRedirectUriCompleter,
    required Future<void> Function(Uri) printFunction,
    OidcPlatformSpecificOptions options = const OidcPlatformSpecificOptions(),
  }) async {
    final listener = OidcLoopbackListener(
      path: originalRedirectUri.path,
      port: originalRedirectUri.port,
    );
    final serverCompleter = Completer<HttpServer>();
    // Mirror `oidc_desktop.startListenerAndGetUri`: an opt-in, per-OS flow
    // timeout bounds the wait so the listener force-closes its socket and
    // throws a `TimeoutException` if no redirect arrives in time.
    final ts = _resolveFlowTimeoutSeconds(options);
    final timeout = (ts != null && ts > 0) ? Duration(seconds: ts) : null;
    //don't await the responseUriFuture until we launch the url.
    final responseUriFuture = listener.listenForSingleResponse(
      serverCompleter: serverCompleter,
      timeout: timeout,
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
        ...OidcInternalUtilities.serializeQueryParameters(requestParameters),
        // override the redirect uri.
        redirectUriKey: originalRedirectUri.toString(),
      },
    );

    await printFunction(uri);

    // wait for a response from the server listener.
    final Uri? responseUri;
    try {
      responseUri = await responseUriFuture;
    } on TimeoutException catch (e, st) {
      final message =
          'The $logRequestDesc flow timed out after $ts seconds without '
          'receiving a redirect on the loopback listener.';
      cliLogger.warn(message);
      throw OidcException(
        message,
        internalException: e,
        internalStackTrace: st,
      );
    }
    if (responseUri == null) {
      return null;
    }
    return responseUri;
  }

  /// Resolves the loopback flow timeout (in seconds) from the platform-specific
  /// [options], reading the native-options object for the current desktop OS.
  ///
  /// Mirrors `oidc_desktop`'s `getNativeOptions` convention, which selects
  /// `options.windows` / `options.linux` per platform package; a single CLI
  /// binary can run on any desktop OS, so it selects the field matching
  /// [Platform.operatingSystem] instead. Returns `null` (unbounded wait) unless
  /// the caller opted in with a positive value for that OS.
  int? _resolveFlowTimeoutSeconds(OidcPlatformSpecificOptions options) {
    if (Platform.isMacOS) {
      return options.macos.flowTimeoutSeconds;
    }
    if (Platform.isWindows) {
      return options.windows.flowTimeoutSeconds;
    }
    // Linux and any other POSIX host a Dart CLI may run on.
    return options.linux.flowTimeoutSeconds;
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
      options: options,
      printFunction: (uri) async {
        cliLogger.info('Please open the following link: $uri');
        // coverage:ignore-start
        // Unconditionally launches the host OS's real default browser via a
        // subprocess. Exercising this in a unit test would pop a real
        // browser window as a side effect of running `dart test` (there is
        // no injection seam for the OS-open call, unlike `oidc_desktop`'s
        // `launchUrl` callback), so the whole login/logout suite
        // deliberately never reaches this branch — see the note atop
        // `login_interactive_command_test.dart` and
        // `pub_proxy_command_test.dart` for the same convention applied to
        // the analogous `dart pub token add` subprocess in `dart_pub.dart`.
        try {
          if (Platform.isWindows) {
            await Process.run('rundll32', [
              'url.dll,FileProtocolHandler',
              uri.toString(),
            ]);
          } else if (Platform.isMacOS) {
            await Process.run('open', [uri.toString()]);
          } else if (Platform.isLinux) {
            await Process.run('xdg-open', [uri.toString()]);
          }
        } on Exception catch (_) {
          // ignore
        }
        // coverage:ignore-end
      },
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
      options: options,
      printFunction: (uri) async {
        logger.info('Please open the following link: $uri');
        // coverage:ignore-start
        // See the matching note in `getAuthorizationResponse` above: this
        // unconditionally shells out to launch the host OS's real default
        // browser, which unit tests deliberately never trigger.
        try {
          if (Platform.isWindows) {
            await Process.run('rundll32', [
              'url.dll,FileProtocolHandler',
              uri.toString(),
            ]);
          } else if (Platform.isMacOS) {
            await Process.run('open', [uri.toString()]);
          } else if (Platform.isLinux) {
            await Process.run('xdg-open', [uri.toString()]);
          }
        } on Exception catch (_) {
          // ignore
        }
        // coverage:ignore-end
      },
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
