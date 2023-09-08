import 'dart:math';

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
    required OidcSimpleAuthorizationCodeFlowRequest input,
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
      redirectUri: input.redirectUri,
      clientId: input.clientId,
      nonce: nonce,
      originalUri: input.originalUri,
      requestType: options.web.navigationMode.name,
      data: input.extraStateData,
      extraTokenParams: input.extraTokenParameters,
      webLaunchMode: options.web.navigationMode.name,
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
      extra: input.extraParameters,
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

  /// Prepares an [OidcAuthorizeRequest] to be used in [getAuthorizationResponse].
  ///
  /// This creates a [OidcAuthorizeState] and stores in it some of the passed parameters.
  static Future<OidcAuthorizeRequest> prepareImplicitCodeFlowRequest({
    required OidcProviderMetadata metadata,
    required OidcSimpleImplicitFlowRequest input,
    required OidcStore store,
    OidcAuthorizePlatformSpecificOptions options =
        const OidcAuthorizePlatformSpecificOptions(),
  }) async {
    //
    final nonce = Nonce.generate(32, Random.secure());
    final stateData = OidcAuthorizeState(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      codeVerifier: null,
      codeChallenge: null,
      redirectUri: input.redirectUri,
      clientId: input.clientId,
      nonce: nonce,
      originalUri: input.originalUri,
      requestType: options.web.navigationMode.name,
      data: input.extraStateData,
      extraTokenParams: null,
      webLaunchMode: options.web.navigationMode.name,
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
      responseType: input.responseType,
      scope: input.scope.contains(OidcConstants_Scopes.openid)
          ? input.scope
          : [
              if (supportsOpenIdScope) OidcConstants_Scopes.openid,
              ...input.scope,
            ],
      acrValues: input.acrValues,
      display: input.display,
      extra: input.extraParameters,
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

  /// starts the authorization flow, and returns the response.
  ///
  /// on android/ios/macos, if the `request.responseType` is set to anything other than `code`, it returns null.
  ///
  /// NOTE: this DOES NOT do token exchange.
  ///
  /// consider using [OidcEndpoints.getProviderMetadata] to get the [metadata] parameter if you don't have it.
  static Future<OidcAuthorizeResponse?> getAuthorizationResponse({
    required OidcProviderMetadata metadata,
    required OidcAuthorizeRequest request,
    required OidcStore store,
    OidcAuthorizePlatformSpecificOptions options =
        const OidcAuthorizePlatformSpecificOptions(),
  }) async {
    final stateStr = request.state == null
        ? null
        : await store.get(
            OidcStoreNamespace.state,
            key: request.state!,
          );
    final stateData = stateStr == null
        ? null
        : OidcAuthorizeState.fromStorageString(stateStr);
    try {
      return _platform.getAuthorizationResponse(
        metadata,
        request,
        store,
        stateData,
        options,
      );
    } catch (e, st) {
      throw OidcException(
        'Failed to authorize user',
        internalException: e,
        internalStackTrace: st,
      );
    }
  }
}
