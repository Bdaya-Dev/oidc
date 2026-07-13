import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';

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

  OidcDPoPManager? _dpopManager;

  /// The DPoP (RFC 9449) proof manager when DPoP is enabled
  /// (`settings.dpop != null`); otherwise null.
  ///
  /// Lazily created and reused for the manager's lifetime so that refresh
  /// proofs are signed with the SAME key as the original token request (the
  /// refresh token is sender-constrained to it).
  @protected
  OidcDPoPManager? get dpopManager {
    final dpopSettings = settings.dpop;
    if (dpopSettings == null) {
      return null;
    }
    return _dpopManager ??= OidcDPoPManager.generate(dpopSettings);
  }

  /// The settings used in this manager.
  final OidcUserManagerSettings settings;

  @protected
  final userSubject = OidcValueStream<OidcUser?>(null);

  @protected
  final eventsController = StreamController<OidcEvent>.broadcast();

  /// Tracks when offline mode was entered, null if not in offline mode
  DateTime? offlineModeStartedAt;

  /// Gets the last time the manager successfully communicated with the server.
  /// This can be useful for displaying "Last synced" information in the UI.
  /// Returns null if no successful server contact has been made yet.
  DateTime? lastSuccessfulServerContact;

  /// Counter for consecutive refresh failures
  int consecutiveRefreshFailures = 0;

  /// Returns true if the manager is currently in offline mode.
  bool get isInOfflineMode => offlineModeStartedAt != null;

  @protected
  Logger get logger => _logger;

  /// Gets a stream that reflects the current data of the user.
  Stream<OidcUser?> userChanges() => userSubject.stream;

  /// Gets a stream of events related to the current manager.
  Stream<OidcEvent> events() => eventsController.stream;

  /// Native browser-layer events (`OidcNativeBrowserEvent` subtypes) to forward
  /// into [events]. The platform manager overrides this to surface Custom Tabs
  /// / `ASWebAuthenticationSession` observability; empty by default (e.g. on
  /// web/desktop).
  @protected
  Stream<OidcEvent> listenToNativeBrowserEvents() => const Stream.empty();

  /// The current authenticated user.
  OidcUser? get currentUser => userSubject.value;

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
      resource: settings.resource,
      requestObjectSettings: settings.requestObject,
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
    // RFC 9126 Pushed Authorization Requests: when enabled, POST the prepared
    // request to the PAR endpoint (back channel, authenticated) and continue
    // the front channel by reference (`request_uri`). state/nonce/PKCE were
    // already persisted by prepareAuthorizationCodeFlowRequest above, so local
    // validation is unchanged (RFC 9126 §6).
    final shouldPushAuthorizationRequest =
        switch (settings.pushedAuthorizationRequestsMode) {
          OidcPushedAuthorizationRequestsMode.never => false,
          OidcPushedAuthorizationRequestsMode.always => true,
          OidcPushedAuthorizationRequestsMode.auto =>
            discoveryDocument.requirePushedAuthorizationRequestsOrDefault,
        };
    if (shouldPushAuthorizationRequest) {
      final parEndpoint = discoveryDocument.pushedAuthorizationRequestEndpoint;
      if (parEndpoint == null) {
        logAndThrow(
          'Pushed Authorization Requests are required/enabled but the '
          'authorization server did not advertise a '
          '`pushed_authorization_request_endpoint`.',
        );
      }
      final dpop = dpopManager;
      final parResponse = await OidcEndpoints.pushAuthorizationRequest(
        pushedAuthorizationRequestEndpoint: parEndpoint,
        request: requestContainer.request,
        credentials: clientCredentials,
        client: httpClient,
        // RFC 9449 §10: bind the authorization code to the DPoP key by sending
        // its thumbprint as `dpop_jkt` on the (back-channel) PAR request.
        extraBodyFields: dpop != null && dpop.settings.bindAuthorizationCode
            ? {OidcConstants_AuthParameters.dpopJkt: dpop.thumbprint}
            : null,
      );
      // Continue the authorization request by reference; generateUri now emits
      // only `client_id` + `request_uri` (RFC 9126 §4).
      requestContainer.request.requestUri = parResponse.requestUri;
    }
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
    Map<String, String>? extraTokenHeaders,
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
        headers: {
          ...?settings.extraTokenHeaders,
          ...?extraTokenHeaders,
        },
        client: httpClient,
        options: settings.options,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.token(
          tokenEndpoint: hookRequest.tokenEndpoint,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
          dpopManager: dpopManager,
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

  /// Attempts to login the user via the OAuth2 Device Authorization Grant.
  ///
  /// This adapts RFC 8628.
  ///
  /// The [onVerification] callback can be used by UIs/CLIs to display the
  /// verification URI/user code to the end-user.
  Future<OidcUser?> loginDeviceCodeFlow({
    List<String>? scopeOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraTokenParameters,
    Map<String, String>? extraTokenHeaders,
    FutureOr<void> Function(OidcDeviceAuthorizationResponse response)?
    onVerification,
  }) async {
    ensureInit();

    final metadata = discoveryDocumentOverride ?? discoveryDocument;
    final tokenEndpoint = metadata.tokenEndpoint;
    if (tokenEndpoint == null) {
      logAndThrow("This provider doesn't provide a token endpoint");
    }

    final deviceAuthEndpointValue = metadata
        .src[OidcConstants_ProviderMetadata.deviceAuthorizationEndpoint];
    if (deviceAuthEndpointValue == null) {
      logAndThrow(
        "This provider doesn't provide the device_authorization_endpoint",
      );
    }
    final deviceAuthorizationEndpoint = Uri.parse(
      deviceAuthEndpointValue.toString(),
    );

    final deviceResp = await OidcEndpoints.deviceAuthorization(
      deviceAuthorizationEndpoint: deviceAuthorizationEndpoint,
      credentials: clientCredentials,
      request: OidcDeviceAuthorizationRequest(
        scope: scopeOverride ?? settings.scope,
      ),
      client: httpClient,
    );

    await onVerification?.call(deviceResp);

    final deadline = clock.now().add(deviceResp.expiresIn);
    var pollInterval =
        deviceResp.interval ??
        OidcConstants_DeviceAuthorizationPolling.defaultInterval;

    while (clock.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      try {
        final tokenResp = await (settings.hooks?.token).execute(
          request: OidcTokenHookRequest(
            metadata: metadata,
            tokenEndpoint: tokenEndpoint,
            request: OidcTokenRequest.deviceCode(
              deviceCode: deviceResp.deviceCode,
              clientId: clientCredentials.clientId,
              scope: scopeOverride ?? settings.scope,
              extra: {
                ...?settings.extraTokenParameters,
                ...?extraTokenParameters,
              },
            ),
            credentials: clientCredentials,
            headers: {
              ...?settings.extraTokenHeaders,
              ...?extraTokenHeaders,
            },
            client: httpClient,
            options: settings.options,
          ),
          defaultExecution: (hookRequest) {
            return OidcEndpoints.token(
              tokenEndpoint: hookRequest.tokenEndpoint,
              credentials: hookRequest.credentials,
              headers: hookRequest.headers,
              dpopManager: dpopManager,
              request: hookRequest.request,
              client: hookRequest.client,
            );
          },
        );

        final token = OidcToken.fromResponse(
          tokenResp,
          overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
          sessionState: tokenResp.sessionState,
        );

        // If an id_token is not returned, we cannot construct an OIDC user.
        if (!token.isOidc) {
          throw const OidcException(
            "Server didn't return the id_token. Ensure `openid` scope is included.",
          );
        }

        return createUserFromToken(
          token: token,
          nonce: null,
          attributes: null,
          userInfo: null,
          metadata: metadata,
        );
      } on OidcException catch (e) {
        final code = e.errorResponse?.error;
        switch (code) {
          case OidcConstants_DeviceAuthorizationErrors.authorizationPending:
            continue;
          case OidcConstants_DeviceAuthorizationErrors.slowDown:
            pollInterval +=
                OidcConstants_DeviceAuthorizationPolling.slowDownIncrement;
            continue;
          case OidcConstants_DeviceAuthorizationErrors.accessDenied:
          case OidcConstants_DeviceAuthorizationErrors.expiredToken:
            return null;
          default:
            rethrow;
        }
      }
    }

    return null;
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
      // RFC 9207 mix-up attack defense, mirroring handleSuccessfulAuthResponse:
      // an authorization ERROR response is just as capable of originating
      // from the wrong AS as a successful one, so it gets the same `iss`
      // check before the original server-error is allowed to propagate.
      final responseIss = response.iss;
      final expectedIssuer = metadata.issuer;
      // §2.4: a client MUST reject a response that omits `iss` when the AS
      // advertises support via `authorization_response_iss_parameter_supported`.
      if (metadata.authorizationResponseIssParameterSupportedOrDefault &&
          responseIss == null) {
        logAndThrow(
          'The authorization server advertises '
          '`authorization_response_iss_parameter_supported` but the '
          'authorization error response is missing the `iss` parameter '
          '(RFC 9207 §2.4); refusing as a possible mix-up attack.',
        );
      }
      // When `iss` is present it MUST match the provider issuer (string compare,
      // not Uri normalization — RFC 9207 §2.4). A no-op for OPs that omit it and
      // do not advertise support.
      if (responseIss != null &&
          expectedIssuer != null &&
          responseIss.toString() != expectedIssuer.toString()) {
        logAndThrow(
          'Authorization error response `iss` ($responseIss) does not '
          'match the provider issuer ($expectedIssuer); possible mix-up '
          'attack (RFC 9207).',
        );
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
    // Best-effort token revocation (RFC 7009) before ending the session, so the
    // refresh and access tokens are invalidated server-side on logout. This is
    // a no-op when the OP advertises no `revocation_endpoint`, and it MUST NEVER
    // block logout: any failure is logged and swallowed. `forgetUser: false`
    // keeps the session intact so the end-session flow below can run.
    if (settings.revokeTokensOnLogout) {
      try {
        await revokeRefreshToken(forgetUser: false);
      } on Object catch (e, st) {
        logger.warning(
          'Best-effort refresh-token revocation on logout failed; '
          'continuing with logout.',
          e,
          st,
        );
      }
      try {
        await revokeAccessToken(forgetUser: false);
      } on Object catch (e, st) {
        logger.warning(
          'Best-effort access-token revocation on logout failed; '
          'continuing with logout.',
          e,
          st,
        );
      }
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
            managerId: id,
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
        // Always send id_token_hint: it's the RP-initiated-logout mechanism
        // OPs use to identify/authenticate the logout request, independent
        // of whether a post_logout_redirect_uri was also requested.
        idTokenHint: currentUser.idToken,
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
      // RFC 9207 mix-up attack defense.
      final responseIss = response.iss;
      final expectedIssuer = metadata.issuer;
      // §2.4: a client MUST reject a response that omits `iss` when the AS
      // advertises support via `authorization_response_iss_parameter_supported`.
      if (metadata.authorizationResponseIssParameterSupportedOrDefault &&
          responseIss == null) {
        logAndThrow(
          'The authorization server advertises '
          '`authorization_response_iss_parameter_supported` but the '
          'authorization response is missing the `iss` parameter '
          '(RFC 9207 §2.4); refusing as a possible mix-up attack.',
        );
      }
      // When `iss` is present it MUST match the provider issuer (string compare,
      // not Uri normalization — RFC 9207 §2.4). A no-op for OPs that omit it and
      // do not advertise support.
      if (responseIss != null &&
          expectedIssuer != null &&
          responseIss.toString() != expectedIssuer.toString()) {
        logAndThrow(
          'Authorization response `iss` ($responseIss) does not match the '
          'provider issuer ($expectedIssuer); possible mix-up attack (RFC 9207).',
        );
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
            // Hybrid responses may carry a front-channel `code` to bind via
            // `c_hash`; null for a pure implicit response.
            authorizationCode: response.code,
            maxAge: stateData.maxAge,
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

      // OpenID Connect Core §3.3.2 (Hybrid flow): when the authorization
      // endpoint ALSO returned an id_token in the front channel, validate it
      // before exchanging the code — `nonce` must match, `c_hash` must bind the
      // returned `code`, and `at_hash` (when present) must bind the
      // front-channel access_token.
      final frontChannelIdToken = response.idToken;
      if (frontChannelIdToken != null) {
        await validateFrontChannelIdToken(
          idToken: frontChannelIdToken,
          accessToken: response.accessToken,
          code: code,
          nonce: stateData.nonce,
          metadata: metadata,
          maxAge: stateData.maxAge,
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
            dpopManager: dpopManager,
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
        authorizationCode: code,
        maxAge: stateData.maxAge,
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
  /// Resolves the allowlist of JWS algorithms an id_token's `alg` header may
  /// use during signature verification.
  ///
  /// When [OidcUserManagerSettings.allowedIdTokenAlgorithms] is set, it
  /// **overrides** (replaces) the OP-advertised
  /// `id_token_signing_alg_values_supported` (defense-in-depth: the RP stops
  /// trusting the OP's self-declared list). When null (the default), the
  /// OP-advertised list is used unchanged. This is the single point where the
  /// pin overrides the OP-advertised list.
  @protected
  List<String>? resolveAllowedIdTokenAlgorithms(
    OidcProviderMetadata metadata,
  ) =>
      settings.allowedIdTokenAlgorithms ??
      metadata.idTokenSigningAlgValuesSupported;

  @protected
  Future<OidcUser?> createUserFromToken({
    required OidcToken token,
    required String? nonce,
    required Map<String, dynamic>? attributes,
    required Map<String, dynamic>? userInfo,
    required OidcProviderMetadata metadata,
    OidcUser? currentUserOverride,
    bool validateAndSave = true,
    String? authorizationCode,
    Duration? maxAge,
  }) async {
    final currentUser = currentUserOverride ?? this.currentUser;
    OidcUser? newUser;
    final idTokenOverride = await settings.getIdToken?.call(token);
    if (currentUser == null) {
      newUser = await OidcUser.fromIdToken(
        token: token,
        // Constrain id_token signature verification to the algorithms the OP
        // advertises for ID Tokens (id_token_signing_alg_values_supported),
        // not the token-endpoint client-authentication algorithms. An explicit
        // `allowedIdTokenAlgorithms` pin overrides the OP-advertised list.
        allowedAlgorithms: resolveAllowedIdTokenAlgorithms(metadata),
        keystore: keyStore,
        attributes: attributes,
        userInfo: userInfo,
        idTokenOverride: idTokenOverride,
        cacheStore: store,
        jwksCacheMaxAge: settings.jwksCacheMaxAge,
        httpClient: httpClient,
      );
    } else {
      final reusesExistingIdToken =
          idTokenOverride == null && token.idToken == null;
      newUser = await currentUser.replaceToken(
        token,
        idTokenOverride: idTokenOverride,
        cacheStore: store,
        allowExpiredIdToken: reusesExistingIdToken,
        jwksCacheMaxAge: settings.jwksCacheMaxAge,
        httpClient: httpClient,
      );
      // OpenID Connect Core §12.2: a freshly-issued id_token MUST keep the same
      // `sub` (and `iss`) as the prior one — refuse a possible account swap on
      // refresh. Skipped when the existing id_token is reused (no new token).
      if (!reusesExistingIdToken) {
        final oldClaims = currentUser.parsedIdToken.claims;
        final newClaims = newUser.parsedIdToken.claims;
        if (oldClaims.subject != null &&
            newClaims.subject != oldClaims.subject) {
          logAndThrow(
            'Refreshed id_token `sub` (${newClaims.subject}) does not match '
            'the existing user (${oldClaims.subject}); refusing a possible '
            'account swap.',
          );
        }
        if (oldClaims.issuer != null && newClaims.issuer != oldClaims.issuer) {
          logAndThrow(
            'Refreshed id_token `iss` (${newClaims.issuer}) does not match '
            'the existing user (${oldClaims.issuer}).',
          );
        }
      }
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
      return validateAndSaveUser(
        user: newUser,
        metadata: metadata,
        authorizationCode: authorizationCode,
        maxAge: maxAge,
      );
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
    unawaited(sessionSub?.cancel());
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

  /// Records a successful contact with the authorization server and optionally
  /// exits offline mode when connectivity is restored.
  @protected
  void recordSuccessfulServerContact({
    OidcToken? newToken,
    bool exitOffline = true,
  }) {
    lastSuccessfulServerContact = clock.now();
    consecutiveRefreshFailures = 0;
    if (exitOffline && isInOfflineMode) {
      exitOfflineMode(
        networkRestored: true,
        newToken: newToken,
      );
    }
  }

  /// Centralized handler for transitioning into offline mode when recoverable
  /// network issues occur during token operations.
  @protected
  bool handleOfflineEligibleFailure({
    required Object error,
    required OidcToken? fallbackToken,
    bool scheduleRetry = false,
    void Function(Duration retryDelay)? onRetryScheduled,
    bool emitRepeatFailureWarning = false,
  }) {
    if (!settings.supportOfflineAuth) {
      return false;
    }

    final canContinue = OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
      error: error,
      supportOfflineAuth: settings.supportOfflineAuth,
    );
    if (!canContinue) {
      return false;
    }

    consecutiveRefreshFailures++;

    // #120/#154: every caller of this method is a failed refresh path
    // (auto-expiry, manual, or startup-load), so offline mode is being entered
    // *because* a token refresh failed. Report that specific reason instead of
    // the generic network/server reason.
    enterOfflineMode(
      reason: OfflineModeReason.tokenRefreshFailed,
      currentToken: fallbackToken,
      error: error,
    );

    if (emitRepeatFailureWarning) {
      final threshold = settings.offlineRepeatFailureWarningThreshold;
      if (threshold > 0 && consecutiveRefreshFailures >= threshold) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.repeatRefreshFailure,
          message:
              'Token refresh has failed $consecutiveRefreshFailures consecutive times',
        );
      }
    }

    if (scheduleRetry && onRetryScheduled != null) {
      final retryDelay = calculateRetryDelay();
      logger.info(
        'Automatic token refresh failed (offline mode), will retry in $retryDelay',
      );
      onRetryScheduled(retryDelay);
    }

    return true;
  }

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
  }) {
    return _refreshToken(
      overrideRefreshToken: overrideRefreshToken,
      discoveryDocumentOverride: discoveryDocumentOverride,
      extraBodyFields: extraBodyFields,
    );
  }

  Future<OidcUser?> _refreshToken({
    String? overrideRefreshToken,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
    OidcUser? currentUserOverride,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    final existingUser = currentUserOverride ?? currentUser;
    // Availability of the refresh_token grant is determined by HAVING a
    // refresh_token, NOT by the OP advertising `refresh_token` in
    // `grant_types_supported`: that field is OPTIONAL discovery metadata
    // (RFC 8414 §2) which compliant IdPs (e.g. Facebook) omit, and RFC 6749 §6
    // ties refresh to possession of the token. Gating on the metadata silently
    // disabled refresh for those IdPs; if the OP genuinely rejects the grant,
    // the token-endpoint call below fails loudly instead.
    final refreshToken =
        overrideRefreshToken ?? existingUser?.token.refreshToken;
    if (refreshToken == null) {
      // Can't refresh the access token anyway.
      return null;
    }

    try {
      final tokenResponse = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: discoveryDocument,
          tokenEndpoint: discoveryDocument.tokenEndpoint!,
          // clientSecret is intentionally NOT passed here: `credentials`
          // below is the single source of client authentication (RFC 6749
          // §2.3). Also setting it on the request would duplicate it into
          // the body even when `credentials` already authenticates via the
          // Basic header (see OidcEndpoints.token).
          request: OidcTokenRequest.refreshToken(
            refreshToken: refreshToken,
            clientId: clientCredentials.clientId,
            extra: {...?settings.extraTokenParameters, ...?extraBodyFields},
            scope: settings.scope,
            resource: settings.resource,
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
            dpopManager: dpopManager,
            request: tokenHookRequest.request,
          );
        },
      );
      final token = OidcToken.fromResponse(
        tokenResponse,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
        sessionState: existingUser?.token.sessionState,
      );

      // Successful refresh - update last server contact and exit offline mode
      recordSuccessfulServerContact(newToken: token);
      return await createUserFromToken(
        token: token,
        nonce: null,
        userInfo: null,
        attributes: null,
        metadata: discoveryDocument,
        currentUserOverride: existingUser,
      );
    } on Object catch (e, st) {
      // #120: signal the failure to background observers of events() before any
      // offline handling or rethrow. The manual path schedules no retry, so
      // willRetry is always false here. This is the intentional double-signal:
      // observers get the event while the awaiting caller still gets the throw
      // below (MSAL pattern).
      eventsController.add(
        OidcTokenRefreshFailedEvent.fromError(
          error: e,
          stackTrace: st,
          source: OidcTokenRefreshSource.manual,
          willRetry: false,
        ),
      );

      // Handle errors based on offline auth settings
      final handledOffline = handleOfflineEligibleFailure(
        error: e,
        fallbackToken: existingUser?.token,
        emitRepeatFailureWarning: true,
      );

      if (handledOffline) {
        // Return the same user - callers will continue with cached state
        return existingUser;
      }

      // Non-network error or offline auth not supported - rethrow
      rethrow;
    }
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
    // Automatic refresh-on-expiry is gated on POSSESSION of a refresh_token, not
    // on the OP advertising `refresh_token` in grant_types_supported (OPTIONAL
    // metadata, RFC 8414 §2; refresh is tied to the token per RFC 6749 §6).
    // Gating on the metadata silently disabled auto-refresh for OPs that omit it
    // (e.g. Facebook) — this mirrors the same ungating already applied to the
    // manual _refreshToken path. A genuinely unsupported grant fails loudly at
    // the token endpoint below.
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
          // clientSecret is intentionally NOT passed here: `credentials`
          // above is the single source of client authentication (RFC 6749
          // §2.3). Also setting it on the request would duplicate it into
          // the body even when `credentials` already authenticates via the
          // Basic header (see OidcEndpoints.token).
          request: OidcTokenRequest.refreshToken(
            refreshToken: refreshToken,
            clientId: clientCredentials.clientId,
            extra: settings.extraTokenParameters,
            scope: settings.scope,
            resource: settings.resource,
          ),
          options: settings.options,
        ),
        defaultExecution: (hookRequest) {
          return OidcEndpoints.token(
            tokenEndpoint: hookRequest.tokenEndpoint,
            credentials: hookRequest.credentials,
            client: hookRequest.client,
            headers: hookRequest.headers,
            dpopManager: dpopManager,
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

      // Successful refresh - update last server contact and exit offline mode
      recordSuccessfulServerContact(newToken: newUser?.token);
    } on Object catch (e, st) {
      // #120: a transient failure that offline handling will absorb schedules a
      // retry; a terminal failure (e.g. invalid_grant) or a disabled offline
      // path does not. Compute this up front so the failure event carries an
      // accurate `willRetry`, and emit it BEFORE entering offline mode or
      // tearing down the timers (#154 ordering).
      final willRetry =
          settings.supportOfflineAuth &&
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: e,
            supportOfflineAuth: settings.supportOfflineAuth,
          );
      eventsController.add(
        OidcTokenRefreshFailedEvent.fromError(
          error: e,
          stackTrace: st,
          source: OidcTokenRefreshSource.autoExpiry,
          willRetry: willRetry,
        ),
      );

      final handledOffline = handleOfflineEligibleFailure(
        error: e,
        fallbackToken: event,
        scheduleRetry: true,
        onRetryScheduled: (retryDelay) {
          Timer(retryDelay, () {
            if (currentUser?.token == event) {
              tokenEvents.load(event);
            }
          });
        },
      );

      if (!handledOffline) {
        // Non-network error or offline auth not supported - unload event manager
        logger.warning(
          'Token refresh failed, unloading token events manager',
          e,
        );
        tokenEvents.unload();
      } else {
        return;
      }
    }
    logger.fine('Refreshed a token and got a new user: ${newUser?.uid}');
  }

  /// Calculates retry delay using the configured callback
  @protected
  Duration calculateRetryDelay() {
    return settings.offlineRefreshRetryDelay(consecutiveRefreshFailures);
  }

  /// Enters offline mode and emits appropriate events
  @protected
  void enterOfflineMode({
    required OfflineModeReason reason,
    OidcToken? currentToken,
    Object? error,
  }) {
    if (offlineModeStartedAt == null) {
      offlineModeStartedAt = clock.now();
      eventsController.add(
        OidcOfflineModeEnteredEvent.now(
          reason: reason,
          currentToken: currentToken,
          lastSuccessfulServerContact: lastSuccessfulServerContact,
          error: error,
        ),
      );
      logger.info('Entered offline mode: $reason');
    }
  }

  /// Exits offline mode and emits appropriate events
  @protected
  void exitOfflineMode({
    required bool networkRestored,
    required OidcToken? newToken,
  }) {
    if (offlineModeStartedAt != null) {
      offlineModeStartedAt = null;
      consecutiveRefreshFailures = 0;
      eventsController.add(
        OidcOfflineModeExitedEvent.now(
          networkRestored: networkRestored,
          newToken: newToken,
          lastSuccessfulServerContact: lastSuccessfulServerContact,
        ),
      );
      logger.info('Exited offline mode');
    }
  }

  /// Emits a warning event for offline auth security concerns
  @protected
  void emitOfflineAuthWarning({
    required OfflineAuthWarningType warningType,
    required String message,
    Duration? tokenExpiredSince,
  }) {
    eventsController.add(
      OidcOfflineAuthWarningEvent.now(
        warningType: warningType,
        message: message,
        tokenExpiredSince: tokenExpiredSince,
      ),
    );
  }

  /// Checks if the offline duration exceeds safe limits
  @protected
  bool isOfflineDurationExcessive() {
    if (offlineModeStartedAt == null) return false;

    final offlineDuration = clock.now().difference(offlineModeStartedAt!);
    // Default to 7 days as maximum offline duration
    const maxOfflineDuration = Duration(days: 7);

    return offlineDuration > maxOfflineDuration;
  }

  @protected
  void handleTokenExpired(OidcToken event) {
    eventsController.add(
      OidcTokenExpiredEvent.now(currentToken: event),
    );

    if (!settings.supportOfflineAuth) {
      unawaited(forgetUser());
    } else {
      // Only emit warning if we're actually in offline mode
      // (not just because offline auth is enabled)
      if (offlineModeStartedAt != null) {
        final user = currentUser;
        Duration? tokenExpiredSince;
        if (user != null) {
          final expiry = user.parsedIdToken.claims.expiry;
          if (expiry != null) {
            tokenExpiredSince = clock.now().difference(expiry);
          }
        }

        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.usingExpiredToken,
          message: 'Using expired ID token in offline mode',
          tokenExpiredSince: tokenExpiredSince,
        );
      }
      // If not in offline mode, the token will be automatically refreshed
      // by handleTokenExpiring, so no warning is needed
    }
  }

  @protected
  /// Performs an RFC 8693 Token Exchange at the token endpoint and returns the
  /// raw [OidcTokenResponse].
  ///
  /// This does NOT change the currently logged-in user; it is intended for
  /// obtaining a (possibly delegated/impersonated or downscoped) token for a
  /// downstream resource. When [subjectToken] is omitted it defaults to the
  /// current user's access token. [resource] defaults to
  /// [OidcUserManagerSettings.resource].
  Future<OidcTokenResponse> exchangeToken({
    String? subjectToken,
    String subjectTokenType = OidcConstants_TokenExchange_TokenType.accessToken,
    String? actorToken,
    String? actorTokenType,
    String? requestedTokenType,
    String? audience,
    List<Uri>? resource,
    List<String>? scope,
    Map<String, String>? headers,
    Map<String, dynamic>? extra,
  }) async {
    final tokenEndpoint = discoveryDocument.tokenEndpoint;
    if (tokenEndpoint == null) {
      logAndThrow("This provider doesn't provide a token endpoint.");
    }
    final actualSubjectToken = subjectToken ?? currentUser?.token.accessToken;
    if (actualSubjectToken == null) {
      throw const OidcException(
        'Token exchange requires a subject_token; none was provided and there '
        'is no current access token.',
      );
    }
    return (settings.hooks?.token).execute(
      request: OidcTokenHookRequest(
        metadata: discoveryDocument,
        tokenEndpoint: tokenEndpoint,
        credentials: clientCredentials,
        headers: {...?settings.extraTokenHeaders, ...?headers},
        client: httpClient,
        options: settings.options,
        // clientSecret is intentionally NOT passed here: `credentials`
        // above is the single source of client authentication (RFC 6749
        // §2.3). Also setting it on the request would duplicate it into
        // the body even when `credentials` already authenticates via the
        // Basic header (see OidcEndpoints.token).
        request: OidcTokenRequest.tokenExchange(
          subjectToken: actualSubjectToken,
          subjectTokenType: subjectTokenType,
          actorToken: actorToken,
          actorTokenType: actorTokenType,
          requestedTokenType: requestedTokenType,
          audience: audience,
          resource: resource ?? settings.resource,
          scope: scope,
          clientId: clientCredentials.clientId,
          extra: extra,
        ),
      ),
      defaultExecution: (hookRequest) => OidcEndpoints.token(
        tokenEndpoint: hookRequest.tokenEndpoint,
        credentials: hookRequest.credentials,
        headers: hookRequest.headers,
        dpopManager: dpopManager,
        request: hookRequest.request,
        client: hookRequest.client,
      ),
    );
  }

  /// Introspects a token (RFC 7662) using the provider's introspection
  /// endpoint, returning its metadata (notably whether it is `active`).
  ///
  /// Defaults to introspecting the current user's access token when [token] is
  /// omitted. The request is authenticated with the manager's client
  /// credentials.
  Future<OidcIntrospectionResponse> introspectToken({
    String? token,
    String? tokenTypeHint,
    Map<String, String>? headers,
    Map<String, dynamic>? extra,
  }) async {
    final introspectionEndpoint = discoveryDocument.introspectionEndpoint;
    if (introspectionEndpoint == null) {
      logAndThrow("This provider doesn't provide an introspection endpoint.");
    }
    final actualToken = token ?? currentUser?.token.accessToken;
    if (actualToken == null) {
      throw const OidcException(
        'Introspection requires a token; none was provided and there is no '
        'current access token.',
      );
    }
    return OidcEndpoints.introspect(
      introspectionEndpoint: introspectionEndpoint,
      credentials: clientCredentials,
      client: httpClient,
      headers: {...?settings.extraTokenHeaders, ...?headers},
      // clientSecret is intentionally NOT passed here: `credentials`
      // above is the single source of client authentication (RFC 6749
      // §2.3). Also setting it on the request would duplicate it into
      // the body even when `credentials` already authenticates via the
      // Basic header (see OidcEndpoints.token).
      request: OidcIntrospectionRequest(
        token: actualToken,
        tokenTypeHint: tokenTypeHint,
        clientId: clientCredentials.clientId,
        extra: extra,
      ),
    );
  }

  /// Validates the front-channel id_token returned by the authorization
  /// endpoint in the OpenID Connect Hybrid flow (OpenID Connect Core §3.3.2):
  /// signature, `nonce`, `c_hash` (binding [code]) and `at_hash` (binding the
  /// front-channel [accessToken], when present). Throws on any failure.
  ///
  /// This is an additional security gate run BEFORE the code is exchanged; the
  /// logged-in user is still built from the token-endpoint response.
  ///
  /// Per OpenID Connect Core §3.1.2.1 / §3.1.3.7 step 12, when [maxAge] was
  /// requested the front-channel id_token MUST carry `auth_time` and is
  /// rejected when `(now - auth_time) > maxAge + expiryTolerance`.
  @protected
  Future<void> validateFrontChannelIdToken({
    required String idToken,
    required String? accessToken,
    required String code,
    required String nonce,
    required OidcProviderMetadata metadata,
    Duration? maxAge,
  }) async {
    final frontChannelUser = await OidcUser.fromIdToken(
      token: OidcToken(
        creationTime: clock.now(),
        idToken: idToken,
        accessToken: accessToken,
        tokenType: accessToken == null ? null : 'Bearer',
      ),
      // The hybrid/implicit front-channel id_token gate, where the signature is
      // the sole protection — honour an explicit `allowedIdTokenAlgorithms` pin.
      allowedAlgorithms: resolveAllowedIdTokenAlgorithms(metadata),
      keystore: keyStore,
      cacheStore: store,
      jwksCacheMaxAge: settings.jwksCacheMaxAge,
      httpClient: httpClient,
    );
    final idTokenNonce =
        frontChannelUser.parsedIdToken.claims[OidcConstants_AuthParameters
                .nonce]
            as String?;
    if (idTokenNonce != nonce) {
      logAndThrow(
        'Hybrid front-channel id_token returned a wrong nonce, possible '
        'replay attack.',
      );
    }
    final errors = validateUser(
      user: frontChannelUser,
      metadata: metadata,
      authorizationCode: code,
      maxAge: maxAge,
    );
    if (errors.isNotEmpty) {
      for (final error in errors) {
        logger.warning(
          'Hybrid front-channel id_token validation problem: $error',
          error,
        );
      }
      logAndThrow(
        'Hybrid front-channel id_token failed validation: ${errors.first}',
      );
    }
  }

  List<Exception> validateUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
    String? authorizationCode,
    Duration? maxAge,
  }) {
    final claims = user.parsedIdToken.claims;
    // `exp` is REQUIRED (OIDC Core §2). jose's `validate()` force-unwraps the
    // expiry, so guard before calling it: a missing `exp` is a hard validation
    // failure (otherwise a malformed token throws an uncaught TypeError instead
    // of a collected exception, breaking the validation contract).
    final errors = <Exception>[];
    if (claims.expiry == null) {
      errors.add(
        JoseException('id token is missing the required `exp` claim.'),
      );
    } else {
      errors.addAll(
        claims.validate(
          clientId: clientCredentials.clientId,
          issuer: metadata.issuer,
          expiryTolerance: settings.expiryTolerance,
        ),
      );
    }
    if (user.token.allowExpiredIdToken) {
      errors.removeWhere(_isJwtExpiredError);
    }
    if (claims.subject == null) {
      errors.add(
        JoseException('id token is missing a `sub` claim.'),
      );
    }
    if (claims.issuedAt == null) {
      errors.add(
        JoseException('id token is missing an `iat` claim.'),
      );
    }

    // Additional OpenID Connect Core §3.1.3.7 id_token checks not covered by
    // the generic JWT validation above.

    // `azp` (authorized party): when present it MUST be the client_id, and when
    // the id_token carries more than one audience, `azp` is REQUIRED.
    final azp = claims['azp'];
    final audiences = claims.audience ?? const <String>[];
    if (azp != null && azp != clientCredentials.clientId) {
      errors.add(
        JoseException(
          'id token `azp` (`$azp`) does not match the client_id '
          '(`${clientCredentials.clientId}`).',
        ),
      );
    }
    if (audiences.length > 1 && azp == null) {
      errors.add(
        JoseException(
          'id token has multiple audiences but is missing the required '
          '`azp` (authorized party) claim.',
        ),
      );
    }

    // `nbf` (not-before): reject a token that is not yet valid, applying the
    // same clock-skew tolerance used for expiry.
    final notBefore = claims.notBefore;
    if (notBefore != null &&
        clock.now().isBefore(notBefore.subtract(settings.expiryTolerance))) {
      errors.add(
        JoseException(
          'id token is not yet valid; `nbf` ($notBefore) is more than the '
          'allowed tolerance (${settings.expiryTolerance}) after now.',
        ),
      );
    }

    // aud strictness (§3.1.3.7): the client_id is always trusted, and
    // `settings.allowedAudiences` extends the trust list. Any OTHER audience
    // means the token was minted for someone else and MUST be rejected.
    final trustedAudiences = <String>{
      clientCredentials.clientId,
      ...?settings.allowedAudiences,
    };
    final untrustedAudiences = audiences
        .where((a) => !trustedAudiences.contains(a))
        .toList();
    if (untrustedAudiences.isNotEmpty) {
      errors.add(
        JoseException(
          'id token contains untrusted audience(s) $untrustedAudiences, not '
          'in the client_id or settings.allowedAudiences.',
        ),
      );
    }

    // `at_hash` (§3.2.2.9): when present alongside an access_token, it MUST be
    // the base64url left-half hash of the access_token using the id_token's
    // signing-alg hash.
    final atHash = claims['at_hash'];
    final accessToken = user.token.accessToken;
    if (atHash is String && accessToken != null) {
      final alg = oidcReadJwtAlg(user.idToken);
      final expected = alg == null
          ? null
          : oidcComputeTokenHash(alg, accessToken);
      // Compare padding-insensitively: the spec mandates unpadded base64url,
      // but tolerate a non-conformant OP that pads rather than false-rejecting.
      if (expected != null && expected != atHash.replaceAll('=', '')) {
        errors.add(
          JoseException('id token `at_hash` does not match the access_token.'),
        );
      }
    }

    // `c_hash` (§3.3.2.11): when an id_token returned from the authorization
    // endpoint alongside an authorization `code` (hybrid flow) carries `c_hash`,
    // it MUST be the base64url left-half hash of the code, using the id_token's
    // signing-alg hash.
    final cHash = claims['c_hash'];
    if (cHash is String && authorizationCode != null) {
      final alg = oidcReadJwtAlg(user.idToken);
      final expected = alg == null
          ? null
          : oidcComputeTokenHash(alg, authorizationCode);
      if (expected != null && expected != cHash.replaceAll('=', '')) {
        errors.add(
          JoseException(
            'id token `c_hash` does not match the authorization code.',
          ),
        );
      }
    }

    // `auth_time` vs `max_age` (§3.1.2.1): when `max_age` was requested, the
    // id_token MUST contain `auth_time`, and the end-user's last authentication
    // MUST NOT be older than `max_age` (within the configured tolerance).
    if (maxAge != null) {
      final authTimeRaw = claims['auth_time'];
      final authTime = authTimeRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (authTimeRaw * 1000).round(),
              isUtc: true,
            )
          : null;
      if (authTime == null) {
        errors.add(
          JoseException(
            '`max_age` was requested but the id token is missing the required '
            '`auth_time` claim.',
          ),
        );
      } else if (clock.now().isAfter(
        authTime.add(maxAge).add(settings.expiryTolerance),
      )) {
        errors.add(
          JoseException(
            'id token `auth_time` ($authTime) is older than the requested '
            'max_age ($maxAge).',
          ),
        );
      }
    }

    return errors;
  }

  bool _isJwtExpiredError(Exception error) =>
      error is JoseException && error.message.startsWith('JWT expired');

  /// This function validates that a user claims
  @protected
  Future<OidcUser?> validateAndSaveUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
    String? authorizationCode,
    Duration? maxAge,
  }) async {
    var actualUser = user;
    final errors = validateUser(
      user: actualUser,
      metadata: metadata,
      authorizationCode: authorizationCode,
      maxAge: maxAge,
    );
    OidcUserInfoResponse? userInfoResp;
    var userInfoFailed = false;

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
            // OIDC Core 5.3.2/5.3.4: validate iss/aud/exp on a signed
            // (verified) UserInfo JWT.
            expectedIssuer: metadata.issuer,
            clientId: clientCredentials.clientId,
            validateSignedResponseClaims:
                settings.userInfoSettings.validateSignedResponseClaims,
            requireSignedResponseIssAud:
                settings.userInfoSettings.requireSignedResponseIssAud,
            claimsExpiryTolerance: settings.expiryTolerance,
            // Present a DPoP-bound access token with the DPoP scheme + an
            // `ath`-bound proof (RFC 9449 §7.1).
            dpopManager: actualUser.token.tokenType?.toUpperCase() == 'DPOP'
                ? dpopManager
                : null,
          );

          logger.info('UserInfo response: ${userInfoResp.src}');
          // OIDC Core §5.3.2: `sub` is REQUIRED in the UserInfo response; a
          // response omitting it MUST be rejected, not silently accepted.
          if (userInfoResp.sub != actualUser.claims.subject) {
            errors.add(
              const OidcException("UserInfo didn't return the same subject."),
            );
          }

          // Successfully contacted server - update last contact time
          recordSuccessfulServerContact(
            newToken: actualUser.token,
            exitOffline: false,
          );
        } on Object catch (e, st) {
          logger.severe('UserInfo endpoint threw an exception!', e, st);
          userInfoFailed = true;

          // Check if this is a network/server error that should enter offline mode
          if (settings.supportOfflineAuth) {
            final errorType = OidcOfflineAuthErrorHandler.categorizeError(e);
            if (errorType == OfflineAuthErrorType.networkUnavailable ||
                errorType == OfflineAuthErrorType.networkTimeout) {
              enterOfflineMode(
                reason: OfflineModeReason.userInfoUnavailable,
                currentToken: actualUser.token,
                error: e,
              );
              emitOfflineAuthWarning(
                warningType: OfflineAuthWarningType.staleUserInfo,
                message: 'Using cached user information due to network error',
              );
            } else if (errorType == OfflineAuthErrorType.serverError) {
              enterOfflineMode(
                reason: OfflineModeReason.serverUnavailable,
                currentToken: actualUser.token,
                error: e,
              );
            }
          }
        }
      }
    }

    // Check if we're using expired tokens in offline mode
    final hasExpiredTokenError = errors.any(_isJwtExpiredError);

    if (errors.isEmpty ||
        //keep going if the only error is that the token expired,
        //and it's allowed in settings.
        (settings.supportOfflineAuth && errors.every(_isJwtExpiredError))) {
      // Check if offline duration is excessive
      if (settings.supportOfflineAuth && isOfflineDurationExcessive()) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.extendedOfflineDuration,
          message: 'User has been in offline mode for an extended period',
        );
      }

      // If validation passed with no errors and we were in offline mode, exit it
      if (errors.isEmpty && offlineModeStartedAt != null && !userInfoFailed) {
        exitOfflineMode(
          networkRestored: true,
          newToken: actualUser.token,
        );
      }

      // Emit warning if token validation was skipped
      if (hasExpiredTokenError &&
          settings.supportOfflineAuth &&
          isInOfflineMode) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.tokenValidationSkipped,
          message: 'Token validation skipped in offline mode',
        );
      }

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
      // An eagerly-supplied discoveryDocument (eager constructor, where
      // discoveryDocumentUri is null) is still validated against
      // `settings.expectedIssuer`.
      _validateDiscoveryIssuer();
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
      } on Object catch (e, st) {
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

    // RFC 8414 §2.1/§3.2: when enabled, verify the document's `signed_metadata`
    // JWT (if present) and merge its verified claims OVER the plain JSON BEFORE
    // issuer-validation and persistence, so a signed-metadata issuer change is
    // still issuer-validated and only a verified+validated document is cached.
    if (settings.verifySignedMetadata &&
        currentDiscoveryDocument!.src.containsKey(
          OidcConstants_ProviderMetadata.signedMetadata,
        )) {
      try {
        currentDiscoveryDocument =
            await OidcEndpoints.verifyAndMergeSignedMetadata(
              metadata: currentDiscoveryDocument!,
              expectedIssuer:
                  settings.expectedIssuer ??
                  OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(uri),
              allowedAlgorithms:
                  settings.allowedSignedMetadataAlgorithms ??
                  currentDiscoveryDocument!.idTokenSigningAlgValuesSupported,
              cacheStore: store,
              client: httpClient,
              jwksCacheMaxAge: settings.jwksCacheMaxAge,
            );
      } on OidcException catch (e, st) {
        // Always fail-closed: refuse to use the document. There is no
        // unverified-fallback opt-out (mirrors id_token handling).
        logAndThrow(
          'Failed to verify the discovery `signed_metadata` JWT '
          '(RFC 8414 §2.1); refusing to use the document.',
          error: e,
          stackTrace: st,
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
    }

    // Validate the final document (cache- or network-sourced) BEFORE persisting,
    // so a mismatched/poisoned document is never written to the store.
    _validateDiscoveryIssuer();

    await store.set(
      OidcStoreNamespace.discoveryDocument,
      key: key,
      value: jsonEncode(discoveryDocument.src),
      managerId: id,
    );
  }

  /// OIDC Discovery 1.0 §4.3 / RFC 8414 §3.3: the discovery document's `issuer`
  /// MUST be identical to the issuer used to fetch it.
  ///
  /// Controlled by [OidcUserManagerSettings.strictIssuerValidation]: when
  /// `true`, a mismatch (or a missing `issuer`) throws; when `false` (the
  /// default), a mismatch is only logged as a warning and the document is still
  /// used (preserves Entra multi-tenant / B2C compatibility).
  void _validateDiscoveryIssuer() {
    final strict = settings.strictIssuerValidation;
    // Resolve the expected issuer: explicit `expectedIssuer` is authoritative;
    // otherwise derive it from the well-known URL (the inverse of the builder
    // every in-repo call site uses).
    final uri = discoveryDocumentUri;
    final expected =
        settings.expectedIssuer ??
        (uri == null
            ? null
            : OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(uri));

    if (expected == null) {
      if (strict) {
        logger.warning(
          'strictIssuerValidation is enabled but no expected issuer could be '
          'determined (no `expectedIssuer` was set and the discovery URL could '
          'not be inverted, e.g. an eagerly-supplied document or a custom '
          'discovery URL); skipping the §4.3 issuer check.',
        );
      }
      return;
    }

    final actual = currentDiscoveryDocument?.issuer;
    if (actual == null) {
      if (strict) {
        logAndThrow(
          'Discovery document is missing the required `issuer` member '
          '(OIDC Discovery §3 / RFC 8414 §2).',
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
      logger.warning(
        'Discovery document is missing the required `issuer` member; '
        'strictIssuerValidation is disabled so it is being used anyway.',
      );
      return;
    }

    if (OidcUtils.issuersAreIdentical(expected, actual)) {
      return;
    }
    if (strict) {
      logAndThrow(
        'Issuer mismatch (OIDC Discovery §4.3 / RFC 8414 §3.3): discovery '
        'issuer ($actual) != expected issuer ($expected).',
        extra: {
          OidcConstants_Exception.discoveryDocumentUri: uri,
        },
      );
    }
    logger.warning(
      'Issuer mismatch (OIDC Discovery §4.3 / RFC 8414 §3.3): discovery issuer '
      '($actual) != expected issuer ($expected); strictIssuerValidation is '
      'disabled so the document is being used anyway.',
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
            final refreshedUser = await _refreshToken(
              overrideRefreshToken: token.refreshToken,
              currentUserOverride: loadedUser,
            );
            if (refreshedUser != null) {
              loadedUser = refreshedUser;
            }
          } catch (e, st) {
            // #120: surface the startup-load refresh failure before offline
            // handling / rethrow.
            eventsController.add(
              OidcTokenRefreshFailedEvent.fromError(
                error: e,
                stackTrace: st,
                source: OidcTokenRefreshSource.startupLoad,
                willRetry: false,
              ),
            );

            // An app might go offline during token refresh, so we consult the
            // supportOfflineAuth setting to check whether this is an issue or
            // not.
            final handledOffline = handleOfflineEligibleFailure(
              error: e,
              fallbackToken: token,
              emitRepeatFailureWarning: true,
            );

            if (!handledOffline) {
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
    } on Object catch (_) {
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
            // Enables JARM: a signed `response` JWT is verified against the
            // provider keys (never `alg:none`) and its `iss`/`aud`/`exp` are
            // enforced before its inner parameters are used.
            keyStore: keyStore,
            allowedAlgorithms:
                discoveryDocument.idTokenSigningAlgValuesSupported,
            expectedAudience: clientCredentials.clientId,
            // RFC 9207: validate `iss` (incl. on error redirects) before the
            // server-error throw; require it when the AS advertises support.
            expectedIssuer: discoveryDocument.issuer,
            requireIss: discoveryDocument
                .authorizationResponseIssParameterSupportedOrDefault,
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
      await store.init();
      await ensureDiscoveryDocument();
      final jwksUri = discoveryDocument.jwksUri;
      if (jwksUri != null) {
        keyStore.addKeySetUrl(jwksUri);
      }
      final clientSecret = clientCredentials.clientSecret;
      if (clientSecret != null) {
        // RFC 7518 §3.2 / OIDC Core §16.19: HS256/384/512 id_tokens are
        // MAC-signed with the client_secret octets as the key. Register it as an
        // `oct` key so symmetric id_token signatures can be verified. Without
        // this, HS*-signed id_tokens were unverifiable. The extra key is inert
        // for RS*/ES* tokens (those still verify via the jwks_uri keys above).
        keyStore.addKey(
          JsonWebKey.fromJson({
            'kty': 'oct',
            'k': base64Url
                .encode(utf8.encode(clientSecret))
                .replaceAll('=', ''),
            'use': 'sig',
          }),
        );
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
        ..add(tokenEvents.expired.listen(handleTokenExpired))
        // Surface native browser-layer observability through events().
        ..add(listenToNativeBrowserEvents().listen(eventsController.add));
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

    // Validate `iss`/`sid` ONLY when the OP actually sent them. Per OpenID
    // Connect Front-Channel Logout 1.0 §3, both are OPTIONAL (sent only when
    // `frontchannel_logout_session_required` is true); a spec-compliant OP MAY
    // omit them. The previous `request.iss != issuer` compare treated a missing
    // (null) param as a mismatch and silently refused to log the user out
    // against every such OP. Now: a PRESENT-but-mismatched value is rejected
    // (defense), an ABSENT value is accepted.
    final issMismatch =
        request.iss != null &&
        request.iss != currentUser.parsedIdToken.claims.issuer;
    final sidMismatch =
        request.sid != null &&
        request.sid != currentUser.parsedIdToken.claims.sid;
    if (issMismatch || sidMismatch) {
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
