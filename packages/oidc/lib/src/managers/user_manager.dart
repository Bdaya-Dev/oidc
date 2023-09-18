import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:oidc/src/facade.dart';
import 'package:oidc/src/models/user_manager_settings.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:rxdart/rxdart.dart';

final _logger = Logger('OidcUserManager');
Never _logAndThrow(
  String message, {
  Map<String, dynamic> extra = const {},
  Object? error,
  StackTrace? stackTrace,
}) {
  final ex = OidcException(
    message,
    extra: extra,
  );
  _logger.severe(message, error ?? ex, stackTrace ?? StackTrace.current);
  throw ex;
}

/// This class manages a single user's authentication status.
///
/// It's preferred to maintain only a single instance of this class.
class OidcUserManager {
  /// Create a new UserManager from [OidcProviderMetadata].
  ///
  /// if [discoveryDocument] is not available,
  /// consider using the [OidcUserManager.lazy] constructor.
  OidcUserManager({
    required OidcProviderMetadata discoveryDocument,
    required this.clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
  })  : discoveryDocumentUri = null,
        _discoveryDocument = discoveryDocument,
        keyStore = keyStore ?? JsonWebKeyStore();

  /// Create a new UserManager that delays getting the discovery document until
  /// [init] is called.
  OidcUserManager.lazy({
    required Uri this.discoveryDocumentUri,
    required this.clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
  }) : keyStore = keyStore ?? JsonWebKeyStore();

  /// The client authentication information.
  final OidcClientAuthentication clientCredentials;

  /// The http client to use when sending requests
  final http.Client? httpClient;

  /// The store responsible for setting/getting cached values.
  final OidcStore store;

  /// The id_token verification options.
  final JsonWebKeyStore keyStore;

  /// The settings used in this manager.
  final OidcUserManagerSettings settings;

  final _userSubject = BehaviorSubject<OidcUser?>.seeded(null);

  /// Gets a stream that reflects the current data of the user.
  Stream<OidcUser?> userChanges() => _userSubject.stream;

  /// The current authenticated user.
  OidcUser? get currentUser => _userSubject.valueOrNull;

  void _ensureInit() {
    if (!_hasInit) {
      _logAndThrow(
        "discoveryDocument hasn't been fetched yet, "
        'please call init() first.',
      );
    }
  }

  Map<String, dynamic> _getOptions(OidcPlatformSpecificOptions options) => {
        if (kIsWeb) 'webLaunchMode': options.web.navigationMode.name,
      };

  /// Attempts to login the user via the AuthorizationCodeFlow.
  ///
  /// [originalUri] is the uri you want to be redirected to after authentication is done,
  /// if null, it defaults to `redirectUri`.
  Future<OidcUser?> loginAuthorizationCodeFlow({
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
    _ensureInit();
    await _cleanUpStore(toDelete: {
      OidcStoreNamespace.session,
      OidcStoreNamespace.state,
      OidcStoreNamespace.stateResponse,
      OidcStoreNamespace.secureTokens,
    });
    final doc = discoveryDocument;
    options ??= settings.options ?? const OidcPlatformSpecificOptions();
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
      idTokenHint: idTokenHintOverride ??
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
      options: _getOptions(options),
    );
    final requestContainer =
        await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
    );

    final response = await OidcFlutter.getPlatformAuthorizationResponse(
      metadata: discoveryDocument,
      request: requestContainer.request,
      options: options,
    );
    if (response == null) {
      return null;
    }

    return _handleSuccessfulAuthResponse(
      response: response,
      grantType: OidcConstants_GrantType.authorizationCode,
    );
  }

  /// Attempts to login the user via resource owner's credentials.
  Future<OidcUser?> loginPassword({
    required String username,
    required String password,
    List<String>? scopeOverride,
  }) async {
    final tokenResp = await OidcEndpoints.token(
      tokenEndpoint: discoveryDocument.tokenEndpoint!,
      request: OidcTokenRequest.password(
        password: password,
        username: username,
        scope: scopeOverride ?? settings.scope,
        clientId: clientCredentials.clientId,
        extra: settings.extraTokenParameters,
      ),
      headers: settings.extraTokenHeaders,
      client: httpClient,
      credentials: clientCredentials,
    );

    return _createUserFromToken(
      token: OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
      ),
      nonce: null,
    );
  }

  ///
  @Deprecated('Implicit flow is deprecated due to security reasons.')
  Future<OidcUser?> loginImplicitFlow({
    required List<String> responseType,
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
    _ensureInit();
    final doc = discoveryDocument;
    options ??= const OidcPlatformSpecificOptions();
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
      idTokenHint: idTokenHintOverride ??
          (includeIdTokenHintFromCurrentUser ? currentUser?.idToken : null),
      loginHint: loginHint,
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
      options: _getOptions(options),
    );
    final request = await OidcEndpoints.prepareImplicitFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
    );

    final response = await OidcFlutter.getPlatformAuthorizationResponse(
      metadata: discoveryDocument,
      request: request,
      options: options,
    );
    if (response == null) {
      return null;
    }

    return _handleSuccessfulAuthResponse(
      response: response,
      grantType: OidcConstants_GrantType.implicit,
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
    await store.remove(
      OidcStoreNamespace.session,
      key: OidcConstants_AuthParameters.nonce,
    );
    await _cleanUpStore(toDelete: {
      OidcStoreNamespace.stateResponse,
      OidcStoreNamespace.request,
      OidcStoreNamespace.secureTokens,
    });
    _userSubject.add(null);
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
  }) async {
    _ensureInit();
    final doc = discoveryDocument;
    options ??= const OidcPlatformSpecificOptions();
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final postLogoutRedirectUri =
        postLogoutRedirectUriOverride ?? settings.postLogoutRedirectUri;

    // final willComeBack = postLogoutRedirectUri != null;
    final stateData = postLogoutRedirectUri == null
        ? null
        : OidcEndSessionState(
            postLogoutRedirectUri: postLogoutRedirectUri,
            originalUri: originalUri,
            options: _getOptions(options),
            data: extraStateData,
          );
    if (stateData != null) {
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
      await store.setCurrentState(stateData.id);
    }
    final resultFuture = OidcFlutter.getPlatformEndSessionResponse(
      metadata: doc,
      request: OidcEndSessionRequest(
        clientId: clientCredentials.clientId,
        postLogoutRedirectUri: postLogoutRedirectUri,
        uiLocales: uiLocalesOverride ?? settings.uiLocales,
        idTokenHint: currentUser.idToken,
        extra: extraParameters,
        logoutHint: logoutHint,
        state: stateData?.id,
      ),
      options: options,
    );
    if (stateData == null) {
      // they won't come back with a result!
      await forgetUser();
      return;
    }
    final result = await resultFuture;
    if (result == null) {
      if (kIsWeb &&
          options.web.navigationMode ==
              OidcPlatformSpecificOptions_Web_NavigationMode.samePage) {
        //wait for a result after redirect.
        return;
      }
      await forgetUser();
      return;
    }
    await _handEndSessionResponse(result: result);
  }

  Future<void> _handEndSessionResponse({
    required OidcEndSessionResponse result,
  }) async {
    final currentState = await store.getCurrentState();
    if (currentState != null) {
      try {
        //found result!
        final resState = result.state;
        if (resState == null) {
          _logAndThrow("Didn't receive state, even though it was sent.");
        }
        final resStateData = await store.getStateData(resState);
        if (resStateData == null) {
          _logAndThrow("Didn't receive correct state value.");
        }
        final parsedState = OidcState.fromStorageString(resStateData);
        await store.setStateData(state: resState, stateData: null);
        if (parsedState is! OidcEndSessionState) {
          _logAndThrow('received wrong state type.');
        }
      } finally {
        await store.setCurrentState(null);
      }
    }
    //if all state checks are successful, do logout.
    await forgetUser();
  }

  Future<OidcUser?> _handleSuccessfulAuthResponse({
    required OidcAuthorizeResponse response,
    required String grantType,
  }) async {
    final receivedStateKey = response.state;
    if (receivedStateKey == null) {
      _logAndThrow(
          "Server didn't return state parameter, even though it was sent.");
    }
    final currentStateKey = await store.getCurrentState();
    if (currentStateKey != receivedStateKey) {
      _logAndThrow('Server sent an older or different state parameter.');
    }

    final stateDataStr = await store.getStateData(receivedStateKey);
    if (stateDataStr == null) {
      await store.setCurrentState(null);
      _logger.warning(
        "Internal error, the session state wasn't cleared after the state was deleted.",
      );
      return null;
    }
    final stateData = OidcState.fromStorageString(stateDataStr);
    if (stateData is! OidcAuthorizeState) {
      _logAndThrow('received wrong state type.');
    }
    if (grantType == OidcConstants_GrantType.implicit) {
      final implicitTokenResponse = OidcTokenResponse.fromJson(response.src);

      if (implicitTokenResponse.accessToken != null ||
          implicitTokenResponse.idToken != null) {
        return _createUserFromToken(
          token: OidcToken.fromResponse(
            implicitTokenResponse,
            overrideExpiresIn:
                settings.getExpiresIn?.call(implicitTokenResponse),
          ),
          nonce: stateData.nonce,
        );
      }
    }
    final doc = discoveryDocument;
    final tokenEndPoint = doc.tokenEndpoint;
    if (tokenEndPoint == null) {
      _logAndThrow(
        "This provider doesn't provide a token endpoint",
      );
    }
    final code = response.code;
    if (code == null) {
      _logAndThrow(
        "Server didn't send code even though the authorization code flow was used.",
      );
    }
    final tokenResp = await OidcEndpoints.token(
      tokenEndpoint: tokenEndPoint,
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
    );
    return _createUserFromToken(
      token: OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
      ),
      nonce: stateData.nonce,
    );
  }

  /// Handles a token; either from cache, in which case the [nonce] will be null
  /// , or from an auth response, in which case [nonce] will not be null.
  ///
  /// This function creates an [OidcUser] by validating the token, and then
  /// passing the result to [_validateAndSaveUser].
  ///
  /// if the manager already has a [currentUser], this function replaces
  /// its internal token (after validation).
  Future<OidcUser?> _createUserFromToken({
    required OidcToken token,
    required String? nonce,
    Map<String, dynamic>? attributes,
  }) async {
    final currentUser = this.currentUser;
    OidcUser newUser;
    if (currentUser == null) {
      newUser = await OidcUser.fromIdToken(
        token: token,
        allowedAlgorithms:
            discoveryDocument.tokenEndpointAuthSigningAlgValuesSupported,
        keystore: keyStore,
        attributes: attributes,
        strictVerification: settings.strictJwtVerification,
      );
    } else {
      newUser = await currentUser.replaceToken(token);
      if (attributes != null) {
        newUser = newUser.setAttributes(attributes);
      }
    }

    final idTokenNonce = newUser
        .parsedIdToken.claims[OidcConstants_AuthParameters.nonce] as String?;
    if (nonce != null && idTokenNonce != nonce) {
      _logAndThrow(
        'Server returned a wrong id_token nonce, might be a replay attack.',
      );
    }
    return _validateAndSaveUser(newUser);
  }

  Future<void> _saveUser(OidcUser user) async {
    await store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {
        OidcConstants_Store.currentToken: jsonEncode(user.token.toJson()),
        OidcConstants_Store.currentUserAttributes: jsonEncode(user.attributes),
      },
    );
    _userSubject.add(user);
  }

  late final _tokenEvents = OidcTokenEventsManager(
    getExpiringNotificationTime: settings.refreshBefore,
  );
  Future<void> _listenToTokenRefreshIfSupported(
    OidcTokenEventsManager tokenEventsManager,
    OidcUser? user,
  ) async {
    if (user == null) {
      tokenEventsManager.unload();
    } else {
      if (!discoveryDocument.grantTypesSupportedOrDefault
          .contains(OidcConstants_GrantType.refreshToken)) {
        //Server doesn't support refresh_token grant.
        return;
      }
      if (user.token.refreshToken == null) {
        // Can't refresh the access token anyway.
        return;
      }
      if (user.token.expiresIn == null) {
        // Can't know how much time is left.
        return;
      }
      tokenEventsManager.load(user.token);
    }
  }

  Future<void> _handleTokenExpiring(OidcToken event) async {
    final refreshToken = event.refreshToken;
    if (refreshToken == null) {
      return;
    }
    OidcUser? newUser;
    //try getting a new token.
    try {
      final tokenResponse = await OidcEndpoints.token(
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
      );
      newUser = await _createUserFromToken(
        token: OidcToken.fromResponse(
          tokenResponse,
          overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
        ),
        nonce: null,
      );
    } catch (e) {
      //swallow errors on fail, but unload the event manager.
      _tokenEvents.unload();
    }
    _logger.fine('Refreshed a token and got a new user: ${newUser?.uid}');
  }

  void _handleTokenExpired(OidcToken event) {}

  /// This function validates that a user claims
  Future<OidcUser?> _validateAndSaveUser(OidcUser user) async {
    var actualUser = user;
    final errors = actualUser.parsedIdToken.claims
        .validate(
          clientId: clientCredentials.clientId,
          issuer: discoveryDocument.issuer,
          expiryTolerance: settings.expiryTolerance,
        )
        .toList();
    if (actualUser.parsedIdToken.claims.subject == null) {
      errors.add(
        JoseException('id token is missing a `sub` claim.'),
      );
    }
    if (actualUser.parsedIdToken.claims.issuedAt == null) {
      errors.add(
        JoseException('id token is missing an `iat` claim.'),
      );
    }
    OidcUserInfoResponse? userInfoResp;

    if (errors.isEmpty) {
      final userInfoEP = discoveryDocument.userinfoEndpoint;

      if (userInfoEP != null) {
        userInfoResp = await OidcEndpoints.userInfo(
          userInfoEndpoint: userInfoEP,
          accessToken: actualUser.token.accessToken!,
        );

        _logger.info('UserInfo response: ${userInfoResp.src}');
        if (userInfoResp.sub != null &&
            userInfoResp.sub != actualUser.claims.subject) {
          errors.add(
            const OidcException("UserInfo didn't return the same subject."),
          );
        }
      }
    }

    if (errors.isEmpty) {
      //get user info:
      if (userInfoResp != null) {
        actualUser = actualUser.withUserInfo(userInfoResp.src);
      }
      await _saveUser(actualUser);
      return actualUser;
    } else {
      for (final element in errors) {
        _logger.warning(
          'found a JWT, but failed the validation test: $element',
          element,
          StackTrace.current,
        );
      }
      await _cleanUpStore(
        toDelete: {
          OidcStoreNamespace.session,
          OidcStoreNamespace.state,
          OidcStoreNamespace.stateResponse,
          OidcStoreNamespace.secureTokens,
        },
      );
    }
    return null;
  }

  Future<void> _cleanUpStore({
    required Set<OidcStoreNamespace> toDelete,
  }) async {
    for (final element in toDelete) {
      final keys = await store.getAllKeys(element);
      await store.removeMany(element, keys: keys);
    }
  }

  /// The discovery document containing openid configuration.
  OidcProviderMetadata get discoveryDocument {
    _ensureInit();
    return _discoveryDocument!;
  }

  OidcProviderMetadata? _discoveryDocument;

  /// The discovery document Uri containing openid configuration.
  final Uri? discoveryDocumentUri;

  /// First gets the cached discoveryDocument if any
  /// (based on discoveryDocumentUri).
  ///
  /// Then tries to get it from the network.
  Future<void> _ensureDiscoveryDocument() async {
    final uri = discoveryDocumentUri;

    if (_discoveryDocument != null) {
      return;
    }

    if (uri == null) {
      _logAndThrow(
        'Impossible case of no discoveryDocument and no discoveryDocumentUri',
      );
    }
    final key = uri.toString();
    final cachedDocument = await store.get(
      OidcStoreNamespace.discoveryDocument,
      key: key,
    );
    if (cachedDocument != null) {
      try {
        ///try loading the document
        _discoveryDocument = OidcProviderMetadata.fromJson(
          jsonDecode(cachedDocument) as Map<String, dynamic>,
        );
      } catch (e, st) {
        //swallow error.
        //remove the cached document.
        _logger.warning(
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
      _discoveryDocument = await OidcEndpoints.getProviderMetadata(
        uri,
        client: httpClient,
      );
    } catch (e, st) {
      //maybe there is no internet.
      if (_discoveryDocument == null) {
        _logAndThrow(
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
    );
  }

  /// Loads and verifies the tokens.
  Future<void> _loadCachedTokens() async {
    final usedKeys = <String>{
      OidcConstants_Store.currentToken,
      OidcConstants_Store.currentUserAttributes,
    };

    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: usedKeys,
    );
    final rawToken = tokens[OidcConstants_Store.currentToken];
    final rawAttributes = tokens[OidcConstants_Store.currentUserAttributes];
    if (rawToken == null) {
      return;
    }
    final decodedAttributes = rawAttributes == null
        ? null
        : jsonDecode(rawAttributes) as Map<String, dynamic>;
    final decodedToken = jsonDecode(rawToken) as Map<String, dynamic>;
    OidcToken? token;
    try {
      token = OidcToken.fromJson(decodedToken);
    } catch (e) {
      // remove invalid tokens, so that they don't get used again.
      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: usedKeys,
      );
    }
    if (token != null) {
      await _createUserFromToken(
        token: token,
        // nonce is only checked for new tokens.
        nonce: null,
        attributes: decodedAttributes,
      );
    }
  }

  /// Loads the current state, and checks if it has a result.
  ///
  /// if this returns `true`, a result has been found, and there is no need to
  /// load cached tokens.
  Future<bool> _loadStateResult() async {
    final stateKey = await store.getCurrentState();
    if (stateKey == null) {
      return false;
    }
    final stateRaw = await store.getStateData(stateKey);
    if (stateRaw == null) {
      return false;
    }
    final stateResponseRaw = await store.getStateResponseData(stateKey);
    if (stateResponseRaw == null) {
      return false;
    }
    final stateResponseUrl = Uri.tryParse(stateResponseRaw);
    if (stateResponseUrl == null) {
      return false;
    }
    try {
      final stateData = OidcState.fromStorageString(stateRaw);
      switch (stateData) {
        case OidcAuthorizeState():
          final resp = await OidcEndpoints.parseAuthorizeResponse(
            responseUri: stateResponseUrl,
          );
          await _handleSuccessfulAuthResponse(
            response: resp,
            grantType: resp.code == null
                ? OidcConstants_GrantType.implicit
                : OidcConstants_GrantType.authorizationCode,
          );
          return true;
        case OidcEndSessionState():
          final resp =
              OidcEndSessionResponse.fromJson(stateResponseUrl.queryParameters);
          await _handEndSessionResponse(result: resp);
          return true;
        default:
          return false;
      }
    } finally {
      //ALWAYS remove the state response and the state after they are done processing.
      await store.removeStateResponseData(stateKey);
      await store.setStateData(
        state: stateKey,
        stateData: null,
      );
      await store.setCurrentState(null);
    }
  }

  /// returns true if there was a logout request.
  Future<bool> _loadLogoutRequests() async {
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
    //
    final issuer = requestUri.queryParameters[OidcConstants_AuthParameters.iss];
    final sid = requestUri.queryParameters[OidcConstants_JWTClaims.sid];
    if (issuer != null && sid != null) {
      //validate something ?
    }
    await forgetUser();
    return true;
  }

  /// true if [init] has been called with no exceptions.
  bool get didInit => _hasInit;
  bool _hasInit = false;

  final _toDispose = <StreamSubscription<dynamic>>[];

  /// Initializes the user manager, this also gets the [discoveryDocument] if it
  /// wasn't provided.
  Future<void> init() async {
    if (_hasInit) {
      return;
    }
    try {
      _hasInit = true;
      await store.init();
      await _ensureDiscoveryDocument();
      final jwksUri = discoveryDocument.jwksUri;
      if (jwksUri != null) {
        keyStore.addKeySetUrl(jwksUri);
      }
      if (!await _loadLogoutRequests()) {
        //no logout requests.
        if (!await _loadStateResult()) {
          //no state results.
          await _loadCachedTokens();
        }
      }
      final frontChannelLogoutUri = settings.frontChannelLogoutUri;
      if (frontChannelLogoutUri != null) {
        _toDispose.add(
          OidcFlutter.listenToFrontChannelLogoutRequests(
            listenTo: frontChannelLogoutUri,
            options: settings.frontChannelRequestListeningOptions,
          ).listen(_handleFrontChannelLogoutRequest),
        );
      }

      //start listening to token events, if the user enabled them.

      _toDispose
        ..add(_userSubject.listen(
          (value) => _listenToTokenRefreshIfSupported(_tokenEvents, value),
        ))
        ..add(_tokenEvents.expiring.listen(_handleTokenExpiring))
        ..add(_tokenEvents.expired.listen(_handleTokenExpired));
    } catch (e) {
      _hasInit = false;
      rethrow;
    }
  }

  /// Disposes the resources used by this class.
  Future<void> dispose() async {
    await _tokenEvents.dispose();
    await _userSubject.close();
    await Future.wait(_toDispose.map((e) => e.cancel()));
  }

  Future<void> _handleFrontChannelLogoutRequest(
    OidcFrontChannelLogoutIncomingRequest event,
  ) async {
    // wait for a random time, to avoid potential race condition between
    // multiple tabs that try to handle the same request.
    await Future<void>.delayed(Duration(milliseconds: Random().nextInt(500)));
    final request = await store.getCurrentFrontChannelLogoutRequest();
    if (request == null) {
      //someone else handled the request.
      return;
    } else {
      //first quickly remove the request, so that no one else handles it.
      await store.remove(
        OidcStoreNamespace.request,
        key: OidcConstants_Store.frontChannelLogout,
      );
      //forget the user.
      await forgetUser();
    }
  }
}
