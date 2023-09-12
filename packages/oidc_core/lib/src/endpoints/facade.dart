import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:nonce/nonce.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:uuid/uuid.dart';

const _authorizationHeaderKey = 'Authorization';
const _formUrlEncoded = 'application/x-www-form-urlencoded';

/// Helper class for dart-based openid connect clients.
class OidcEndpoints {
  static T _handleResponse<T>({
    required Uri uri,
    required T Function(Map<String, dynamic> response) mapper,
    required http.Request request,
    required http.Response response,
  }) {
    final commonExtra = {
      OidcConstants_Exception.request: request,
      OidcConstants_Exception.response: response,
      OidcConstants_Exception.statusCode: response.statusCode,
    };
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey(OidcConstants_AuthParameters.error)) {
        throw OidcException(
          'Error returned from the endpoint: $uri',
          errorResponse: OidcErrorResponse.fromJson(body),
          extra: commonExtra,
        );
      }
      return mapper(body);
    } on OidcException {
      rethrow;
    } catch (e, st) {
      throw OidcException(
        'Failed to handle the response from endpoint: $uri',
        internalException: e,
        internalStackTrace: st,
        extra: commonExtra,
      );
    }
  }

  static http.Request _prepareRequest({
    required String method,
    required Uri uri,
    required Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? bodyFields,
  }) {
    final req = http.Request(method, uri);
    if (headers != null) {
      req.headers.addAll(headers);
    }
    if (contentType != null) {
      req.headers['Content-Type'] = contentType;
    }
    if (bodyFields != null) {
      req.bodyFields = (bodyFields.map<String, String?>(
        (key, value) => MapEntry(
          key,
          value is List<String>
              ? OidcInternalUtilities.joinSpaceDelimitedList(value)
              : value?.toString(),
        ),
      )..removeWhere((key, value) => value is! String))
          .cast<String, String>();
    }
    return req;
  }

  /// Prepares an opinionated [OidcAuthorizeRequest]
  /// from an [OidcSimpleAuthorizationCodeFlowRequest].
  ///
  /// This creates a [OidcAuthorizeState] as well, which is used to store useful
  /// information about the flow parameters for later validation.
  ///
  /// If the [store] parameter is passed, it persists the generated nonce/state.
  static Future<OidcSimpleAuthorizationRequestContainer>
      prepareAuthorizationCodeFlowRequest({
    required OidcProviderMetadata metadata,
    required OidcSimpleAuthorizationCodeFlowRequest input,
    OidcStore? store,
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
      data: input.extraStateData,
      extraTokenParams: input.extraTokenParameters,
      options: input.options,
    );
    //store the state
    if (store != null) {
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
      // store the current state and nonce.
      await store.setCurrentState(stateData.id);
      await store.setCurrentNonce(nonce);
    }

    final supportsOpenIdScope =
        metadata.scopesSupported?.contains(OidcConstants_Scopes.openid) ??
            false;

    final req = OidcAuthorizeRequest(
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
      uiLocales: input.uiLocales,
    );

    return OidcSimpleAuthorizationRequestContainer(
      request: req,
      stateData: stateData,
    );
  }

  /// Prepares an opinionated [OidcAuthorizeRequest]
  /// from an [OidcSimpleImplicitFlowRequest].
  ///
  /// This creates a [OidcAuthorizeState] as well, which is used to store useful
  /// information about the flow parameters for later validation.
  ///
  /// If the [store] parameter is passed, it persists the generated nonce/state.
  static Future<OidcAuthorizeRequest> prepareImplicitFlowRequest({
    required OidcProviderMetadata metadata,
    required OidcSimpleImplicitFlowRequest input,
    OidcStore? store,
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
      options: input.options,
      data: input.extraStateData,
      extraTokenParams: null,
    );
    if (store != null) {
      //store the state
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
      // store the current state and nonce.
      await store.setCurrentState(stateData.id);
      await store.setCurrentNonce(nonce);
    }

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
      uiLocales: input.uiLocales,
    );
  }

  /// Gets the Oidc provider metadata from a '.well-known' url
  static Future<OidcProviderMetadata> getProviderMetadata(
    Uri wellKnownUri, {
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.get,
      uri: wellKnownUri,
      headers: headers,
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcProviderMetadata.fromJson,
      request: req,
      response: resp,
      uri: wellKnownUri,
    );
  }

  /// parses the Uri from an /authorize response.
  ///
  /// if [responseMode] is assigned, it's used to determine the
  /// response location; it can either be:
  /// - `query` (in authorization code flow)
  /// - `fragment` (in implicit flow).
  ///
  /// if [responseMode] is null, [resolveResponseModeByKey] (`state` by default)
  /// is used to dynamically determine the response location,
  /// where it would first look in the query parameters, then look in
  /// the fragment parameters if it didn't find the key.
  ///
  /// if [responseMode] wasn't assigned a proper value, or if it wasn't resolved
  /// , an [OidcException] is raised explaining the error.
  static Future<OidcAuthorizeResponse> parseAuthorizeResponse({
    required Uri responseUri,
    String? responseMode,
    String? resolveResponseModeByKey,
    Map<String, dynamic>? overrides,
  }) async {
    String resolvedResponseMode;
    Map<String, String> parameters;
    if (responseMode != null) {
      resolvedResponseMode = responseMode;
      switch (responseMode) {
        case OidcConstants_AuthorizeRequest_ResponseMode.query:
          parameters = responseUri.queryParameters;
        case OidcConstants_AuthorizeRequest_ResponseMode.fragment:
          final fragmentUri = Uri(query: responseUri.fragment);
          parameters = fragmentUri.queryParameters;
        default:
          throw OidcException(
            "responseMode of $responseMode can't "
            'be handled using a Uri only response.',
          );
      }
    } else {
      final key =
          resolveResponseModeByKey ?? OidcConstants_AuthParameters.state;

      if (responseUri.queryParameters.containsKey(key)) {
        parameters = responseUri.queryParameters;
        resolvedResponseMode =
            OidcConstants_AuthorizeRequest_ResponseMode.query;
      } else {
        final fragmentUri = Uri(query: responseUri.fragment);
        if (fragmentUri.queryParameters.containsKey(key)) {
          parameters = fragmentUri.queryParameters;

          resolvedResponseMode =
              OidcConstants_AuthorizeRequest_ResponseMode.fragment;
        } else {
          throw OidcException(
            "Couldn't resolve the response mode, "
            'make sure the key ($key) exists in the Uri.',
          );
        }
      }
    }

    return OidcAuthorizeResponse.fromJson({
      ...parameters,
      OidcConstants_AuthParameters.responseMode: resolvedResponseMode,
      ...?overrides,
    });
  }

  /// Sends a token exchange request.
  ///
  /// if [credentials] is set to null, it's up to the caller how to authenticate
  /// the request; either via [headers] or [extraBodyFields].
  static Future<OidcTokenResponse> token({
    required Uri tokenEndpoint,
    required OidcTokenRequest request,
    OidcClientAuthentication? credentials,
    Map<String, String>? headers,
    Map<String, dynamic>? extraBodyFields,
    http.Client? client,
  }) async {
    final authHeader = credentials?.getAuthorizationHeader();
    final authBodyParams = credentials?.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: tokenEndpoint,
      headers: {
        if (authHeader != null) _authorizationHeaderKey: authHeader,
        ...?headers,
      },
      contentType: _formUrlEncoded,
      bodyFields: {
        ...request.toMap(),
        if (authHeader == null) ...?authBodyParams,
        ...?extraBodyFields,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      uri: tokenEndpoint,
      mapper: OidcTokenResponse.fromJson,
      response: resp,
      request: req,
    );
  }
}
