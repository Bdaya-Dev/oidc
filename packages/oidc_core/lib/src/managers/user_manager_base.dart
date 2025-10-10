import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:rxdart/rxdart.dart';

final _logger = Logger('OidcUserManagerBase');

/// This class manages a single user's authentication status.
///
/// It's preferred to maintain only a single instance of this class.
abstract class OidcUserManagerBase {
  /// Create a new UserManager from [OidcProviderMetadata].
  ///
  /// if [discoveryDocument] is not available,
  /// consider using the [OidcUserManagerBase.lazy] constructor.
  OidcUserManagerBase({
    required OidcProviderMetadata discoveryDocument,
    required this.clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
    this.id,
  }) : discoveryDocumentUri = null,
       currentDiscoveryDocument = discoveryDocument,
       _keyStore = keyStore;

  /// Create a new UserManager that delays getting the discovery document until
  /// [init] is called.
  OidcUserManagerBase.lazy({
    required Uri this.discoveryDocumentUri,
    required this.clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
    this.id,
  }) : _keyStore = keyStore;

  bool get isWeb;

  final String? id;

  /// The client authentication information.
  final OidcClientAuthentication clientCredentials;

  /// The http client to use when sending requests
  final http.Client? httpClient;

  /// The store responsible for setting/getting cached values.
  final OidcStore store;

  /// The id_token verification options.
  JsonWebKeyStore? _keyStore;
  JsonWebKeyStore get keyStore => _keyStore ??= JsonWebKeyStore();

  /// The settings used in this manager.
  final OidcUserManagerSettings settings;

  @protected
  final userSubject = BehaviorSubject<OidcUser?>.seeded(null);

  @protected
  final eventsController = StreamController<OidcEvent>.broadcast();

  @protected
  Logger get logger => _logger;

  /// Gets a stream that reflects the current data of the user.
  Stream<OidcUser?> userChanges() => userSubject.stream;

  /// Gets a stream of events related to the current manager.
  Stream<OidcEvent> events() => eventsController.stream;

  /// The current authenticated user.
  OidcUser? get currentUser => userSubject.valueOrNull;

  @protected
  Never logAndThrow(
    String message, {
    Map<String, dynamic> extra = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final ex = OidcException(
      message,
      extra: extra,
      internalException: error,
      internalStackTrace: stackTrace,
    );
    logger.severe(message, error ?? ex, stackTrace ?? StackTrace.current);
    throw ex;
  }

  @protected
  void ensureInit() {
    if (!didInit) {
      logAndThrow(
        "discoveryDocument hasn't been fetched yet, "
        'please call init() first.',
      );
    }
  }

  @protected
  Map<String, dynamic> getSerializableOptions(
    OidcPlatformSpecificOptions options,
  ) => {
    if (isWeb) 'webLaunchMode': options.web.navigationMode.name,
  };

  /// Returns the authorization response.
  /// may throw an [OidcException].
  @protected
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  );

  /// Returns the end session response for an RP initiated logout request.
  /// may throw an [OidcException].
  @protected
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  );

  @protected
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  );

  /// Listens to incoming front channel logout requests.
  /// returns an empty stream on non-supported platforms.
  @protected
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  );

  /// starts monitoring the session status.
  @protected
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  });

  @protected
  OidcPlatformSpecificOptions getPlatformOptions([
    OidcPlatformSpecificOptions? optionsOverride,
  ]) {
    return optionsOverride ??
        settings.options ??
        const OidcPlatformSpecificOptions();
  }

  /// Attempts to login the user via the AuthorizationCodeFlow.
  ///
  /// [originalUri] is the uri you want to be redirected to after authentication is done,
  /// if null, it defaults to `redirectUri`.
  Future<OidcUser?> loginAuthorizationCodeFlow({
    OidcProviderMetadata? discoveryDocumentOverride,
    Uri? redirectUriOverride,
    Uri? originalUri,
    List<String>? scopeOverride,
    List<String>? promptOverride,
    List<String>? uiLocalesOverride,
    String? displayOverride,
    List<String>? acrValuesOverride,
    dynamic extraStateData,
    bool includeIdTokenHintFromCurrentUser = true,
    String? idTokenHintOverride,
    String? loginHint,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
    Map<String, dynamic>? extraTokenParameters,
    Map<String, String>? extraTokenHeaders,
    OidcPlatformSpecificOptions? options,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);
    final simpleReq = OidcSimpleAuthorizationCodeFlowRequest(
      clientId: clientCredentials.clientId,
      originalUri: originalUri,
      redirectUri: redirectUriOverride ?? settings.redirectUri,
      scope: scopeOverride ?? settings.scope,
      prompt: promptOverride ?? settings.prompt,
      display: displayOverride ?? settings.display,
      extraStateData: extraStateData,
      uiLocales: uiLocalesOverride ?? settings.uiLocales,
      acrValues: acrValuesOverride ?? settings.acrValues,
      idTokenHint:
          idTokenHintOverride ??
          (includeIdTokenHintFromCurrentUser ? currentUser?.idToken : null),
      loginHint: loginHint,
      extraTokenHeaders: {
        ...?settings.extraTokenHeaders,
        ...?extraTokenHeaders,
      },
      extraTokenParameters: {
        ...?settings.extraTokenParameters,
        ...?extraTokenParameters,
      },
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
      options: getSerializableOptions(options),
      managerId: id,
    );
    // this function adds state, state data, nonce to the store
    // the state/state data is only until we get a response (success or fail).
    // the nonce is until the user logs out.
    final requestContainer =
        await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
          input: simpleReq,
          metadata: discoveryDocument,
          store: store,
        );
    return tryGetAuthResponse(
      grantType: OidcConstants_GrantType.authorizationCode,
      request: requestContainer.request,
      options: options,
      metadata: discoveryDocument,
      prep: prep,
    );
  }

  /// Attempts to login the user via resource owner's credentials.
  Future<OidcUser?> loginPassword({
    required String username,
    required String password,
    List<String>? scopeOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
  }) async {
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final tokenResp = await (settings.hooks?.token).execute(
      request: OidcTokenHookRequest(
        metadata: discoveryDocument,
        tokenEndpoint: discoveryDocument.tokenEndpoint!,
        request: OidcTokenRequest.password(
          username: username,
          password: password,
          scope: scopeOverride ?? settings.scope,
          clientId: clientCredentials.clientId,
          extra: {...?settings.extraTokenParameters, ...?extraBodyFields},
        ),
        credentials: clientCredentials,
        headers: settings.extraTokenHeaders,
        client: httpClient,
        options: settings.options,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.token(
          tokenEndpoint: hookRequest.tokenEndpoint,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
          request: hookRequest.request,
          client: hookRequest.client,
        );
      },
    );

    return createUserFromToken(
      token: OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
        sessionState: null,
      ),
      attributes: null,
      userInfo: null,
      nonce: null,
      metadata: discoveryDocument,
    );
  }

  @protected
  Future<OidcUser?> tryGetAuthResponse({
    required OidcAuthorizeRequest request,
    required String grantType,
    required OidcPlatformSpecificOptions options,
    required OidcProviderMetadata metadata,
    required Map<String, dynamic> prep,
  }) async {
    try {
      final response = await (settings.hooks?.authorization).execute(
        defaultExecution: (request) {
          return getAuthorizationResponse(
            request.metadata,
            request.request,
            request.options,
            request.preparationResult,
          );
        },
        request: OidcAuthorizationHookRequest(
          metadata: metadata,
          request: request,
          options: options,
          preparationResult: prep,
        ),
      );
      if (response == null) {
        return null;
      }
      final state = response.state;

      //since we already have a response, remove it from the store.
      if (state != null) {
        await store.setStateResponseData(state: state, stateData: null);
      }
      return await handleSuccessfulAuthResponse(
        response: response,
        grantType: grantType,
        metadata: metadata,
      );
    } on OidcException catch (e) {
      //failed to authorize.
      final response = e.errorResponse;
      if (response == null) {
        rethrow;
      }
      //if we have a response, remove it from the store.
      final state = response.state;
      if (state != null) {
        await store.setStateResponseData(state: state, stateData: null);
      }
      rethrow;
    }
  }

  ///
  @Deprecated('Implicit flow is deprecated due to security reasons.')
  Future<OidcUser?> loginImplicitFlow({
    required List<String> responseType,
    OidcProviderMetadata? discoveryDocumentOverride,
    Uri? redirectUriOverride,
    Uri? originalUri,
    List<String>? scopeOverride,
    List<String>? promptOverride,
    List<String>? uiLocalesOverride,
    String? displayOverride,
    List<String>? acrValuesOverride,
    dynamic extraStateData,
    bool includeIdTokenHintFromCurrentUser = true,
    String? idTokenHintOverride,
    String? loginHint,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
    OidcPlatformSpecificOptions? options,
  }) async {
    ensureInit();
    final doc = discoveryDocumentOverride ?? discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);

    final simpleReq = OidcSimpleImplicitFlowRequest(
      responseType: responseType,
      clientId: clientCredentials.clientId,
      originalUri: originalUri,
      redirectUri: redirectUriOverride ?? settings.redirectUri,
      scope: scopeOverride ?? settings.scope,
      prompt: promptOverride ?? settings.prompt,
      display: displayOverride ?? settings.display,
      extraStateData: extraStateData,
      uiLocales: uiLocalesOverride ?? settings.uiLocales,
      acrValues: acrValuesOverride ?? settings.acrValues,
      idTokenHint:
          idTokenHintOverride ??
          (includeIdTokenHintFromCurrentUser ? currentUser?.idToken : null),
      loginHint: loginHint,
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
      options: getSerializableOptions(options),
    );
    final request = await OidcEndpoints.prepareImplicitFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
    );
    return tryGetAuthResponse(
      request: request,
      grantType: OidcConstants_GrantType.implicit,
      options: options,
      metadata: doc,
      prep: prep,
    );
  }

  /// This simply forgets the current user.
  ///
  /// this adds a new event to [userChanges] with value `null`, and also clears
  /// the store namespaces: state, session, secureTokens.
  ///
  /// NOTE: this is different than [logout], since this method doesn't initiate
  /// any logout flows.
  Future<void> forgetUser() async {
    await cleanUpStore(
      toDelete: {
        OidcStoreNamespace.secureTokens,
      },
    );
    final currentUser = this.currentUser;
    if (currentUser != null) {
      eventsController.add(
        OidcPreLogoutEvent.now(currentUser: currentUser),
      );
      userSubject.add(null);
    }
  }

  /// Revokes the current user's access token.
  ///
  /// This method sends a revocation request to the authorization server's
  /// revocation endpoint to invalidate the access token. The token will no
  /// longer be valid for accessing protected resources.
  ///
  /// **Parameters:**
  /// - [discoveryDocumentOverride]: Optional discovery document to use instead
  ///   of the default one
  /// - [options]: Platform-specific options for the revocation request
  /// - [forgetUser]: Whether to forget the current user after successful
  ///   revocation (defaults to `true`)
  /// - [overrideAccessToken]: Specific access token to revoke instead of the
  ///   current user's token
  /// - [revocationEndpointOverride]: Custom revocation endpoint URL to use
  /// - [extraBodyFields]: Additional fields to include in the revocation request body
  /// - [headers]: Additional HTTP headers to include in the request
  ///
  /// **Behavior:**
  /// - Returns early if no current user exists
  /// - Returns early if no access token is available to revoke
  /// - Returns early if the authorization server doesn't provide a revocation endpoint
  /// - Calls [forgetUser] automatically after successful revocation when [forgetUser] is `true`
  /// - Uses hooks system to allow customization of the revocation process
  ///
  /// **Example:**
  /// ```dart
  /// // Revoke current user's access token
  /// await userManager.revokeAccessToken();
  ///
  /// // Revoke specific token without forgetting user
  /// await userManager.revokeAccessToken(
  ///   overrideAccessToken: 'specific_token',
  ///   forgetUser: false,
  /// );
  /// ```
  Future<void> revokeAccessToken({
    OidcProviderMetadata? discoveryDocumentOverride,
    OidcPlatformSpecificOptions? options,
    bool forgetUser = true,
    String? overrideAccessToken,
    Uri? revocationEndpointOverride,
    Map<String, dynamic>? extraBodyFields,
    Map<String, String>? headers,
  }) async {
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final token = overrideAccessToken ?? currentUser.token.accessToken;
    if (token == null) {
      return; // no access token to revoke.
    }
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final revocationEndpoint =
        revocationEndpointOverride ?? discoveryDocument.revocationEndpoint;
    if (revocationEndpoint == null) {
      return; // no revocation endpoint, nothing to do.
    }

    final resp = await (settings.hooks?.revocation).execute(
      request: OidcRevocationHookRequest(
        metadata: discoveryDocument,
        revocationEndpoint: revocationEndpoint,
        credentials: clientCredentials,
        headers: {
          ...?settings.extraRevocationHeaders,
          ...?headers,
        },
        request: OidcRevocationRequest(
          token: token,
          tokenTypeHint:
              OidcConstants_RevocationParameters_TokenType.accessToken,
          extra: {
            ...?extraBodyFields,
            ...?settings.extraRevocationParameters,
          },
        ),
        options: getPlatformOptions(options),
        client: httpClient,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.revokeToken(
          revocationEndpoint: hookRequest.revocationEndpoint,
          request: hookRequest.request,
          client: hookRequest.client,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
        );
      },
    );
    if (resp != null) {
      if (forgetUser) {
        await this.forgetUser();
      }
      return;
    }
    // revocation failed.
    return;
  }

  /// Revokes the current user's refresh token.
  ///
  /// This method sends a revocation request to the authorization server's
  /// revocation endpoint to invalidate the refresh token. The token will no
  /// longer be valid for obtaining new access tokens.
  ///
  /// **Parameters:**
  /// - [discoveryDocumentOverride]: Optional discovery document to use instead
  ///   of the default one
  /// - [options]: Platform-specific options for the revocation request
  /// - [forgetUser]: Whether to forget the current user after successful
  ///   revocation (defaults to `true`)
  /// - [overrideRefreshToken]: Specific refresh token to revoke instead of the
  ///   current user's token
  /// - [revocationEndpointOverride]: Custom revocation endpoint URL to use
  /// - [extraBodyFields]: Additional fields to include in the revocation request body
  /// - [headers]: Additional HTTP headers to include in the request
  ///
  /// **Behavior:**
  /// - Returns early if no current user exists
  /// - Returns early if no refresh token is available to revoke
  /// - Returns early if the authorization server doesn't provide a revocation endpoint
  /// - Calls [forgetUser] automatically after successful revocation when [forgetUser] is `true`
  /// - Uses hooks system to allow customization of the revocation process
  ///
  /// **Example:**
  /// ```dart
  /// // Revoke current user's refresh token
  /// await userManager.revokeRefreshToken();
  ///
  /// // Revoke specific token with custom headers
  /// await userManager.revokeRefreshToken(
  ///   overrideRefreshToken: 'specific_refresh_token',
  ///   headers: {'Custom-Header': 'value'},
  /// );
  /// ```
  Future<void> revokeRefreshToken({
    OidcProviderMetadata? discoveryDocumentOverride,
    OidcPlatformSpecificOptions? options,
    bool forgetUser = true,
    String? overrideRefreshToken,
    Uri? revocationEndpointOverride,
    Map<String, dynamic>? extraBodyFields,
    Map<String, String>? headers,
  }) async {
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final token = overrideRefreshToken ?? currentUser.token.refreshToken;
    if (token == null) {
      return; // no refresh token to revoke.
    }
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final revocationEndpoint =
        revocationEndpointOverride ?? discoveryDocument.revocationEndpoint;
    if (revocationEndpoint == null) {
      return; // no revocation endpoint, nothing to do.
    }

    final resp = await (settings.hooks?.revocation).execute(
      request: OidcRevocationHookRequest(
        metadata: discoveryDocument,
        revocationEndpoint: revocationEndpoint,
        credentials: clientCredentials,
        headers: {
          ...?settings.extraRevocationHeaders,
          ...?headers,
        },
        request: OidcRevocationRequest(
          token: token,
          tokenTypeHint:
              OidcConstants_RevocationParameters_TokenType.refreshToken,
          extra: {
            ...?extraBodyFields,
            ...?settings.extraRevocationParameters,
          },
        ),
        options: getPlatformOptions(options),
        client: httpClient,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.revokeToken(
          revocationEndpoint: hookRequest.revocationEndpoint,
          request: hookRequest.request,
          client: hookRequest.client,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
        );
      },
    );
    if (resp != null) {
      if (forgetUser) {
        await this.forgetUser();
      }
      return;
    }
    // revocation failed.
    return;
  }

  /// Logs out the current user and calls [forgetUser] if successful.
  Future<void> logout({
    String? logoutHint,
    Map<String, dynamic>? extraParameters,
    OidcPlatformSpecificOptions? options,
    Uri? postLogoutRedirectUriOverride,
    Uri? originalUri,
    dynamic extraStateData,
    List<String>? uiLocalesOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final postLogoutRedirectUri =
        postLogoutRedirectUriOverride ?? settings.postLogoutRedirectUri;

    final stateData = postLogoutRedirectUri == null
        ? null
        : OidcEndSessionState(
            postLogoutRedirectUri: postLogoutRedirectUri,
            originalUri: originalUri,
            options: getSerializableOptions(options),
            data: extraStateData,
          );
    if (stateData != null) {
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
    }
    final resultFuture = getEndSessionResponse(
      discoveryDocument,
      OidcEndSessionRequest(
        clientId: clientCredentials.clientId,
        postLogoutRedirectUri: postLogoutRedirectUri,
        uiLocales: uiLocalesOverride ?? settings.uiLocales,
        idTokenHint: postLogoutRedirectUri == null ? null : currentUser.idToken,
        extra: extraParameters,
        logoutHint: logoutHint,
        state: stateData?.id,
      ),
      options,
      prep,
    );
    if (stateData == null) {
      // they won't come back with a result!
      await forgetUser();

      return;
    }
    final result = await resultFuture;
    if (result == null) {
      if (isWeb &&
          options.web.navigationMode ==
              OidcPlatformSpecificOptions_Web_NavigationMode.samePage) {
        //wait for a result after redirect.
        return;
      }
      await forgetUser();
      return;
    }
    await handleEndSessionResponse(result: result);
  }

  @protected
  Future<void> handleEndSessionResponse({
    required OidcEndSessionResponse result,
  }) async {
    //found result!
    final resState = result.state;
    if (resState == null) {
      await forgetUser();
      return;
    }
    final resStateData = await store.getStateData(resState);
    if (resStateData == null) {
      logAndThrow("Didn't receive correct state value.");
    }
    final parsedState = OidcState.fromStorageString(resStateData);
    if (parsedState.managerId != id) {
      return; // this state is not for this manager.
    }
    await store.setStateData(state: resState, stateData: null);
    if (parsedState is! OidcEndSessionState) {
      logAndThrow('received wrong state type (${parsedState.runtimeType}).');
    }
    //if all state checks are successful, do logout.
    await forgetUser();
  }

  /// You enter this function with an /authorize response.
  ///
  /// this function expects the [store] to still have
  /// - current state
  /// - state data
  /// - nonce
  ///
  /// this function calls [createUserFromToken] after validating the response,
  /// and parsing the state.
  ///
  /// it also clears the store after it's done.
  @protected
  Future<OidcUser?> handleSuccessfulAuthResponse({
    required OidcAuthorizeResponse response,
    required String grantType,
    required OidcProviderMetadata metadata,
  }) async {
    final receivedStateKey = response.state;
    if (receivedStateKey == null) {
      logAndThrow(
        "Server didn't return state parameter, even though it was sent.",
      );
    }

    try {
      final stateDataStr = await store.getStateData(receivedStateKey);
      if (stateDataStr == null) {
        logger.severe(
          "Internal error, the session state wasn't cleared after the state was deleted.",
        );
        //don't throw here, since it's a bug.
        return null;
      }
      final stateData = OidcState.fromStorageString(stateDataStr);
      if (stateData is! OidcAuthorizeState) {
        //impossible case.
        logAndThrow('received wrong state type (${stateData.runtimeType}).');
      }
      if (stateData.managerId != id) {
        return null; // this state is not for this manager.
      }
      if (grantType == OidcConstants_GrantType.implicit) {
        //implicit grant gets the token directly from the response.
        final implicitTokenResponse = OidcTokenResponse.fromJson(response.src);
        if (implicitTokenResponse.accessToken != null ||
            implicitTokenResponse.idToken != null) {
          final token = OidcToken.fromResponse(
            implicitTokenResponse,
            overrideExpiresIn: settings.getExpiresIn?.call(
              implicitTokenResponse,
            ),
            sessionState: response.sessionState,
          );
          return await createUserFromToken(
            token: token,
            userInfo: null,
            attributes: null,
            nonce: stateData.nonce,
            metadata: metadata,
          );
        }
      }

      final tokenEndpoint = metadata.tokenEndpoint;
      if (tokenEndpoint == null) {
        logAndThrow(
          "This provider doesn't provide a token endpoint",
        );
      }
      // an authorization code flow MUST have a code as a response,
      // otherwise an OidcException should have been thrown before entering
      // this function.
      final code = response.code;
      if (code == null) {
        logAndThrow(
          "Server didn't send code even though the authorization code flow was used.",
        );
      }
      //request the token.
      final tokenResp = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: metadata,
          tokenEndpoint: tokenEndpoint,
          credentials: clientCredentials,
          headers: stateData.extraTokenHeaders,
          request: OidcTokenRequest.authorizationCode(
            redirectUri: response.redirectUri ?? stateData.redirectUri,
            codeVerifier: response.codeVerifier ?? stateData.codeVerifier,
            extra: stateData.extraTokenParams,
            clientId: clientCredentials.clientId,
            code: code,
          ),
          client: httpClient,
          options: settings.options,
        ),
        defaultExecution: (hookRequest) {
          return OidcEndpoints.token(
            tokenEndpoint: hookRequest.tokenEndpoint,
            credentials: hookRequest.credentials,
            headers: hookRequest.headers,
            request: hookRequest.request,
            client: hookRequest.client,
          );
        },
      );

      final token = OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
        sessionState: response.sessionState,
      );
      return await createUserFromToken(
        token: token,
        nonce: stateData.nonce,
        attributes: null,
        userInfo: null,
        metadata: metadata,
      );
    } finally {
      //remove the state + state response since we already handled it.
      await store.setStateResponseData(
        state: receivedStateKey,
        stateData: null,
      );
      await store.setStateData(state: receivedStateKey, stateData: null);
    }
  }

  /// Handles a token; either from cache, in which case the [nonce] will be null
  /// , or from an auth response, in which case [nonce] will not be null.
  ///
  /// This function creates an [OidcUser] by validating the token, and then
  /// passing the result to [validateAndSaveUser].
  ///
  /// if the manager already has a [currentUser], this function replaces
  /// its internal token (after validation).
  @protected
  Future<OidcUser?> createUserFromToken({
    required OidcToken token,
    required String? nonce,
    required Map<String, dynamic>? attributes,
    required Map<String, dynamic>? userInfo,
    required OidcProviderMetadata metadata,
    bool validateAndSave = true,
  }) async {
    final currentUser = this.currentUser;
    OidcUser? newUser;
    final idTokenOverride = await settings.getIdToken?.call(token);
    if (currentUser == null) {
      newUser = await OidcUser.fromIdToken(
        token: token,
        allowedAlgorithms: metadata.tokenEndpointAuthSigningAlgValuesSupported,
        keystore: keyStore,
        attributes: attributes,
        strictVerification: settings.strictJwtVerification,
        userInfo: userInfo,
        idTokenOverride: idTokenOverride,
        cacheStore: store,
      );
    } else {
      newUser = await currentUser.replaceToken(
        token,
        idTokenOverride: idTokenOverride,
        strictVerification: settings.strictJwtVerification,
        cacheStore: store,
      );
      if (attributes != null) {
        newUser = newUser.setAttributes(attributes);
      }
      if (userInfo != null) {
        newUser = newUser.withUserInfo(userInfo);
      }
    }

    final idTokenNonce =
        newUser.parsedIdToken.claims[OidcConstants_AuthParameters.nonce]
            as String?;
    if (nonce != null && idTokenNonce != nonce) {
      logAndThrow(
        'Server returned a wrong id_token nonce, might be a replay attack.',
      );
    }
    if (validateAndSave) {
      return validateAndSaveUser(user: newUser, metadata: metadata);
    } else {
      return newUser;
    }
  }

  @protected
  Future<void> saveUser(OidcUser user) async {
    await store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {
        OidcConstants_Store.currentToken: jsonEncode(user.token.toJson()),
        OidcConstants_Store.currentUserInfo: jsonEncode(user.userInfo),
        OidcConstants_Store.currentUserAttributes: jsonEncode(user.attributes),
      },
      managerId: id,
    );
  }

  @protected
  StreamSubscription<OidcMonitorSessionResult>? sessionSub;

  @protected
  void listenToUserSessionIfSupported(OidcUser? user) {
    sessionSub?.cancel();
    sessionSub = null;
    if (user == null) {
      return;
    }
    final checkSessionIframe = discoveryDocument.checkSessionIframe;
    final sessionState = user.token.sessionState;
    if (!settings.sessionManagementSettings.enabled) {
      return;
    }
    if (checkSessionIframe == null || sessionState == null) {
      logger.info(
        "can't "
        'monitor user session due to lack of sessionState ($sessionState) or checkSessionIframe ($checkSessionIframe)',
      );
      return;
    }
    logger.info('started monitoring user session');

    sessionSub ??=
        monitorSessionStatus(
          checkSessionIframe: checkSessionIframe,
          request: OidcMonitorSessionStatusRequest(
            clientId: clientCredentials.clientId,
            sessionState: sessionState,
            interval: settings.sessionManagementSettings.interval,
          ),
        ).listen((event) {
          switch (event) {
            case OidcValidMonitorSessionResult(changed: final changed):
              if (changed) {
                unawaited(sessionSub?.cancel());
                unawaited(reAuthorizeUser());
              }
            case OidcErrorMonitorSessionResult():
              if (settings.sessionManagementSettings.stopIfErrorReceived) {
                unawaited(sessionSub?.cancel());
              }
            case OidcUnknownMonitorSessionResult():
          }
        });
  }

  @protected
  late final tokenEvents = OidcTokenEventsManager(
    getExpiringNotificationTime: settings.refreshBefore,
  );

  /// Refreshes the token manually.
  ///
  /// If token can't be refreshed `null` will be returned.
  ///
  /// Token can be refreshed in the following cases:
  /// 1. grant_types_supported MUST include refresh_token
  /// 2. the [currentUser] MUST NOT be null
  /// 3. the `currentUser.token` MUST include refreshToken
  ///
  /// If any of these conditions are not met, null is returned.
  ///
  /// An [OidcException] will be thrown if the server returns an error.
  Future<OidcUser?> refreshToken({
    String? overrideRefreshToken,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    if (!discoveryDocument.grantTypesSupportedOrDefault.contains(
      OidcConstants_GrantType.refreshToken,
    )) {
      //Server doesn't support refresh_token grant.
      return null;
    }

    final refreshToken =
        overrideRefreshToken ?? currentUser?.token.refreshToken;
    if (refreshToken == null) {
      // Can't refresh the access token anyway.
      return null;
    }

    final tokenResponse = await (settings.hooks?.token).execute(
      request: OidcTokenHookRequest(
        metadata: discoveryDocument,
        tokenEndpoint: discoveryDocument.tokenEndpoint!,
        request: OidcTokenRequest.refreshToken(
          refreshToken: refreshToken,
          clientId: clientCredentials.clientId,
          clientSecret: clientCredentials.clientSecret,
          extra: {...?settings.extraTokenParameters, ...?extraBodyFields},
          scope: settings.scope,
        ),
        credentials: clientCredentials,
        headers: settings.extraTokenHeaders,
        client: httpClient,
        options: settings.options,
      ),
      defaultExecution: (tokenHookRequest) async {
        return OidcEndpoints.token(
          tokenEndpoint: tokenHookRequest.tokenEndpoint,
          credentials: tokenHookRequest.credentials,
          client: tokenHookRequest.client,
          headers: tokenHookRequest.headers,
          request: tokenHookRequest.request,
        );
      },
    );

    return createUserFromToken(
      token: OidcToken.fromResponse(
        tokenResponse,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
        sessionState: currentUser?.token.sessionState,
      ),
      nonce: null,
      userInfo: null,
      attributes: null,
      metadata: discoveryDocument,
    );
  }

  @protected
  Future<void> listenToTokenRefreshIfSupported(
    OidcTokenEventsManager tokenEventsManager,
    OidcUser? user,
  ) async {
    if (user == null) {
      tokenEventsManager.unload();
    } else {
      if (user.token.expiresIn == null) {
        // Can't know how much time is left.
        return;
      }
      tokenEventsManager.load(user.token);
    }
  }

  @protected
  Future<void> handleTokenExpiring(OidcToken event) async {
    eventsController.add(
      OidcTokenExpiringEvent.now(currentToken: event),
    );
    final discoveryDocument = this.discoveryDocument;
    if (!discoveryDocument.grantTypesSupportedOrDefault.contains(
      OidcConstants_GrantType.refreshToken,
    )) {
      //Server doesn't support refresh_token grant.
      return;
    }

    final refreshToken = event.refreshToken;
    if (refreshToken == null) {
      return;
    }
    OidcUser? newUser;
    //try getting a new token.
    try {
      final tokenResponse = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: discoveryDocument,
          tokenEndpoint: discoveryDocument.tokenEndpoint!,
          credentials: clientCredentials,
          client: httpClient,
          headers: settings.extraTokenHeaders,
          request: OidcTokenRequest.refreshToken(
            refreshToken: refreshToken,
            clientId: clientCredentials.clientId,
            clientSecret: clientCredentials.clientSecret,
            extra: settings.extraTokenParameters,
            scope: settings.scope,
          ),
          options: settings.options,
        ),
        defaultExecution: (hookRequest) {
          return OidcEndpoints.token(
            tokenEndpoint: hookRequest.tokenEndpoint,
            credentials: hookRequest.credentials,
            client: hookRequest.client,
            headers: hookRequest.headers,
            request: hookRequest.request,
          );
        },
      );
      newUser = await createUserFromToken(
        token: OidcToken.fromResponse(
          tokenResponse,
          overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
          sessionState: event.sessionState,
        ),
        nonce: null,
        attributes: null,
        userInfo: null,
        metadata: discoveryDocument,
      );
    } catch (e) {
      //swallow errors on fail, but unload the event manager.
      tokenEvents.unload();
    }
    logger.fine('Refreshed a token and got a new user: ${newUser?.uid}');
  }

  @protected
  void handleTokenExpired(OidcToken event) {
    eventsController.add(
      OidcTokenExpiredEvent.now(currentToken: event),
    );

    if (!settings.supportOfflineAuth) {
      forgetUser();
    }
  }

  @protected
  List<Exception> validateUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
  }) {
    final errors = <Exception>[
      ...user.parsedIdToken.claims.validate(
        clientId: clientCredentials.clientId,
        issuer: metadata.issuer,
        expiryTolerance: settings.expiryTolerance,
      ),
    ];
    if (user.parsedIdToken.claims.subject == null) {
      errors.add(
        JoseException('id token is missing a `sub` claim.'),
      );
    }
    if (user.parsedIdToken.claims.issuedAt == null) {
      errors.add(
        JoseException('id token is missing an `iat` claim.'),
      );
    }

    return errors;
  }

  /// This function validates that a user claims
  @protected
  Future<OidcUser?> validateAndSaveUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
  }) async {
    var actualUser = user;
    final errors = validateUser(user: actualUser, metadata: metadata);
    OidcUserInfoResponse? userInfoResp;

    if (errors.isEmpty) {
      final userInfoEP = metadata.userinfoEndpoint;

      if (settings.userInfoSettings.sendUserInfoRequest && userInfoEP != null) {
        try {
          userInfoResp = await OidcEndpoints.userInfo(
            userInfoEndpoint: userInfoEP,
            accessToken: actualUser.token.accessToken!,
            requestMethod: settings.userInfoSettings.requestMethod,
            tokenLocation: settings.userInfoSettings.accessTokenLocation,
            client: httpClient,
            allowedAlgorithms: metadata.userinfoSigningAlgValuesSupported,
            followDistributedClaims:
                settings.userInfoSettings.followDistributedClaims,
            getAccessTokenForDistributedSource:
                settings.userInfoSettings.getAccessTokenForDistributedSource,
            keyStore: keyStore,
          );

          logger.info('UserInfo response: ${userInfoResp.src}');
          if (userInfoResp.sub != null &&
              userInfoResp.sub != actualUser.claims.subject) {
            errors.add(
              const OidcException("UserInfo didn't return the same subject."),
            );
          }
        } catch (e, st) {
          logger.severe('UserInfo endpoint threw an exception!', e, st);
        }
      }
    }

    if (errors.isEmpty ||
        //keep going if the only error is that the token expired,
        //and it's allowed in settings.
        (settings.supportOfflineAuth &&
            errors.every(
              (e) => e is JoseException && e.message.startsWith('JWT expired.'),
            ))) {
      // apply userinfo if present
      if (userInfoResp != null) {
        actualUser = actualUser.withUserInfo(userInfoResp.src);
      }
      await saveUser(actualUser);
      userSubject.add(actualUser);
      return actualUser;
    } else {
      for (final element in errors) {
        logger.warning(
          'Found the following problem when validation JWT: $element',
          element,
          StackTrace.current,
        );
      }
      await store.setCurrentNonce(null, managerId: id);

      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: {
          OidcConstants_Store.currentToken,
          OidcConstants_Store.currentUserInfo,
          OidcConstants_Store.currentUserAttributes,
          OidcConstants_AuthParameters.nonce,
        },
        managerId: id,
      );
    }
    return null;
  }

  @protected
  Future<void> cleanUpStore({
    required Set<OidcStoreNamespace> toDelete,
  }) async {
    for (final element in toDelete) {
      final keys = await store.getAllKeys(
        element,
        managerId: id,
      );
      await store.removeMany(
        element,
        keys: keys,
        managerId: id,
      );
    }
  }

  /// The discovery document containing openid configuration.
  OidcProviderMetadata get discoveryDocument {
    ensureInit();
    return currentDiscoveryDocument!;
  }

  set discoveryDocument(OidcProviderMetadata value) {
    currentDiscoveryDocument = value;
  }

  @protected
  OidcProviderMetadata? currentDiscoveryDocument;

  /// The discovery document Uri containing openid configuration.
  final Uri? discoveryDocumentUri;

  /// First gets the cached discoveryDocument if any
  /// (based on discoveryDocumentUri).
  ///
  /// Then tries to get it from the network.
  @protected
  Future<void> ensureDiscoveryDocument() async {
    final uri = discoveryDocumentUri;

    if (currentDiscoveryDocument != null) {
      return;
    }

    if (uri == null) {
      logAndThrow(
        'Impossible case of no discoveryDocument and no discoveryDocumentUri',
      );
    }
    final key = uri.toString();
    final cachedDocument = await store.get(
      OidcStoreNamespace.discoveryDocument,
      key: key,
      managerId: id,
    );
    if (cachedDocument != null) {
      try {
        ///try loading the document
        currentDiscoveryDocument = OidcProviderMetadata.fromJson(
          jsonDecode(cachedDocument) as Map<String, dynamic>,
        );
      } catch (e, st) {
        //swallow error.
        //remove the cached document.
        logger.warning(
          "Found a cached discovery document at key: $key, but couldn't parse it.\n"
          'Removing the bad key now.\n'
          'cached document: $cachedDocument',
          e,
          st,
        );
        await store
            .remove(OidcStoreNamespace.discoveryDocument, key: key)
            .onError((error, stackTrace) => null);
      }
    }

    try {
      currentDiscoveryDocument = await OidcEndpoints.getProviderMetadata(
        uri,
        client: httpClient,
      );
    } catch (e, st) {
      //maybe there is no internet.
      if (currentDiscoveryDocument == null) {
        logAndThrow(
          "Couldn't fetch the discoveryDocument",
          error: e,
          stackTrace: st,
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
    }

    await store.set(
      OidcStoreNamespace.discoveryDocument,
      key: key,
      value: jsonEncode(discoveryDocument.src),
      managerId: id,
    );
  }

  /// Loads and verifies the tokens.
  @protected
  Future<void> loadCachedTokens() async {
    final usedKeys = <String>{
      OidcConstants_Store.currentToken,
      OidcConstants_Store.currentUserAttributes,
      OidcConstants_Store.currentUserInfo,
    };

    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: usedKeys,
      managerId: id,
    );
    final rawToken = tokens[OidcConstants_Store.currentToken];
    final rawUserInfo = tokens[OidcConstants_Store.currentUserInfo];
    final rawAttributes = tokens[OidcConstants_Store.currentUserAttributes];
    if (rawToken == null) {
      return;
    }

    try {
      final decodedAttributes = rawAttributes == null
          ? null
          : jsonDecode(rawAttributes) as Map<String, dynamic>;
      final decodedUserInfo = rawUserInfo == null
          ? null
          : jsonDecode(rawUserInfo) as Map<String, dynamic>;
      final decodedToken = jsonDecode(rawToken) as Map<String, dynamic>;
      final token = OidcToken.fromJson(decodedToken);
      final metadata = discoveryDocument;
      var loadedUser = await createUserFromToken(
        token: token,
        // nonce is only checked for new tokens.
        nonce: null,
        attributes: decodedAttributes,
        userInfo: decodedUserInfo,
        metadata: metadata,
        validateAndSave: false,
      );
      if (loadedUser != null) {
        final validationErrors = validateUser(
          user: loadedUser,
          metadata: metadata,
        );
        final idTokenNeedsRefresh = validationErrors
            .whereType<JoseException>()
            .any((element) => element.message.startsWith('JWT expired'));

        if (token.refreshToken != null &&
            (idTokenNeedsRefresh || token.isAccessTokenExpired())) {
          try {
            loadedUser = await refreshToken(
              overrideRefreshToken: token.refreshToken,
            );
          } catch (e) {
            // An app might go offline during token refresh, so we consult the
            // supportOfflineAuth setting to check whether this is an issue or
            // not.
            if (!settings.supportOfflineAuth) {
              rethrow;
            }
          }
        }
        if (loadedUser != null) {
          loadedUser = await validateAndSaveUser(
            user: loadedUser,
            metadata: metadata,
          );
        }
      }

      if (loadedUser == null) {
        logAndThrow(
          'Found a cached token, but the user could not be created or validated',
        );
      }
    } catch (e) {
      if (!settings.supportOfflineAuth) {
        // remove invalid tokens, so that they don't get used again.
        await store.removeMany(
          OidcStoreNamespace.secureTokens,
          keys: usedKeys,
          managerId: id,
        );
      }
    }
  }

  /// Loads the current state, and checks if it has a result.
  ///
  /// if this returns `true`, a result has been found, and there is no need to
  /// load cached tokens.
  @protected
  Future<bool> loadStateResult() async {
    final statesWithResponses = await store.getStatesWithResponses();
    if (statesWithResponses.isEmpty) {
      return false;
    }

    for (final entry in statesWithResponses.entries) {
      final (stateData: stateDataRaw, stateResponse: stateResponseRaw) =
          entry.value;

      final stateResponseUrl = Uri.tryParse(stateResponseRaw);
      if (stateResponseUrl == null) {
        continue;
      }

      final stateData = OidcState.fromStorageString(stateDataRaw);
      if (stateData.managerId != id) {
        continue; // this state is not for this manager.
      }
      switch (stateData) {
        case OidcAuthorizeState():
          final resp = await OidcEndpoints.parseAuthorizeResponse(
            responseUri: stateResponseUrl,
          );

          await handleSuccessfulAuthResponse(
            response: resp,
            grantType: resp.code == null
                ? OidcConstants_GrantType.implicit
                : OidcConstants_GrantType.authorizationCode,
            metadata: discoveryDocument,
          );
          return true;
        case OidcEndSessionState():
          final resp = OidcEndSessionResponse.fromJson(
            stateResponseUrl.queryParameters,
          );
          await handleEndSessionResponse(result: resp);
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  /// returns true if there was a logout request.
  @protected
  Future<bool> loadLogoutRequests() async {
    final request = await store.getCurrentFrontChannelLogoutRequest();
    if (request == null) {
      return false;
    }
    final requestUri = Uri.tryParse(request);
    if (requestUri == null) {
      return false;
    }
    final requestType =
        requestUri.queryParameters[OidcConstants_Store.requestType];
    if (requestType != OidcConstants_Store.frontChannelLogout) {
      return false;
    }
    final parsedRequest = OidcFrontChannelLogoutIncomingRequest.fromJson(
      requestUri.queryParameters,
    );
    if (parsedRequest.managerId != id) {
      //this request is not for this manager.
      return false;
    }
    await handleFrontChannelLogoutRequest(parsedRequest);
    return true;
  }

  /// true if [init] has been called with no exceptions.
  bool get didInit => initMemoizer.hasRun;

  /// A future that completes when [init] completes.
  Future<void> get initFuture => initMemoizer.future;

  @protected
  AsyncMemoizer<void> initMemoizer = AsyncMemoizer();

  @protected
  final toDispose = <StreamSubscription<dynamic>>[];

  @protected
  Future<void> clearUnusedStates() async {
    await OidcState.clearStaleState(
      store: store,
      age: const Duration(days: 1),
    );
  }

  /// Initializes the user manager, this also gets the [discoveryDocument] if it
  /// wasn't provided.
  Future<void> init() {
    return initMemoizer.runOnce(() async {
      await Future.delayed(const Duration(seconds: 5));
      await store.init();
      await ensureDiscoveryDocument();
      final jwksUri = discoveryDocument.jwksUri;
      if (jwksUri != null) {
        keyStore.addKeySetUrl(jwksUri);
      }
      await clearUnusedStates();
      if (!await loadLogoutRequests()) {
        //no logout requests.
        if (!await loadStateResult()) {
          //no state results.
          await loadCachedTokens();
        }
      }
      final frontChannelLogoutUri = settings.frontChannelLogoutUri;
      if (frontChannelLogoutUri != null) {
        toDispose.add(
          listenToFrontChannelLogoutRequests(
            frontChannelLogoutUri,
            settings.frontChannelRequestListeningOptions,
          ).listen(handleFrontChannelLogoutRequest),
        );
      }

      //start listening to token events, if the user enabled them.

      toDispose
        ..add(
          userSubject.listen(
            (value) => listenToTokenRefreshIfSupported(tokenEvents, value),
          ),
        )
        ..add(userSubject.listen(listenToUserSessionIfSupported))
        ..add(tokenEvents.expiring.listen(handleTokenExpiring))
        ..add(tokenEvents.expired.listen(handleTokenExpired));
    });
  }

  /// Disposes the resources used by this class.
  Future<void> dispose() async {
    await sessionSub?.cancel();
    await tokenEvents.dispose();
    await userSubject.close();
    await eventsController.close();
    await Future.wait(toDispose.map((e) => e.cancel()));
  }

  @protected
  Future<void> handleFrontChannelLogoutRequest(
    OidcFrontChannelLogoutIncomingRequest request,
  ) async {
    await store.remove(
      OidcStoreNamespace.request,
      key: OidcConstants_Store.frontChannelLogout,
    );
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }

    //validate first.
    if (request.iss != currentUser.parsedIdToken.claims.issuer ||
        request.sid != currentUser.parsedIdToken.claims.sid) {
      //invalid request, do nothing.
      logger.severe(
        'Received a front channel logout request, but the issuer '
        'or the session ids were different.',
      );
      return;
    }
    //forget the user.
    await forgetUser();
  }

  ///
  @protected
  Future<OidcUser?> reAuthorizeUser() async {
    try {
      final user = await loginAuthorizationCodeFlow(
        promptOverride: ['none'],
        options: const OidcPlatformSpecificOptions(
          web: OidcPlatformSpecificOptions_Web(
            navigationMode:
                OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
          ),
        ),
      );
      return user;
    } on OidcException catch (e) {
      if (e.errorResponse != null) {
        if (!settings.supportOfflineAuth) {
          await forgetUser();
        }
        return null;
      }
      rethrow;
    }
  }
}
