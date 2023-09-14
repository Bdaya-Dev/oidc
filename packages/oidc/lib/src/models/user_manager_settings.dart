import 'package:oidc/oidc.dart';

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
    this.expiryTolerance = Duration.zero,
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.refreshBefore = defaultRefreshBefore,
  });

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

  /// see [OidcEndSessionRequest.postLogoutRedirectUri].
  final Uri? postLogoutRedirectUri;

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

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;
}
