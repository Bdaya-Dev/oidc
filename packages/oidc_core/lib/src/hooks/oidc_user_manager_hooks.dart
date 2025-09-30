import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

class OidcTokenHookRequest {
  OidcTokenHookRequest({
    required this.metadata,
    required this.tokenEndpoint,
    required this.request,
    required this.credentials,
    required this.headers,
    required this.options,
    required this.client,
  });
  OidcProviderMetadata metadata;
  Uri tokenEndpoint;
  OidcTokenRequest request;
  OidcClientAuthentication? credentials;
  Map<String, String>? headers;
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

class OidcRevocationHookRequest {
  OidcRevocationHookRequest({
    required this.metadata,
    required this.request,
    required this.options,
    required this.revocationEndpoint,
    required this.client,
    required this.credentials,
    required this.headers,
  });

  Uri revocationEndpoint;
  OidcProviderMetadata metadata;
  OidcRevocationRequest request;
  OidcPlatformSpecificOptions options;
  Client? client;
  OidcClientAuthentication? credentials;
  Map<String, String>? headers;
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
  OidcHookMixin<OidcRevocationHookRequest, OidcRevocationResponse?>? revocation;

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
    required OidcHookExecution<
      OidcAuthorizationHookRequest,
      OidcAuthorizeResponse?
    >
    defaultExecution,
  }) {
    return authorization.execute(
      request: request,
      defaultExecution: defaultExecution,
    );
  }

  Future<OidcRevocationResponse?> executeRevocation({
    required OidcRevocationHookRequest request,
    required OidcHookExecution<
      OidcRevocationHookRequest,
      OidcRevocationResponse?
    >
    defaultExecution,
  }) {
    return revocation.execute(
      request: request,
      defaultExecution: defaultExecution,
    );
  }
}
