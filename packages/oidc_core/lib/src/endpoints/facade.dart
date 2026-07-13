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
  ///
  /// [dpopJkt] is the RFC 7638 thumbprint of the DPoP proof key. When non-null
  /// it is emitted as the `dpop_jkt` authorization-request parameter (RFC 9449
  /// §10) to bind the authorization code to the DPoP key; pass it only for the
  /// direct (non-PAR) path, since the PAR path binds via the pushed request
  /// body instead.
  static Future<OidcSimpleAuthorizationRequestContainer>
  prepareAuthorizationCodeFlowRequest({
    required OidcProviderMetadata metadata,
    required OidcSimpleAuthorizationCodeFlowRequest input,
    OidcStore? store,
    String? dpopJkt,
  }) async {
    // OAuth 2.1 / RFC 9700 (Security BCP): ALWAYS use PKCE, defaulting to S256,
    // even when the OP's metadata omits `code_challenge_methods_supported` — a
    // server MUST ignore parameters it does not understand, so sending PKCE is
    // always safe, and silently dropping it is a downgrade. Only fall back to
    // `plain` when the OP advertises `plain` but NOT `S256`; never send no PKCE.
    final supportedCodeChallengeMethods =
        metadata.codeChallengeMethodsSupported ?? const <String>[];
    final codeVerifier = OidcPkcePair.generateVerifier();
    final String codeChallenge;
    final String codeChallengeMethod;
    if (!supportedCodeChallengeMethods.contains(
          OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256,
        ) &&
        supportedCodeChallengeMethods.contains(
          OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain,
        )) {
      // The OP explicitly supports `plain` but not `S256`.
      codeChallenge = OidcPkcePair.generatePlainChallenge(codeVerifier);
      codeChallengeMethod =
          OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain;
    } else {
      // Default: S256 (advertised, or metadata silent — the recommended path).
      codeChallenge = OidcPkcePair.generateS256Challenge(codeVerifier);
      codeChallengeMethod =
          OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256;
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
      // RFC 9449 §10: set before the JAR request object is built below so the
      // binding is also carried inside a signed request object (RFC 9101) when
      // one is used. Null (DPoP off / PAR path) omits it entirely.
      dpopJkt: dpopJkt,
    );

    final requestObjectSettings = input.requestObjectSettings;
    if (requestObjectSettings != null) {
      // JAR (RFC 9101): sign the authorization parameters into a `request`
      // object. `iss` is the client_id and `aud` the authorization server
      // (its issuer, falling back to the authorization endpoint).
      final audience = (metadata.issuer ?? metadata.authorizationEndpoint)
          ?.toString();
      if (audience == null) {
        throw const OidcException(
          'Cannot build a JAR request object: the provider metadata has no '
          '`issuer` or `authorization_endpoint` to use as the `aud`.',
        );
      }
      req.request = oidcCreateRequestObject(
        parameters: req.toMap(),
        key: requestObjectSettings.signingKey,
        algorithm: requestObjectSettings.algorithm,
        issuer: input.clientId,
        audience: audience,
        lifetime: requestObjectSettings.lifetime,
        clockSkew: requestObjectSettings.clockSkew,
      );
    }

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

  /// Verifies the RFC 8414 §2.1 `signed_metadata` JWT (if present) carried by a
  /// discovery document and merges its verified claims over the plain JSON
  /// members (RFC 8414 §3.2: signed metadata takes precedence).
  ///
  /// When [metadata] carries no `signed_metadata` member, the input is returned
  /// unchanged (no network, no crypto). Otherwise:
  ///
  /// - verification keys are bootstrapped from the plain `jwks_uri` (trusted
  ///   because it arrived over TLS from the well-known endpoint); a missing
  ///   `jwks_uri` makes the signed metadata unverifiable and throws;
  /// - `none` is ALWAYS stripped from [allowedAlgorithms] (`jose_plus` only
  ///   auto-rejects `none` when the allow-list is null — same hazard handled in
  ///   [_decodeJarmResponse]/[validateLogoutToken]);
  /// - the JWT MUST contain an `iss` claim (RFC 8414 §2.1) and, when an
  ///   [expectedIssuer] is known, `iss` MUST be identical to it (mix-up
  ///   defense);
  /// - a present-and-expired `exp` is rejected, but `exp` is NOT required
  ///   (RFC 8414 does not mandate it);
  /// - on success the merged [OidcProviderMetadata] is returned (the caller
  ///   then issuer-validates + persists it).
  ///
  /// Throws [OidcException] on ANY failure so the caller can apply its
  /// strict/warn policy.
  static Future<OidcProviderMetadata> verifyAndMergeSignedMetadata({
    required OidcProviderMetadata metadata,
    required Uri? expectedIssuer,
    List<String>? allowedAlgorithms,
    OidcStore? cacheStore,
    http.Client? client,
    Duration jwksCacheMaxAge = const Duration(days: 1),
  }) async {
    final signedMetadata =
        metadata.src[OidcConstants_ProviderMetadata.signedMetadata];
    if (signedMetadata is! String) {
      // No signed_metadata member: use the plain JSON unchanged.
      return metadata;
    }

    // Bootstrap verification keys from the plain (TLS-trusted) jwks_uri.
    final jwksUri = metadata.jwksUri;
    if (jwksUri == null) {
      throw const OidcException(
        'Discovery document carries a `signed_metadata` JWT but no `jwks_uri` '
        'to bootstrap its verification keys (RFC 8414 §2.1); cannot verify.',
      );
    }
    final keyStore = JsonWebKeyStore()..addKeySetUrl(jwksUri);

    // signed_metadata MUST be signed; strip `none` explicitly.
    final algs = allowedAlgorithms
        ?.where((a) => a.toLowerCase() != 'none')
        .toList();

    final JsonWebToken jwt;
    try {
      jwt = await JsonWebKeySetLoader.runZoned(
        () => JsonWebToken.decodeAndVerify(
          signedMetadata,
          keyStore,
          allowedArguments: algs,
        ),
        loader: cacheStore == null
            ? (client == null
                  ? null
                  : DefaultJsonWebKeySetLoader(httpClient: client))
            : OidcJwksStoreLoader(
                store: cacheStore,
                httpClient: client,
                staleCacheMaxAge: jwksCacheMaxAge,
              ),
      );
    } on OidcException {
      rethrow;
    } catch (e, st) {
      throw OidcException(
        'Failed to verify the discovery `signed_metadata` JWT signature.',
        internalException: e,
        internalStackTrace: st,
      );
    }

    final claims = jwt.claims;

    // RFC 8414 §2.1: the JWT MUST contain an `iss` claim.
    final iss = claims.issuer;
    if (iss == null) {
      throw const OidcException(
        'Discovery `signed_metadata` JWT is missing the required `iss` claim '
        '(RFC 8414 §2.1).',
      );
    }
    // Mix-up defense: cross-check `iss` against the expected/document issuer
    // when one can be derived (skip only when no expected issuer is known).
    if (expectedIssuer != null &&
        !OidcUtils.issuersAreIdentical(expectedIssuer, iss)) {
      throw OidcException(
        'Discovery `signed_metadata` JWT `iss` ($iss) does not match the '
        'expected issuer ($expectedIssuer); possible mix-up attack '
        '(RFC 8414 §2.1).',
      );
    }

    // RFC 8414 does not require `exp`, but a present-and-expired one is invalid.
    final exp = claims.expiry;
    if (exp != null && clock.now().isAfter(exp)) {
      throw const OidcException(
        'Discovery `signed_metadata` JWT has expired.',
      );
    }

    // RFC 8414 §3.2: signed claims OVERRIDE the corresponding plain JSON.
    final merged = {...metadata.src}..addAll(claims.toJson());
    return OidcProviderMetadata.fromJson(merged);
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

      // A JARM response carries everything inside a single `response` JWT, so
      // the plain `state` key is absent from the URL — treat `response` (and
      // `error`) as resolution keys too.
      bool hasResolutionKey(Map<String, String> params) =>
          params.containsKey(key) ||
          params.containsKey(OidcConstants_AuthParameters.error) ||
          params.containsKey(OidcConstants_AuthParameters.response);

      if (hasResolutionKey(responseUri.queryParameters)) {
        parameters = responseUri.queryParameters;
        resolvedResponseMode =
            OidcConstants_AuthorizeRequest_ResponseMode.query;
      } else {
        final fragmentUri = Uri(query: responseUri.fragment);
        if (hasResolutionKey(fragmentUri.queryParameters)) {
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
    JsonWebKeyStore? keyStore,
    List<String>? allowedAlgorithms,
    String? expectedAudience,
    Uri? expectedIssuer,
    bool requireIss = false,
  }) async {
    final (
      :parameters,
      responseMode: resolvedResponseMode,
    ) = resolveAuthorizeResponseParameters(
      responseUri: responseUri,
      resolveResponseModeByKey: resolveResponseModeByKey,
      responseMode: responseMode,
    );

    // JARM (JWT Secured Authorization Response Mode): when the response is
    // delivered as a signed `response` JWT, verify it and use its claims as the
    // authorization-response parameters (the inner `iss`/`state`/`code`/`error`
    // then flow through the normal checks).
    final jarm = parameters[OidcConstants_AuthParameters.response];
    final responseParameters = jarm is String
        ? await _decodeJarmResponse(
            responseJwt: jarm,
            keyStore: keyStore,
            expectedAudience: expectedAudience,
            allowedAlgorithms: allowedAlgorithms,
          )
        : parameters;

    final p = {
      ...responseParameters,
      OidcConstants_AuthParameters.responseMode: resolvedResponseMode,
      ...?overrides,
    };
    // RFC 9207 §2.4: validate `iss` BEFORE surfacing a server error, so the
    // mix-up defense also applies to error redirects (which would otherwise
    // throw `serverError` below before any issuer check). When the AS advertises
    // iss support, a missing `iss` is rejected; a present `iss` must match the
    // provider issuer (string compare, not Uri normalization).
    final issStr = p[OidcConstants_AuthParameters.iss] as String?;
    final iss = issStr == null ? null : Uri.tryParse(issStr);
    if (requireIss && iss == null) {
      throw const OidcException(
        'Authorization response is missing the `iss` parameter from an AS that '
        'advertises authorization_response_iss_parameter_supported '
        '(RFC 9207 §2.4); refusing as a possible mix-up attack.',
      );
    }
    if (iss != null &&
        expectedIssuer != null &&
        iss.toString() != expectedIssuer.toString()) {
      throw OidcException(
        'Authorization response `iss` ($iss) does not match the provider '
        'issuer ($expectedIssuer); possible mix-up attack (RFC 9207).',
      );
    }
    if (p.containsKey(OidcConstants_AuthParameters.error)) {
      throw OidcException.serverError(
        errorResponse: OidcErrorResponse.fromJson(p),
      );
    }
    return OidcAuthorizeResponse.fromJson(p);
  }

  /// Verifies a JARM `response` JWT and returns its claims (the authorization
  /// response parameters). When [keyStore] is null the JWT is parsed
  /// unverified; callers that need the JARM signature guarantee MUST pass the
  /// provider's [keyStore].
  static Future<Map<String, dynamic>> _decodeJarmResponse({
    required String responseJwt,
    required JsonWebKeyStore? keyStore,
    required String? expectedAudience,
    List<String>? allowedAlgorithms,
  }) async {
    // A JARM response is security-critical (it carries code/state/iss); never
    // trust it unverified.
    if (keyStore == null) {
      throw const OidcException(
        'A JARM `response` JWT was returned but no key store was available to '
        'verify its signature; refusing to trust it unverified.',
      );
    }
    // JARM MUST NOT be unsigned. jose_plus only auto-rejects `alg:none` when the
    // allowed-algorithm list is null, so strip it explicitly (an OP MAY list
    // `none` in id_token_signing_alg_values_supported, which would otherwise
    // open an unsigned-response forgery path).
    final algs = allowedAlgorithms
        ?.where((a) => a.toLowerCase() != 'none')
        .toList();
    final jwt = await JsonWebToken.decodeAndVerify(
      responseJwt,
      keyStore,
      allowedArguments: algs,
    );
    final claims = jwt.claims;
    // JARM mandates `iss`, `aud`, and `exp`; reject if any is missing/invalid
    // (the inner `iss` is additionally cross-checked against the issuer by the
    // RFC 9207 mix-up defense downstream).
    final exp = claims.expiry;
    if (exp == null) {
      throw const OidcException(
        'JARM `response` JWT is missing the required `exp` claim.',
      );
    }
    if (clock.now().isAfter(exp)) {
      throw const OidcException('JARM `response` JWT has expired.');
    }
    if (claims.issuer == null) {
      throw const OidcException(
        'JARM `response` JWT is missing the required `iss` claim.',
      );
    }
    final aud = claims.audience;
    if (expectedAudience != null &&
        (aud == null || !aud.contains(expectedAudience))) {
      throw OidcException(
        'JARM `response` JWT `aud` ($aud) does not contain the client_id '
        '($expectedAudience).',
      );
    }
    return claims.toJson();
  }

  /// Validates an encoded `logout_token` string per OpenID Connect Back-Channel
  /// Logout 1.0 §2.6.
  ///
  /// This is a pure-Dart, no-HTTP helper for **backend** Relying Parties: a
  /// `dart:io`/`shelf` server calls it from its `backchannel_logout_uri`
  /// handler and, on success, signals the client out-of-band. It does NOT host
  /// an endpoint and does NOT mutate session state. A browser SPA or native app
  /// cannot host a server-reachable `backchannel_logout_uri`, so this is not
  /// usable from the client packages — for client-side logout detection use the
  /// Session Management / front-channel logout support instead.
  ///
  /// On success the verified [JsonWebToken] is returned so the caller can read
  /// `sub`/`sid` to target the right session. On ANY validation failure an
  /// [OidcException] is thrown (the caller maps it to HTTP 400 per §2.6).
  ///
  /// Pass the OP's `id_token_signing_alg_values_supported` as
  /// [allowedAlgorithms]; `none` is always stripped before verification (§2.6
  /// step 3). When [cacheStore] is supplied, JWKS are fetched + cached via
  /// `OidcJwksStoreLoader` exactly like id_token verification.
  ///
  /// [maxAge], when set, additionally rejects a token whose `iat` is older than
  /// `maxAge + expiryTolerance` (defense-in-depth; the spec validates `iat`
  /// presence only). [seenJtis], when supplied, is a caller-owned replay guard
  /// for the OPTIONAL §2.6 step 8 (the caller owns its persistence/TTL).
  ///
  /// Out of scope for this helper (left to the caller): §2.6 step 1 JWE
  /// decryption (only works if the RP private key is already in [keyStore]) and
  /// steps 9-11 (cross-checking iss/sub/sid against a stored prior ID Token,
  /// which require RP session storage the core package does not own).
  static Future<JsonWebToken> validateLogoutToken({
    required String logoutToken,
    required JsonWebKeyStore keyStore,
    required Uri issuer,
    required String clientId,
    List<String>? allowedAlgorithms,
    OidcStore? cacheStore,
    Duration expiryTolerance = const Duration(minutes: 1),
    Duration? maxAge,
    Set<String>? seenJtis,
    Duration jwksCacheMaxAge = const Duration(days: 1),
  }) async {
    // 1. alg/none strip (§2.6 step 3): jose_plus only auto-rejects `none` when
    // the allow-list is null, so a supplied list containing `none` must have it
    // removed before verification.
    final algs = allowedAlgorithms
        ?.where((a) => a.toLowerCase() != 'none')
        .toList();

    // 2. signature verify (§2.6 steps 2-3). NEVER fall back to
    // `JsonWebToken.unverified`: a logout_token must never be accepted
    // unverified. A bad signature / unsigned token / disallowed alg throws.
    final JsonWebToken jwt;
    try {
      jwt = await JsonWebKeySetLoader.runZoned(
        () => JsonWebToken.decodeAndVerify(
          logoutToken,
          keyStore,
          allowedArguments: algs,
        ),
        loader: cacheStore == null
            ? null
            : OidcJwksStoreLoader(
                store: cacheStore,
                staleCacheMaxAge: jwksCacheMaxAge,
              ),
      );
    } on OidcException {
      rethrow;
    } catch (e, st) {
      throw OidcException(
        'Failed to verify the logout_token signature.',
        internalException: e,
        internalStackTrace: st,
      );
    }
    final claims = jwt.claims;

    // 3. exp present guard (§2.4 lists exp as REQUIRED). MUST precede
    // `claims.validate()`, which dereferences `expiry!`.
    if (claims.expiry == null) {
      throw const OidcException(
        'logout_token is missing the required `exp` claim.',
      );
    }

    // 4. iss/aud/exp (§2.6 step 4).
    final errs = claims
        .validate(
          expiryTolerance: expiryTolerance,
          issuer: issuer,
          clientId: clientId,
        )
        .toList();
    if (errs.isNotEmpty) {
      throw OidcException(
        'logout_token failed iss/aud/exp validation: ${errs.first}',
      );
    }

    // 5. iat (§2.6 step 4; not covered by validate()).
    final iat = claims.issuedAt;
    if (iat == null) {
      throw const OidcException(
        'logout_token is missing the required `iat` claim.',
      );
    }
    if (maxAge != null &&
        clock.now().difference(iat) > maxAge + expiryTolerance) {
      throw const OidcException(
        'logout_token is older than the allowed maxAge.',
      );
    }

    // 6. sub and/or sid (§2.6 step 5).
    if (claims.subject == null && claims.sid == null) {
      throw const OidcException(
        'logout_token must contain a `sub` and/or `sid` claim.',
      );
    }

    // 7. events member (§2.6 step 6). The member value MAY be an empty `{}`, so
    // require it be a Map — do NOT require it be non-empty.
    final json = claims.toJson();
    final events = json[OidcConstants_JWTClaims.events];
    if (events is! Map ||
        events[OidcConstants_JWTClaims.backchannelLogoutEvent] is! Map) {
      throw const OidcException(
        'logout_token is missing the required backchannel-logout `events` '
        'member.',
      );
    }

    // 8. nonce prohibited (§2.6 step 7). Reject on PRESENCE (containsKey), not
    // on a non-null value — a present-but-null nonce is still a violation.
    if (json.containsKey(OidcConstants_AuthParameters.nonce)) {
      throw const OidcException(
        'logout_token must not contain a `nonce` claim.',
      );
    }

    // 9. jti replay (§2.6 step 8, OPTIONAL).
    final jti = claims.jwtId;
    if (seenJtis != null && jti != null && !seenJtis.add(jti)) {
      throw OidcException(
        'logout_token `jti` ($jti) has already been seen (replay).',
      );
    }

    // 10. success.
    return jwt;
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
    Uri? expectedIssuer,
    String? clientId,
    bool validateSignedResponseClaims = true,
    bool requireSignedResponseIssAud = false,
    Duration claimsExpiryTolerance = const Duration(minutes: 1),
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
        // Strip `alg:none` before verifying a signed UserInfo JWT: `jose_plus`
        // only auto-rejects `none` when the allowed-algorithm list is null, so
        // an OP advertising `none` in `userinfo_signing_alg_values_supported`
        // would otherwise open an unsigned-UserInfo forgery path. (Mirrors the
        // id_token and JARM `alg:none` strips.)
        final algs = allowedAlgorithms
            ?.where((a) => a.toLowerCase() != 'none')
            .toList();
        jwt = await JsonWebToken.decodeAndVerify(
          resp.body,
          keyStore,
          allowedArguments: algs,
        );
      } else {
        // No keyStore => we cannot verify a signed UserInfo response.
        // OIDC Core 5.3.2: a signed UserInfo Response MUST have its signature
        // validated. Always refuse to silently trust it — mirroring id_token
        // handling, there is no unverified-fallback opt-out.
        throw const OidcException(
          'UserInfo returned a signed (application/jwt) response but no '
          'keyStore was provided to verify its signature; refusing to trust '
          'an unverified UserInfo JWT. Provide a keyStore.',
        );
      }
      ret = OidcUserInfoResponse.fromJson(jwt.claims.toJson());
      // OIDC Core 5.3.2/5.3.4: when the UserInfo response is a signed JWT that
      // we VERIFIED against the keyStore, validate its iss/aud/exp. Reaching
      // here always means `keyStore != null` — the `else` branch above always
      // throws, so the unverified path never gains false assurance.
      //
      // We deliberately do NOT call `jwt.claims.validate(...)`: that force-
      // unwraps `exp` (crashing when a UserInfo JWT omits it, which is common)
      // and treats an absent `iss` as a mismatch. UserInfo `iss`/`aud`/`exp`
      // are validate-when-present (SHOULD), so use custom logic on the parsed
      // model fields.
      if (validateSignedResponseClaims) {
        final iss = ret.iss;
        if (iss != null) {
          // Simple-string compare (consistent with the repo's RFC 9207 `iss`
          // handling), NOT `Uri==`.
          if (expectedIssuer != null && iss != expectedIssuer.toString()) {
            throw OidcException(
              'Signed UserInfo `iss` ($iss) does not match the provider issuer '
              '($expectedIssuer) — OIDC Core 5.3.4.',
            );
          }
        } else if (requireSignedResponseIssAud) {
          throw const OidcException(
            'Signed UserInfo response is missing the required `iss` claim.',
          );
        }

        final aud = ret.aud;
        if (aud.isNotEmpty) {
          if (clientId != null && !aud.contains(clientId)) {
            throw OidcException(
              'Signed UserInfo `aud` ($aud) does not contain the client_id '
              '($clientId) — OIDC Core 5.3.2.',
            );
          }
        } else if (requireSignedResponseIssAud) {
          throw const OidcException(
            'Signed UserInfo response is missing the required `aud` claim.',
          );
        }

        final exp = ret.exp;
        if (exp != null &&
            clock.now().difference(exp) > claimsExpiryTolerance) {
          throw OidcException(
            'Signed UserInfo JWT expired at $exp (tolerance '
            '$claimsExpiryTolerance) — RFC 7519 4.1.4.',
          );
        }
      }
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
