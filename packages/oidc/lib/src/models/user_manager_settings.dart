import 'package:oidc_core/oidc_core.dart';

///
class UserManagerSettings {
  /// The default scopes
  static const defaultScopes = ['openid'];

  ///
  const UserManagerSettings({
    required this.redirectUri,
    this.uiLocales,
    this.scope = defaultScopes,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
  });

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

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
}
