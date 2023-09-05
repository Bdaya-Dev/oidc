import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:oidc/src/managers/utils.dart';
import 'package:oidc/src/models/code_flow_parameters.dart';
import 'package:oidc/src/models/id_token_verification_options.dart';
import 'package:oidc/src/models/user.dart';
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
    this.verificationOptions,
  })  : discoveryDocumentUri = null,
        _discoveryDocument = discoveryDocument;

  /// Create a new UserManager that delays getting the discovery document until
  /// [init] is called.
  OidcUserManager.lazy({
    required Uri this.discoveryDocumentUri,
    required this.clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    this.verificationOptions,
  });

  /// The client authentication information.
  final OidcClientAuthentication clientCredentials;

  /// The http client to use when sending requests
  final http.Client? httpClient;

  /// The store responsible for setting/getting cached values.
  final OidcStore store;

  /// The id_token verification options.
  final OidcIdTokenVerificationOptions? verificationOptions;

  /// The settings used in this manager.
  final UserManagerSettings settings;

  final _userSubject = BehaviorSubject<OidcUser?>.seeded(null);

  /// Gets a stream that reflects the current data of the user.
  Stream<OidcUser?> userChanges() => _userSubject.stream;

  void _ensureInit() {
    if (!_hasInit) {
      _logAndThrow(
        "discoveryDocument hasn't been fetched yet, "
        'please call init() first.',
      );
    }
  }

  bool canAuthorizeCodeFlow() {
    _ensureInit();
    final endpoint = discoveryDocument.authorizationEndpoint;

    return endpoint != null;
  }

  Future<void> loginAuthorizationCodeFlow() async {
    _ensureInit();
    final response = await Oidc.getAuthorizationResponse(
      metadata: discoveryDocument,
      request: OidcAuthorizeRequest(
        responseType: [OidcConstants_AuthorizeRequest_ResponseType.code],
        clientId: clientCredentials.clientId,
        redirectUri: settings.redirectUri,
        scope: [
          'openid',
        ],
      ),
      store: store,
      options: const OidcAuthorizePlatformOptions(
        web: OidcAuthorizePlatformOptions_Web(),
      ),
    );
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
      _discoveryDocument = await OidcUtils.getProviderMetadata(uri);
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
      OidcConstants_Store.idToken,
      OidcConstants_Store.accessToken,
      OidcConstants_Store.refreshToken,
    };
    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: usedKeys,
    );
    final idToken = tokens[OidcConstants_Store.idToken];

    final verificationOptions = this.verificationOptions;
    if (idToken != null) {
      try {
        final accessToken = tokens[OidcConstants_Store.accessToken];
        final refreshToken = tokens[OidcConstants_Store.refreshToken];
        final user = await OidcUser.fromIdToken(
          idToken: idToken,
          metadata: {
            if (accessToken != null)
              OidcConstants_Store.accessToken: accessToken,
            if (refreshToken != null)
              OidcConstants_Store.refreshToken: refreshToken,
          },
          verificationOptions: verificationOptions,
        );

        final errors = verificationOptions == null
            ? <Exception>[]
            : user.parsedToken.claims
                .validate(
                  clientId: verificationOptions.validateAudience
                      ? clientCredentials.clientId
                      : null,
                  issuer: verificationOptions.validateIssuer
                      ? discoveryDocument.issuer
                      : null,
                  expiryTolerance: verificationOptions.expiryTolerance,
                )
                .toList();
        if (errors.isEmpty) {
          _logger.finer('found a JWT and validated it');
          _userSubject.add(user);
        } else {
          for (final element in errors) {
            _logger.fine(
              'found a JWT, but failed the validation test',
              element,
              StackTrace.current,
            );
          }
          await store.removeMany(
            OidcStoreNamespace.secureTokens,
            keys: usedKeys,
          );
        }
      } catch (e) {
        // swallow error
        await store.removeMany(
          OidcStoreNamespace.secureTokens,
          keys: usedKeys,
        );
      }
    }
  }

  /// true if [init] has been called with no exceptions.
  bool get didInit => _hasInit;
  bool _hasInit = false;

  /// Initializes the user manager, this also gets the [discoveryDocument] if it
  /// wasn't provided.
  Future<void> init() async {
    try {
      _hasInit = true;
      await _ensureDiscoveryDocument();
      //load cached tokens if they exist.
      await _loadCachedTokens();
      //get the authorization response
      // await OidcPlatform.instance.getAuthorizationResponse();
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
