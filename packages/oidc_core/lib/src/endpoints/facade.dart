import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:nonce/nonce.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:uuid/uuid.dart';

const _authorizationHeaderKey = 'Authorization';
const _formUrlEncoded = 'application/x-www-form-urlencoded';

/// Helper class for dart-based openid connect clients.
class OidcEndpoints {
  static T _handleResponse<T>({
    required T Function(Map<String, dynamic> response) mapper,
    required http.Request request,
    required http.Response response,
  }) {
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body.containsKey(OidcConstants_AuthParameters.error)) {
        final resp = OidcErrorResponse.fromJson(body);
        throw OidcException.serverError(
          errorResponse: resp,
          rawRequest: request,
          rawResponse: response,
        );
      }
      if (!(response.statusCode >= 200 && response.statusCode < 400)) {
        throw OidcException(
          'Failed to handle the response from endpoint (status code ${response.statusCode}): ${request.url}',
          rawRequest: request,
          rawResponse: response,
        );
      }
      return mapper(body);
    } on OidcException {
      rethrow;
    } catch (e, st) {
      throw OidcException(
        'Failed to handle the response from endpoint: ${request.url}',
        internalException: e,
        internalStackTrace: st,
        rawRequest: request,
        rawResponse: response,
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
    final bytes = utf8.encode(nonce);
    final hashedNonce = sha256.convert(bytes).toString();

    final stateData = OidcAuthorizeState(
      id: const Uuid().v4(),
      createdAt: clock.now(),
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      redirectUri: input.redirectUri,
      clientId: input.clientId,
      nonce: hashedNonce,
      originalUri: input.originalUri,
      data: input.extraStateData,
      extraTokenParams: input.extraTokenParameters,
      options: input.options,
      extraTokenHeaders: input.extraTokenHeaders,
    );
    //store the state
    if (store != null) {
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
      // store the current state and nonce.
      // await store.setCurrentState(stateData.id);
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
      extraScopeToConsent: input.extraScopeToConsent,
      acrValues: input.acrValues,
      codeChallenge: codeChallenge,
      codeChallengeMethod: codeChallengeMethod,
      display: input.display,
      extra: input.extraParameters,
      idTokenHint: input.idTokenHint,
      loginHint: input.loginHint,
      maxAge: input.maxAge,
      nonce: hashedNonce,
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
      createdAt: clock.now(),
      codeVerifier: null,
      codeChallenge: null,
      redirectUri: input.redirectUri,
      clientId: input.clientId,
      nonce: nonce,
      originalUri: input.originalUri,
      options: input.options,
      data: input.extraStateData,
      extraTokenParams: null,
      extraTokenHeaders: null,
    );
    if (store != null) {
      //store the state
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
      // store the current state and nonce.
      // await store.setCurrentState(stateData.id);
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
    );
  }

  /// takes an input response uri from the /authorize endpoint, and gets the parameters from it.
  static ({Map<String, dynamic> parameters, String responseMode})
      resolveAuthorizeResponseParameters({
    required Uri responseUri,
    String? responseMode,
    String? resolveResponseModeByKey,
  }) {
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

      if (responseUri.queryParameters.containsKey(key) ||
          responseUri.queryParameters
              .containsKey(OidcConstants_AuthParameters.error)) {
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

    return (
      parameters: {
        ...parameters,
        OidcConstants_AuthParameters.responseMode: resolvedResponseMode,
      },
      responseMode: resolvedResponseMode
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
    final (:parameters, responseMode: resolvedResponseMode) =
        resolveAuthorizeResponseParameters(
      responseUri: responseUri,
      resolveResponseModeByKey: resolveResponseModeByKey,
      responseMode: responseMode,
    );

    final p = {
      ...parameters,
      OidcConstants_AuthParameters.responseMode: resolvedResponseMode,
      ...?overrides,
    };
    if (parameters.containsKey(OidcConstants_AuthParameters.error)) {
      throw OidcException.serverError(
        errorResponse: OidcErrorResponse.fromJson(p),
      );
    }
    return OidcAuthorizeResponse.fromJson(p);
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
      mapper: OidcTokenResponse.fromJson,
      response: resp,
      request: req,
    );
  }

  static Future<OidcUserInfoResponse> userInfo({
    required Uri userInfoEndpoint,
    required String accessToken,
    String requestMethod = OidcConstants_RequestMethod.get,
    OidcUserInfoAccessTokenLocations tokenLocation =
        OidcUserInfoAccessTokenLocations.authorizationHeader,
    bool followDistributedClaims = true,
    JsonWebKeyStore? keyStore,
    List<String>? allowedAlgorithms,
    Map<String, String>? headers,
    http.Client? client,
    Future<String?> Function(String, Uri)? getAccessTokenForDistributedSource,
  }) async {
    if (tokenLocation == OidcUserInfoAccessTokenLocations.formParameter &&
        requestMethod != OidcConstants_RequestMethod.post) {
      throw const OidcException(
        'to send access_token as a form parameter, the request method MUST be post.',
      );
    }
    final req = _prepareRequest(
      method: requestMethod,
      uri: userInfoEndpoint,
      headers: {
        if (tokenLocation ==
            OidcUserInfoAccessTokenLocations.authorizationHeader)
          _authorizationHeaderKey: 'Bearer $accessToken',
        ...?headers,
      },
      bodyFields:
          tokenLocation == OidcUserInfoAccessTokenLocations.formParameter
              ? {
                  OidcConstants_AuthParameters.accessToken: accessToken,
                }
              : null,
    );

    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    const applicationJson = 'application/json';
    const applicationJwt = 'application/jwt';

    final contentTypeRaw = resp.headers['Content-Type'] ?? applicationJson;
    final contentTypeParts = contentTypeRaw.split(';');
    final contentType = contentTypeParts.firstOrNull;
    OidcUserInfoResponse ret;
    if (contentType == applicationJwt) {
      JsonWebToken jwt;
      if (keyStore != null) {
        jwt = await JsonWebToken.decodeAndVerify(
          resp.body,
          keyStore,
          allowedArguments: allowedAlgorithms,
        );
      } else {
        jwt = JsonWebToken.unverified(resp.body);
      }
      ret = OidcUserInfoResponse.fromJson(jwt.claims.toJson());
    } else {
      //defaults to json
      ret = _handleResponse(
        mapper: OidcUserInfoResponse.fromJson,
        response: resp,
        request: req,
      );
    }
    if (followDistributedClaims) {
      ret = await userInfoFollowDistributedClaims(
        response: ret,
        client: client,
        getAccessTokenFor: getAccessTokenForDistributedSource,
      );
    }
    return ret;
  }

  /// follows instructions in the spec https://openid.net/specs/openid-connect-core-1_0.html#AggregatedDistributedClaims
  /// to aggregate claims from multiple sources.
  static Future<OidcUserInfoResponse> userInfoFollowDistributedClaims({
    required OidcUserInfoResponse response,
    Future<String?> Function(String source, Uri endpoint)? getAccessTokenFor,
    http.Client? client,
  }) async {
    //
    final claimNames = {...?response.claimNames};
    final claimSources = {...?response.claimSources};
    if (claimNames.isEmpty || claimSources.isEmpty) {
      return response;
    }
    final neededSources = claimNames.values.toSet();
    final availableSources = (Map.fromEntries(
      neededSources.map((e) => MapEntry(e, claimSources[e])),
    )..removeWhere((key, value) => value == null))
        .cast<String, OidcClaimSource>();
    if (availableSources.isEmpty) {
      return response;
    }
    // maps source key, to its claims
    final resolvedClaims = <String, Map<String, dynamic>>{};
    for (final sourceEntry in availableSources.entries) {
      final sourceKey = sourceEntry.key;
      final targetMap = resolvedClaims[sourceKey] ??= <String, dynamic>{};
      final sourceDesc = sourceEntry.value;
      if (sourceDesc is OidcAggregatedClaimSource) {
        final jwt = sourceDesc.jwt;
        final parsedJwt = JsonWebToken.unverified(jwt);
        targetMap.addEntries(
          parsedJwt.claims
              .toJson()
              .entries
              .where((element) => claimNames.containsKey(element.key)),
        );
      } else if (sourceDesc is OidcDistributedClaimSource) {
        var accessToken = sourceDesc.accessToken;
        accessToken ??=
            await getAccessTokenFor?.call(sourceKey, sourceDesc.endpoint);

        final request = http.Request(
          OidcConstants_RequestMethod.get,
          sourceDesc.endpoint,
        );
        if (accessToken != null) {
          request.headers[_authorizationHeaderKey] = 'Bearer $accessToken';
        }
        final endpointResp = await OidcInternalUtilities.sendWithClient(
          client: client,
          request: request,
        );
        if (endpointResp.statusCode >= 200 && endpointResp.statusCode < 300) {
          //success
          JsonWebToken? parsedJwt;
          try {
            parsedJwt = JsonWebToken.unverified(endpointResp.body);
          } catch (_) {
            parsedJwt = null;
          }
          if (parsedJwt != null) {
            targetMap.addEntries(
              parsedJwt.claims
                  .toJson()
                  .entries
                  .where((element) => claimNames.containsKey(element.key)),
            );
          }
        } else {
          continue;
        }
      } else {
        continue;
      }
    }
    final newClaims = {
      ...response.src,
    };
    for (final claimEntry in claimNames.entries) {
      final claimName = claimEntry.key;
      final sourceKey = claimEntry.value;
      final sourceResolved = resolvedClaims[sourceKey] ??= {};
      final claimValue = sourceResolved[claimName];
      if (claimValue != null) {
        newClaims[claimName] = claimValue;
      }
    }
    return OidcUserInfoResponse.fromJson(newClaims);
  }

  /// Sends a device authorization request.
  ///
  /// this adapts: [rfc8628](https://datatracker.ietf.org/doc/html/rfc8628)
  ///
  /// if [credentials] is set to null, it's up to the caller how to authenticate
  /// the request; either via [headers] or [extraBodyFields].
  static Future<OidcDeviceAuthorizationResponse> deviceAuthorization({
    required Uri deviceAuthorizationEndpoint,
    required OidcDeviceAuthorizationRequest request,
    OidcClientAuthentication? credentials,
    Map<String, String>? headers,
    Map<String, dynamic>? extraBodyFields,
    http.Client? client,
  }) async {
    final authHeader = credentials?.getAuthorizationHeader();
    final authBodyParams = credentials?.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: deviceAuthorizationEndpoint,
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
      mapper: OidcDeviceAuthorizationResponse.fromJson,
      response: resp,
      request: req,
    );
  }
}
