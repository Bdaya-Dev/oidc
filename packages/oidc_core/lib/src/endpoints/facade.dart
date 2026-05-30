import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
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
    final body = _handleResponseRaw(
      request: request,
      response: response,
    );
    return mapper(body);
  }

  static Map<String, dynamic> _handleResponseRaw({
    required http.Request request,
    required http.Response response,
  }) {
    try {
      final rawBody = utf8.decode(response.bodyBytes).trim();
      final body = rawBody.isNotEmpty
          ? jsonDecode(rawBody) as Map<String, dynamic>
          : <String, dynamic>{};
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
      return body;
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
      final pairs = <MapEntry<String, String>>[];
      var hasRepeated = false;
      for (final entry in bodyFields.entries) {
        final value = entry.value;
        if (value == null) {
          continue;
        }
        if (value is Iterable) {
          // A repeatable form parameter (e.g. RFC 8707 `resource`): emit one
          // pair per element. `http.Request.bodyFields` is a Map<String,String>
          // and cannot represent repeated keys, so when any value is a list the
          // body is URL-encoded manually below. (Space-delimited params such as
          // `scope` arrive already joined to a String, so they are unaffected.)
          hasRepeated = true;
          for (final item in value) {
            if (item != null) {
              pairs.add(MapEntry(entry.key, item.toString()));
            }
          }
        } else {
          pairs.add(MapEntry(entry.key, value.toString()));
        }
      }
      if (hasRepeated) {
        req.headers.putIfAbsent(
          'content-type',
          () => 'application/x-www-form-urlencoded; charset=utf-8',
        );
        req.body = pairs
            .map(
              (e) =>
                  '${Uri.encodeQueryComponent(e.key)}='
                  '${Uri.encodeQueryComponent(e.value)}',
            )
            .join('&');
      } else {
        req.bodyFields = {for (final e in pairs) e.key: e.value};
      }
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
      if (supportedCodeChallengeMethods.contains(
        OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256,
      )) {
        codeChallenge = OidcPkcePair.generateS256Challenge(codeVerifier);
        codeChallengeMethod =
            OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256;
      } else if (supportedCodeChallengeMethods.contains(
        OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain,
      )) {
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
      managerId: input.managerId,
      maxAge: input.maxAge,
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
      resource: input.resource,
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
      maxAge: input.maxAge,
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
          responseUri.queryParameters.containsKey(
            OidcConstants_AuthParameters.error,
          )) {
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
      responseMode: resolvedResponseMode,
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
    final (
      :parameters,
      responseMode: resolvedResponseMode,
    ) = resolveAuthorizeResponseParameters(
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
    OidcDPoPManager? dpopManager,
  }) async {
    // The client assertion (private_key_jwt / client_secret_jwt) and the DPoP
    // proof are both single-use, so they are (re)built on each attempt.
    Future<OidcTokenResponse> attempt() async {
      final resolved = credentials?.resolveForRequest(tokenEndpoint);
      final authHeader = resolved?.getAuthorizationHeader();
      final authBodyParams = resolved?.getBodyParameters();
      final req = _prepareRequest(
        method: OidcConstants_RequestMethod.post,
        uri: tokenEndpoint,
        headers: {
          _authorizationHeaderKey: ?authHeader,
          if (dpopManager != null)
            oidcDPoPHeaderName: dpopManager.createTokenProof(tokenEndpoint),
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

    if (dpopManager == null) {
      return attempt();
    }
    try {
      return await attempt();
    } on OidcException catch (e) {
      // RFC 9449 §8: the AS may reject the first request with `use_dpop_nonce`
      // and supply a `DPoP-Nonce`; cache it and retry exactly once with the
      // nonce in the proof.
      final nonce =
          e.rawResponse?.headers[oidcDPoPNonceHeaderName.toLowerCase()];
      if (nonce != null && e.errorResponse?.error == oidcDPoPUseNonceError) {
        dpopManager.setNonceFor(tokenEndpoint, nonce);
        return attempt();
      }
      rethrow;
    }
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
    OidcDPoPManager? dpopManager,
  }) async {
    if (tokenLocation == OidcUserInfoAccessTokenLocations.formParameter &&
        requestMethod != OidcConstants_RequestMethod.post) {
      throw const OidcException(
        'to send access_token as a form parameter, the request method MUST be post.',
      );
    }
    // The DPoP proof carries a single-use `ath`/`jti`, so the request is
    // (re)built on each attempt; the proof picks up the latest cached nonce.
    http.Request buildRequest() => _prepareRequest(
      method: requestMethod,
      uri: userInfoEndpoint,
      headers: {
        if (tokenLocation ==
            OidcUserInfoAccessTokenLocations.authorizationHeader)
          _authorizationHeaderKey:
              '${dpopManager != null ? 'DPoP' : 'Bearer'} $accessToken',
        // RFC 9449 §7.1: a DPoP-bound access token is presented with the `DPoP`
        // scheme + a proof whose `ath` binds it to this request.
        if (dpopManager != null)
          oidcDPoPHeaderName: dpopManager.createResourceProof(
            method: requestMethod,
            uri: userInfoEndpoint,
            accessToken: accessToken,
          ),
        ...?headers,
      },
      bodyFields:
          tokenLocation == OidcUserInfoAccessTokenLocations.formParameter
          ? {
              OidcConstants_AuthParameters.accessToken: accessToken,
            }
          : null,
    );

    var req = buildRequest();
    var resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    // RFC 9449 §9: a resource server may reject the first DPoP request with a
    // `use_dpop_nonce` challenge — a 401 carrying a `DPoP-Nonce` header and a
    // `WWW-Authenticate: DPoP ... error="use_dpop_nonce"`. Cache the nonce and
    // retry exactly once with it baked into the proof. (Unlike the token
    // endpoint, the RS error lives in WWW-Authenticate, not a JSON body.)
    if (dpopManager != null && resp.statusCode == 401) {
      final nonce = resp.headers[oidcDPoPNonceHeaderName.toLowerCase()];
      final wwwAuthenticate =
          resp.headers['www-authenticate']?.toLowerCase() ?? '';
      if (nonce != null && wwwAuthenticate.contains(oidcDPoPUseNonceError)) {
        dpopManager.setNonceFor(userInfoEndpoint, nonce);
        req = buildRequest();
        resp = await OidcInternalUtilities.sendWithClient(
          client: client,
          request: req,
        );
      }
    }
    const applicationJson = 'application/json';
    const applicationJwt = 'application/jwt';

    // `package:http` lowercases all response header keys, so this lookup MUST
    // use the lowercase key. A capitalized 'Content-Type' never matched, which
    // caused every `application/jwt` UserInfo response to be misparsed as JSON.
    final contentTypeRaw = resp.headers['content-type'] ?? applicationJson;
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
    final availableSources =
        (Map.fromEntries(
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
          parsedJwt.claims.toJson().entries.where(
            (element) => claimNames.containsKey(element.key),
          ),
        );
      } else if (sourceDesc is OidcDistributedClaimSource) {
        var accessToken = sourceDesc.accessToken;
        accessToken ??= await getAccessTokenFor?.call(
          sourceKey,
          sourceDesc.endpoint,
        );

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
          } on Object {
            parsedJwt = null;
          }
          if (parsedJwt != null) {
            targetMap.addEntries(
              parsedJwt.claims.toJson().entries.where(
                (element) => claimNames.containsKey(element.key),
              ),
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
    final resolved = credentials?.resolveForRequest(
      deviceAuthorizationEndpoint,
    );
    final authHeader = resolved?.getAuthorizationHeader();
    final authBodyParams = resolved?.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: deviceAuthorizationEndpoint,
      headers: {
        _authorizationHeaderKey: ?authHeader,
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

  /// Sends a Pushed Authorization Request (PAR).
  ///
  /// this adapts: [rfc9126](https://datatracker.ietf.org/doc/html/rfc9126)
  ///
  /// The [request] is the same [OidcAuthorizeRequest] that would otherwise be
  /// sent to the authorization endpoint; PAR POSTs it (authenticated) to the
  /// [pushedAuthorizationRequestEndpoint] and returns a single-use
  /// `request_uri` to send to the authorization endpoint instead of the raw
  /// parameters.
  ///
  /// if [credentials] is set to null, it's up to the caller how to authenticate
  /// the request; either via [headers] or [extraBodyFields].
  static Future<OidcPushedAuthorizationResponse> pushAuthorizationRequest({
    required Uri pushedAuthorizationRequestEndpoint,
    required OidcAuthorizeRequest request,
    OidcClientAuthentication? credentials,
    Map<String, String>? headers,
    Map<String, dynamic>? extraBodyFields,
    http.Client? client,
  }) async {
    final resolved = credentials?.resolveForRequest(
      pushedAuthorizationRequestEndpoint,
    );
    final authHeader = resolved?.getAuthorizationHeader();
    final authBodyParams = resolved?.getBodyParameters();
    final bodyFields =
        <String, dynamic>{
            ...request.toMap(),
            if (authHeader == null) ...?authBodyParams,
            ...?extraBodyFields,
          }
          // RFC 9126 §2.1: the `request_uri` parameter MUST NOT be provided to the
          // PAR endpoint — strip it defensively in case a caller supplied one via
          // `extra` parameters / extraBodyFields.
          ..remove(OidcConstants_AuthParameters.requestUri);
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: pushedAuthorizationRequestEndpoint,
      headers: {
        _authorizationHeaderKey: ?authHeader,
        ...?headers,
      },
      contentType: _formUrlEncoded,
      bodyFields: bodyFields,
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcPushedAuthorizationResponse.fromJson,
      response: resp,
      request: req,
    );
  }

  /// Sends a token revocation request.
  static Future<OidcRevocationResponse> revokeToken({
    required Uri revocationEndpoint,
    required OidcRevocationRequest request,
    http.Client? client,
    OidcClientAuthentication? credentials,
    Map<String, String>? headers,
    Map<String, dynamic>? extraBodyFields,
  }) async {
    final resolved = credentials?.resolveForRequest(revocationEndpoint);
    final authHeader = resolved?.getAuthorizationHeader();
    final authBodyParams = resolved?.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: revocationEndpoint,
      contentType: _formUrlEncoded,
      headers: {
        _authorizationHeaderKey: ?authHeader,
        ...?headers,
      },
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
      mapper: OidcRevocationResponse.fromJson,
      request: req,
      response: resp,
    );
  }

  /// Introspects a token (RFC 7662) at the [introspectionEndpoint] and returns
  /// the token's metadata — notably whether it is `active`.
  ///
  /// The request is authenticated with the client's [credentials] (the same
  /// resolution used by [token]/[revokeToken]); introspection is a privileged
  /// endpoint, so a client without credentials must supply authentication via
  /// [headers] or [extraBodyFields].
  static Future<OidcIntrospectionResponse> introspect({
    required Uri introspectionEndpoint,
    required OidcIntrospectionRequest request,
    http.Client? client,
    OidcClientAuthentication? credentials,
    Map<String, String>? headers,
    Map<String, dynamic>? extraBodyFields,
  }) async {
    final resolved = credentials?.resolveForRequest(introspectionEndpoint);
    final authHeader = resolved?.getAuthorizationHeader();
    final authBodyParams = resolved?.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: introspectionEndpoint,
      contentType: _formUrlEncoded,
      headers: {
        _authorizationHeaderKey: ?authHeader,
        ...?headers,
      },
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
      mapper: OidcIntrospectionResponse.fromJson,
      request: req,
      response: resp,
    );
  }

  /// Builds a request with an optional JSON body (used by the dynamic client
  /// registration / management endpoints, which exchange `application/json`).
  static http.Request _prepareJsonRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? jsonBody,
    Map<String, String>? headers,
  }) {
    final req = http.Request(method, uri);
    req.headers['Accept'] = 'application/json';
    if (headers != null) {
      req.headers.addAll(headers);
    }
    if (jsonBody != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(jsonBody);
    }
    return req;
  }

  /// Dynamically registers a client (RFC 7591) at [registrationEndpoint],
  /// returning the issued client_id (+ optional client_secret and the RFC 7592
  /// registration_access_token / registration_client_uri).
  ///
  /// When the authorization server requires an initial access token for
  /// registration, pass [initialAccessToken] (sent as a Bearer token).
  static Future<OidcClientRegistrationResponse> registerClient({
    required Uri registrationEndpoint,
    required OidcClientRegistrationRequest request,
    String? initialAccessToken,
    http.Client? client,
    Map<String, String>? headers,
  }) async {
    final req = _prepareJsonRequest(
      method: OidcConstants_RequestMethod.post,
      uri: registrationEndpoint,
      jsonBody: request.toMap(),
      headers: {
        if (initialAccessToken != null)
          _authorizationHeaderKey: 'Bearer $initialAccessToken',
        ...?headers,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcClientRegistrationResponse.fromJson,
      request: req,
      response: resp,
    );
  }

  /// Reads a client's current configuration (RFC 7592 §2.1) from its
  /// [registrationClientUri], authenticated with the [registrationAccessToken].
  static Future<OidcClientRegistrationResponse> readClientConfiguration({
    required Uri registrationClientUri,
    required String registrationAccessToken,
    http.Client? client,
    Map<String, String>? headers,
  }) async {
    final req = _prepareJsonRequest(
      method: OidcConstants_RequestMethod.get,
      uri: registrationClientUri,
      headers: {
        _authorizationHeaderKey: 'Bearer $registrationAccessToken',
        ...?headers,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcClientRegistrationResponse.fromJson,
      request: req,
      response: resp,
    );
  }

  /// Updates a client's configuration (RFC 7592 §2.2) at its
  /// [registrationClientUri], authenticated with the [registrationAccessToken].
  static Future<OidcClientRegistrationResponse> updateClientConfiguration({
    required Uri registrationClientUri,
    required String registrationAccessToken,
    required OidcClientRegistrationRequest request,
    http.Client? client,
    Map<String, String>? headers,
  }) async {
    final req = _prepareJsonRequest(
      method: OidcConstants_RequestMethod.put,
      uri: registrationClientUri,
      jsonBody: request.toMap(),
      headers: {
        _authorizationHeaderKey: 'Bearer $registrationAccessToken',
        ...?headers,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcClientRegistrationResponse.fromJson,
      request: req,
      response: resp,
    );
  }

  /// Deletes (deprovisions) a client (RFC 7592 §2.3) at its
  /// [registrationClientUri]. A successful deletion returns HTTP 204.
  static Future<void> deleteClientConfiguration({
    required Uri registrationClientUri,
    required String registrationAccessToken,
    http.Client? client,
    Map<String, String>? headers,
  }) async {
    final req = _prepareJsonRequest(
      method: OidcConstants_RequestMethod.delete,
      uri: registrationClientUri,
      headers: {
        _authorizationHeaderKey: 'Bearer $registrationAccessToken',
        ...?headers,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    if (!(resp.statusCode >= 200 && resp.statusCode < 400)) {
      throw OidcException(
        'Failed to delete client configuration '
        '(status ${resp.statusCode}): ${req.url}',
        rawRequest: req,
        rawResponse: resp,
      );
    }
  }
}
