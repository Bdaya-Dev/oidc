// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_web_core/oidc_web_core.dart';

/// The flutter web implementation of [OidcPlatform], which depends on [OidcWebCore].
class OidcWeb extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith([Object? registrar]) {
    OidcPlatform.instance = OidcWeb();
  }

  static const _coreInstance = OidcWebCore();

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    return _coreInstance.getAuthorizationResponse(
      metadata,
      request,
      options.web,
      preparationResult,
    );
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    return _coreInstance.listenToFrontChannelLogoutRequests(
      listenOn,
      options.web,
    );
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return _coreInstance.monitorSessionStatus(
      checkSessionIframe: checkSessionIframe,
      request: request,
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) {
    return _coreInstance.getEndSessionResponse(
      metadata,
      request,
      options.web,
      preparationResult,
    );
  }

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) {
    return _coreInstance.prepareForRedirectFlow(options.web);
  }
}
