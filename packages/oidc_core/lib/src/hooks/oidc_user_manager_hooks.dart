import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

class OidcTokenHookRequest {
  OidcTokenHookRequest({
    required this.metadata,
    required this.tokenEndpoint,
    required this.request,
    this.credentials,
    this.headers,
    this.extraBodyFields,
    this.options,
    this.client,
  });
  OidcProviderMetadata metadata;
  Uri tokenEndpoint;
  OidcTokenRequest request;
  OidcClientAuthentication? credentials;
  Map<String, String>? headers;
  Map<String, dynamic>? extraBodyFields;
  OidcPlatformSpecificOptions? options;
  Client? client;
}

class OidcAuthorizationHookRequest {
  OidcAuthorizationHookRequest({
    required this.metadata,
    required this.request,
    required this.options,
    required this.preparationResult,
  });
  OidcProviderMetadata metadata;
  OidcAuthorizeRequest request;
  OidcPlatformSpecificOptions options;
  Map<String, dynamic> preparationResult;
}

/// A collection of hooks for the OIDC User Manager.
class OidcUserManagerHooks {
  OidcUserManagerHooks({
    this.token,
    this.authorization,
  });
  OidcHookMixin<OidcTokenHookRequest, OidcTokenResponse>? token;
  OidcHookMixin<OidcAuthorizationHookRequest, OidcAuthorizeResponse?>?
      authorization;

  Future<OidcTokenResponse> executeToken({
    required OidcTokenHookRequest request,
    required OidcHookExecution<OidcTokenHookRequest, OidcTokenResponse>
        defaultExecution,
  }) {
    return token.execute(
      request: request,
      defaultExecution: defaultExecution,
    );
  }

  Future<OidcAuthorizeResponse?> executeAuthorization({
    required OidcAuthorizationHookRequest request,
    required OidcHookExecution<OidcAuthorizationHookRequest,
            OidcAuthorizeResponse?>
        defaultExecution,
  }) {
    return authorization.execute(
      request: request,
      defaultExecution: defaultExecution,
    );
  }
}
