import 'package:oidc_core/oidc_core.dart';

/// The callback used to determine the `expiring` duration.
typedef OidcRefreshBeforeCallback = Duration? Function(OidcToken token);

/// The default refreshBefore function, which refreshes 1 minute before the token expires.
Duration? defaultRefreshBefore(OidcToken token) {
  return const Duration(minutes: 1);
}

/// The callback used to determine the retry delay for offline mode refresh attempts.
typedef OidcOfflineRefreshRetryDelayCallback =
    Duration Function(
      int consecutiveFailures,
    );

/// Default threshold for emitting repeat refresh failure warnings.

/// The default retry delay function with exponential backoff.
/// Returns delays of: 30s, 1m, 2m, 4m, 5m (capped at 5 minutes).
Duration defaultOfflineRefreshRetryDelay(int consecutiveFailures) {
  // Exponential backoff: 30s, 1m, 2m, 4m, 5m (capped)
  final baseDelay = const Duration(seconds: 30);
  final exponentialDelay = baseDelay * (1 << (consecutiveFailures - 1));
  const maxDelay = Duration(minutes: 5);

  return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
}

///
class OidcUserManagerSettings {
  ///
  const OidcUserManagerSettings({
    required this.redirectUri,
    this.uiLocales,
    this.extraTokenHeaders,
    this.scope = defaultScopes,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
    this.expiryTolerance = const Duration(minutes: 1),
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.frontChannelLogoutUri,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
    this.refreshBefore = defaultRefreshBefore,
    this.strictJwtVerification = false,
    this.getExpiresIn,
    this.sessionManagementSettings = const OidcSessionManagementSettings(),
    this.getIdToken,
    this.supportOfflineAuth = false,
    this.offlineRefreshRetryDelay = defaultOfflineRefreshRetryDelay,
    this.offlineRepeatFailureWarningThreshold = 3,
    this.hooks,
    this.extraRevocationParameters,
    this.extraRevocationHeaders,
  });

  /// The default scopes
  static const defaultScopes = ['openid'];

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// whether JWTs are strictly verified.
  ///
  /// If set to true, the library will throw an exception if a JWT is invalid.
  final bool strictJwtVerification;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// The retry delay calculation for offline mode refresh attempts.
  ///
  /// This callback receives the number of consecutive refresh failures and
  /// returns the duration to wait before the next retry attempt.
  ///
  /// The default implementation uses exponential backoff:
  /// - 1st failure: 30 seconds
  /// - 2nd failure: 1 minute
  /// - 3rd failure: 2 minutes
  /// - 4th failure: 4 minutes
  /// - 5th+ failure: 5 minutes (capped)
  ///
  /// This helps reduce battery usage and server load during extended outages.
  final OidcOfflineRefreshRetryDelayCallback offlineRefreshRetryDelay;

  /// The number of consecutive refresh failures before emitting a warning.
  ///
  /// Set to `0` or a negative value to disable repeat failure warnings.
  final int offlineRepeatFailureWarningThreshold;

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

  /// see [OidcEndSessionRequest.postLogoutRedirectUri].
  final Uri? postLogoutRedirectUri;

  /// the uri of the front channel logout flow.
  /// this Uri MUST be registered with the OP first.
  /// the OP will call this Uri when it wants to logout the user.
  final Uri? frontChannelLogoutUri;

  /// The options to use when listening to platform channels.
  ///
  /// [frontChannelLogoutUri] must be set for this to work.
  final OidcFrontChannelRequestListeningOptions
  frontChannelRequestListeningOptions;

  /// see [OidcAuthorizeRequest.scope].
  final List<String> scope;

  /// see [OidcAuthorizeRequest.prompt].
  final List<String> prompt;

  /// see [OidcAuthorizeRequest.display].
  final String? display;

  /// see [OidcAuthorizeRequest.uiLocales].
  final List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.acrValues].
  final List<String>? acrValues;

  /// see [OidcAuthorizeRequest.maxAge]
  final Duration? maxAge;

  /// see [OidcAuthorizeRequest.extra]
  final Map<String, dynamic>? extraAuthenticationParameters;

  /// see [OidcTokenRequest.extra]
  final Map<String, String>? extraTokenHeaders;

  /// see [OidcTokenRequest.extra]
  final Map<String, dynamic>? extraTokenParameters;

  /// see [OidcRevocationRequest.extra]
  final Map<String, dynamic>? extraRevocationParameters;

  /// Extra headers to send with the revocation request.
  final Map<String, String>? extraRevocationHeaders;

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// Settings related to the session management spec.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - (default) if `Duration(minutes: 1)` is returned, it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// pass this function to control how an `id_token` is fetched from a
  /// token response.
  ///
  /// This can be used to trick the user manager into using a JWT `access_token`
  /// as an `id_token` for example.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// Customized hooks to modify the user manager behavior.
  final OidcUserManagerHooks? hooks;
}

///
class OidcUserInfoSettings {
  ///
  const OidcUserInfoSettings({
    this.accessTokenLocation =
        OidcUserInfoAccessTokenLocations.authorizationHeader,
    this.requestMethod = OidcConstants_RequestMethod.get,
    this.sendUserInfoRequest = true,
    this.followDistributedClaims = true,
    this.getAccessTokenForDistributedSource,
  });

  /// Where to put the access token.
  final OidcUserInfoAccessTokenLocations accessTokenLocation;

  /// Request method to use (POST/GET).
  final String requestMethod;

  /// Whether to send the user info request.
  ///
  /// true by default.
  final bool sendUserInfoRequest;

  /// Whether to try to follow and resolve Distributed Claims or not.
  final bool followDistributedClaims;

  /// this function gets called whenever there is an endpoint with no access token,
  /// to try and get the access token.
  final Future<String?> Function(String, Uri)?
  getAccessTokenForDistributedSource;
}

///
class OidcSessionManagementSettings {
  ///
  const OidcSessionManagementSettings({
    this.enabled = false,
    this.interval = const Duration(seconds: 5),
    this.stopIfErrorReceived = true,
  });

  /// pass `true` if you want to enable the session checking.
  ///
  /// default is false.
  final bool enabled;

  /// how often do you want to ask the server for user status.
  ///
  /// default is 5 seconds.
  final Duration interval;

  /// if the OP sends us an "error" responses when checking for status, it's pointless to ask for status after it.
  ///
  /// by default this is true.
  final bool stopIfErrorReceived;
}
