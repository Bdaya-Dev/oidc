//cspell: disable

import 'dart:async';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';

/// Pure dart implementation of OidcUserManagerBase that uses package:web and
/// is independant of flutter.
class OidcUserManagerWeb extends OidcUserManagerBase {
  OidcUserManagerWeb.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super.lazy();

  OidcUserManagerWeb({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  }) : super();

  static const _coreInstance = OidcWebCore();

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
  ) {
    return _coreInstance.getAuthorizationResponse(
      metadata,
      request,
      options.web,
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
  ) {
    return _coreInstance.getEndSessionResponse(
      metadata,
      request,
      options.web,
    );
  }

  @override
  final bool isWeb = true;

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
}
