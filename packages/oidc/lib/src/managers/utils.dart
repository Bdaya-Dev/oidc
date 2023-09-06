import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nonce/nonce.dart';
import 'package:oidc/src/models/authorize_request.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:uuid/uuid.dart';

/// Helper class for openid connect.
class Oidc {
  static OidcPlatform get _platform => OidcPlatform.instance;

  /// Prepares an [OidcAuthorizeRequest] to be used in [getAuthorizationResponse].
  ///
  /// This creates a [OidcAuthorizeState] and stores in it some of the passed parameters.
  static Future<OidcAuthorizeRequest> prepareAuthorizationCodeFlowRequest({
    required OidcProviderMetadata metadata,
    required OidcSimpleAuthorizationCodeRequest input,
    required OidcStore store,
    OidcAuthorizePlatformSpecificOptions options =
        const OidcAuthorizePlatformSpecificOptions(),
  }) async {
    //
    final supportedCodeChallengeMethods =
        metadata.codeChallengeMethodsSupported;
    String? codeVerifier;
    String? codeChallenge;
    String? codeChallengeMethod;

    if (supportedCodeChallengeMethods != null &&
        supportedCodeChallengeMethods.isNotEmpty) {
      codeVerifier = OidcPkcePair.generateVerifier();
      if (supportedCodeChallengeMethods
          .contains(OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256)) {
        codeChallenge = OidcPkcePair.generateS256Challenge(codeVerifier);
        codeChallengeMethod =
            OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256;
      } else if (supportedCodeChallengeMethods
          .contains(OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain)) {
        codeChallenge = OidcPkcePair.generatePlainChallenge(codeVerifier);
        codeChallengeMethod =
            OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain;
      } else {
        codeVerifier = null;
        codeChallenge = null;
      }
    }

    final nonce = Nonce.generate(32, Random.secure());
    final stateData = OidcAuthorizeState(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      authorizationRequest: {
        // store the information that you need from the simple request.
        OidcConstants_AuthParameters.clientId: input.clientId,
      },
      nonce: nonce,
      originalUri: input.originalUri,
      requestType: options.web.navigationMode.name,
      data: input.extraStateData,
    );
    //store the state
    await store.set(
      OidcStoreNamespace.state,
      key: stateData.id,
      value: stateData.toStorageString(),
    );
    // store the current state and nonce.
    await store.set(
      OidcStoreNamespace.session,
      key: OidcConstants_AuthParameters.state,
      value: stateData.id,
    );
    await store.set(
      OidcStoreNamespace.session,
      key: OidcConstants_AuthParameters.nonce,
      value: nonce,
    );
    final supportsOpenIdScope =
        metadata.scopesSupported?.contains(OidcConstants_Scopes.openid) ??
            false;

    return OidcAuthorizeRequest(
      state: stateData.id,
      clientId: input.clientId,
      redirectUri: input.redirectUri,
      responseType: [OidcConstants_AuthorizationEndpoint_ResponseType.code],
      scope: input.scope.contains(OidcConstants_Scopes.openid)
          ? input.scope
          : [
              if (supportsOpenIdScope) OidcConstants_Scopes.openid,
              ...input.scope,
            ],
      acrValues: input.acrValues,
      codeChallenge: codeChallenge,
      codeChallengeMethod: codeChallengeMethod,
      display: input.display,
      extra: input.extra,
      idTokenHint: input.idTokenHint,
      loginHint: input.loginHint,
      maxAge: input.maxAge,
      nonce: nonce,
      prompt: input.prompt,
      // it isn't recommended to change the response_mode
      // responseMode: OidcConstants_AuthorizeRequest_ResponseMode.query,
      uiLocales: input.uiLocales,
    );
  }

  /// starts the authorization code flow, and returns the response.
  ///
  /// if the `request.responseType` is set to anything other than `code`, it returns null.
  ///
  /// NOTE: this DOES NOT do token exchange.
  ///
  /// consider using [OidcUtils.getProviderMetadata] to get the [metadata] parameter if you don't have it.
  static Future<OidcAuthorizeResponse?> getAuthorizationResponse({
    required OidcProviderMetadata metadata,
    required OidcAuthorizeRequest request,
    required OidcStore store,
    OidcAuthorizePlatformSpecificOptions options =
        const OidcAuthorizePlatformSpecificOptions(),
  }) {
    return _platform.getAuthorizationResponse(
      metadata,
      request,
      store,
      stateData,
      options,
    );
  }
}
