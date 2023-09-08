import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:logging/logging.dart';
import 'package:oidc/src/managers/utils.dart';
import 'package:oidc/src/models/authorize_request.dart';
import 'package:oidc/src/models/user.dart';
import 'package:oidc/src/models/user_manager_settings.dart';
import 'package:oidc/src/models/user_metadata.dart';
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
    OidcAuthorizePlatformSpecificOptions? options,
  }) async {
    _ensureInit();
    await _cleanUpStore(toDelete: {
      OidcStoreNamespace.session,
      OidcStoreNamespace.state,
      OidcStoreNamespace.secureTokens,
    });
    final doc = discoveryDocument;
    options ??= const OidcAuthorizePlatformSpecificOptions();
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
      extraTokenParameters: extraTokenParameters,
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
    );
    final request = await Oidc.prepareAuthorizationCodeFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
      options: options,
    );

    final response = await Oidc.getAuthorizationResponse(
      metadata: discoveryDocument,
      request: request,
      store: store,
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
    OidcAuthorizePlatformSpecificOptions? options,
  }) async {
    _ensureInit();
    final doc = discoveryDocument;
    options ??= const OidcAuthorizePlatformSpecificOptions();
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
    );
    final request = await Oidc.prepareImplicitCodeFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
      options: options,
    );

    final response = await Oidc.getAuthorizationResponse(
      metadata: discoveryDocument,
      request: request,
      store: store,
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

  /// Logs out the current user and clears the cache.
  Future<void> logout() async {
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    await _cleanUpStore(toDelete: {
      OidcStoreNamespace.state,
      OidcStoreNamespace.session,
      OidcStoreNamespace.secureTokens,
    });
    _userSubject.add(null);
    final accessToken = currentUser.metadata.accessToken;
    if (accessToken != null) {
      final revokeEP = discoveryDocument.revocationEndpoint;
      if (revokeEP != null) {
        //
        try {
          await OidcInternalUtilities.sendWithClient(
            client: httpClient,
            request: http.Request(
              'POST',
              revokeEP.replace(queryParameters: {
                ...revokeEP.queryParameters,
                'token': accessToken,
              }),
            ),
          );
        } catch (e) {
          //do nothing
        }
      }
    }
  }

  Future<OidcUser?> _handleSuccessfulAuthResponse({
    required OidcAuthorizeResponse response,
    required String grantType,
  }) async {
    final receivedStateKey = response.state;
    if (receivedStateKey == null) {
      throw const OidcException(
        "Server didn't return state parameter, even though it was sent.",
      );
    }
    final currentStateKey = await store.get(
      OidcStoreNamespace.session,
      key: OidcConstants_AuthParameters.state,
    );
    if (currentStateKey != receivedStateKey) {
      throw const OidcException(
        'Server sent an older or different state parameter.',
      );
    }

    final stateDataStr = await store.get(
      OidcStoreNamespace.state,
      key: receivedStateKey,
    );
    if (stateDataStr == null) {
      throw const OidcException(
        "Internal error, the session state wasn't cleared after the state was deleted.",
      );
    }
    final stateData = OidcAuthorizeState.fromStorageString(stateDataStr);
    if (grantType == OidcConstants_GrantType.implicit) {
      //
      final implicitTokenResponse = OidcTokenResponse.fromJson(response.src);
      if (implicitTokenResponse.accessToken != null ||
          implicitTokenResponse.idToken != null) {
        return _handleTokenResponse(
          response: implicitTokenResponse,
          nonce: stateData.nonce,
          refDate: DateTime.now().toUtc(),
        );
      }
    }
    final doc = discoveryDocument;
    final tokenEndPoint = doc.tokenEndpoint;
    if (tokenEndPoint == null) {
      throw const OidcException(
        "This provider doesn't provide a token endpoint",
      );
    }
    final code = response.code;
    if (code == null) {
      throw const OidcException(
        "Server didn't send code even though the authorization code flow was used.",
      );
    }
    final tokenResp = await OidcEndpoints.token(
      tokenEndpoint: tokenEndPoint,
      credentials: clientCredentials,
      request: OidcTokenRequest.authorizationCode(
        redirectUri: stateData.redirectUri,
        codeVerifier: response.codeVerifier ?? stateData.codeVerifier,
        extra: stateData.extraTokenParams,
        code: code,
        clientId: clientCredentials.clientId,
      ),
      client: httpClient,
    );
    return _handleTokenResponse(
      response: tokenResp,
      nonce: stateData.nonce,
      refDate: DateTime.now().toUtc(),
    );
  }

  Future<OidcUser?> _handleTokenResponse({
    required OidcTokenResponse response,
    required String? nonce,
    required DateTime? refDate,
  }) async {
    refDate ??= DateTime.now().toUtc();
    final idToken = response.idToken;
    if (idToken == null) {
      throw const OidcException(
        "Server didn't return the id_token.",
      );
    }
    final metadataObject = OidcUserMetadata.fromJson({
      ...response.src,
      OidcConstants_Store.expiresInReferenceDate: refDate,
    });
    final user = await OidcUser.fromIdToken(
      idToken: idToken,
      metadata: metadataObject,
      allowedAlgorithms:
          discoveryDocument.tokenEndpointAuthSigningAlgValuesSupported,
      keystore: keyStore,
    );
    final idTokenNonce =
        user.parsedToken.claims[OidcConstants_AuthParameters.nonce] as String?;
    if (nonce != null && idTokenNonce != nonce) {
      throw const OidcException(
        'Server returned a wrong id_token nonce, might be a replay attack.',
      );
    }
    return _handleUser(user);
  }

  Future<OidcUser?> _handleUser(OidcUser user) async {
    final errors = user.parsedToken.claims
        .validate(
          clientId: clientCredentials.clientId,
          issuer: discoveryDocument.issuer,
          expiryTolerance: settings.expiryTolerance,
        )
        .toList();
    if (errors.isEmpty) {
      await store.setMany(
        OidcStoreNamespace.secureTokens,
        values: {
          OidcConstants_AuthParameters.idToken: user.idToken,
          OidcConstants_Store.currentUserMetadata:
              jsonEncode(user.metadata.toJson()),
        },
      );
      _userSubject.add(user);
      return user;
    } else {
      for (final element in errors) {
        _logger.fine(
          'found a JWT, but failed the validation test',
          element,
          StackTrace.current,
        );
      }
      await _cleanUpStore(
        toDelete: {
          OidcStoreNamespace.session,
          OidcStoreNamespace.state,
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
  /// Then trys to get it from the network.
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
      _discoveryDocument = await OidcEndpoints.getProviderMetadata(uri);
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

  /// Loads and verifies the idToken, accessToken and refreshToken
  Future<void> _loadCachedTokens() async {
    final usedKeys = <String>{
      OidcConstants_AuthParameters.idToken,
      OidcConstants_Store.currentUserMetadata,
    };

    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: usedKeys,
    );
    final idToken = tokens[OidcConstants_AuthParameters.idToken];
    final rawMetadata = tokens[OidcConstants_Store.currentUserMetadata];
    if (idToken == null || rawMetadata == null) {
      return;
    }
    final decodedMetadata = jsonDecode(rawMetadata) as Map<String, dynamic>;
    // final parsedMetadata = OidcUserMetadata.fromJson(decodedMetadata);
    OidcTokenResponse? tokenResponse;
    try {
      tokenResponse = OidcTokenResponse.fromJson({
        OidcConstants_AuthParameters.idToken: idToken,
        ...decodedMetadata,
      });
    } catch (e) {
      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: usedKeys,
      );
    }
    if (tokenResponse != null) {
      await _handleTokenResponse(
        response: tokenResponse,
        nonce: null,
        refDate: OidcInternalUtilities.dateTimeFromJson(
          tokens[OidcConstants_Store.expiresInReferenceDate],
        ),
      );
    }
  }

  Future<void> _loadStateResult() async {
    final stateKey = await store.get(
      OidcStoreNamespace.session,
      key: OidcConstants_AuthParameters.state,
    );
    if (stateKey == null) {
      return;
    }
    final stateResponseRaw = await store.get(
      OidcStoreNamespace.state,
      key: '$stateKey-response',
    );
    if (stateResponseRaw == null) {
      return;
    }
    final stateResponseUrl = Uri.tryParse(stateResponseRaw);
    if (stateResponseUrl == null) {
      return;
    }
    final resp = await OidcEndpoints.parseAuthorizeResponse(
      responseUri: stateResponseUrl,
      store: store,
    );
    if (resp == null) {
      return;
    }
    await _handleSuccessfulAuthResponse(
      response: resp,
      grantType: resp.code == null
          ? OidcConstants_GrantType.implicit
          : OidcConstants_GrantType.authorizationCode,
    );
  }

  /// true if [init] has been called with no exceptions.
  bool get didInit => _hasInit;
  bool _hasInit = false;

  /// Initializes the user manager, this also gets the [discoveryDocument] if it
  /// wasn't provided.
  Future<void> init() async {
    try {
      _hasInit = true;
      await store.init();
      await _ensureDiscoveryDocument();
      final jwksUri = discoveryDocument.jwksUri;
      if (jwksUri != null) {
        keyStore.addKeySetUrl(jwksUri);
      }
      //load cached tokens if they exist.
      await _loadCachedTokens();
      //get the authorization response
      if (currentUser == null) {
        await _loadStateResult();
      }
    } catch (e) {
      _hasInit = false;
      rethrow;
    }
  }

  /// Disposes the resources used by this class.
  Future<void> dispose() async {
    await _userSubject.close();
  }
}
