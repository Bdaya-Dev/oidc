// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_web/extensions/web_core_options_mapper.dart';
import 'package:oidc_web_core/oidc_web_core.dart';


/// The Web implementation of [OidcPlatform], which depends on [OidcWebCore].
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
  ) async {
    return _coreInstance.getAuthorizationResponse(
      metadata,
      request,
      options.web.mapToWebCore(),
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
      options.web.mapToWebCore(),
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
      OidcPlatformSpecificOptions options) {
    return _coreInstance.getEndSessionResponse(
      metadata,
      request,
      options.web.mapToWebCore(),
    );
  }
}
