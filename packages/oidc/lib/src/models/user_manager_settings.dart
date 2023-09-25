import 'package:oidc/oidc.dart';

/// The callback used to determine the `expiring` duration.
typedef OidcRefreshBeforeCallback = Duration? Function(OidcToken token);

/// The default refreshBefore function, which refreshes 1 minute before the token expires.
Duration? defaultRefreshBefore(OidcToken token) {
  return const Duration(minutes: 1);
}

///
class OidcUserManagerSettings {
  /// The default scopes
  static const defaultScopes = ['openid'];

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
    this.sessionStatusCheckInterval = const Duration(seconds: 5),
    this.sessionStatusCheckStopIfErrorReceived = true,
  });

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// whether JWTs are strictly verified.
  final bool strictJwtVerification;

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

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - if `Duration(minutes: 1)` is returned (default), it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// when using the oidc session management specification, how often do you want to ask the server for user status.
  ///
  /// default is 5 seconds.
  final Duration sessionStatusCheckInterval;

  /// if the OP sends us an "error" responses when checking for status, it's pointless to ask for status after it.
  ///
  /// by default this is true.
  final bool sessionStatusCheckStopIfErrorReceived;
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
