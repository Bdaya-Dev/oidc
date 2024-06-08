import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oidc/src/facade.dart';
import 'package:oidc_core/oidc_core.dart';

/// The flutter implementation of OidcUserManagerBase
class OidcUserManager extends OidcUserManagerBase {
  ///
  OidcUserManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  ///
  OidcUserManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
  ) {
    return OidcFlutter.getPlatformAuthorizationResponse(
      metadata: metadata,
      request: request,
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
  ) {
    return OidcFlutter.getPlatformEndSessionResponse(
      metadata: metadata,
      request: request,
    );
  }

  @override
  bool get isWeb => kIsWeb;

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    return OidcFlutter.listenToFrontChannelLogoutRequests(
      listenTo: listenOn,
      options: options,
    );
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return OidcFlutter.monitorSessionStatus(
      checkSessionIframe: checkSessionIframe,
      request: request,
    );
  }
}
