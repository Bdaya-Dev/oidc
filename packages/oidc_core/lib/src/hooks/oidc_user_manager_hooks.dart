import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';

/// A request to the OIDC Token endpoint.
typedef OidcTokenHookRequest = ({
  OidcProviderMetadata metadata,
  Uri tokenEndpoint,
  OidcTokenRequest request,
  OidcClientAuthentication? credentials,
  Map<String, String>? headers,
  Map<String, dynamic>? extraBodyFields,
  OidcPlatformSpecificOptions options,
  Client? client,
});

typedef OidcAuthorizationHookRequest = ({
  OidcProviderMetadata metadata,
  OidcAuthorizeRequest request,
  OidcPlatformSpecificOptions options,
  Map<String, dynamic> preparationResult,
});

/// A collection of hooks for the OIDC User Manager.
class OidcUserManagerHooks {
  OidcUserManagerHooks({
    this.token,
  });
  OidcRequestHook<OidcTokenHookRequest, OidcTokenResponse>? token;
  OidcRequestHook<OidcAuthorizationHookRequest, OidcAuthorizeResponse?>?
      authorization;

  static Future<TResponse> execute<TRequest, TResponse>({
    required TRequest request,
    required OidcRequestHookExecution<TRequest, TResponse> defaultExecution,
    required OidcRequestHook<TRequest, TResponse>? hook,
  }) async {
    if (hook == null) {
      return defaultExecution(request);
    } else {
      var finalRequest = request;
      final requestModifier = hook.modifyRequest;
      if (requestModifier != null) {
        finalRequest = await requestModifier(finalRequest);
      }
      final executionModifier = hook.modifyExecution;
      if (executionModifier != null) {
        return executionModifier(finalRequest, defaultExecution);
      }
      return defaultExecution(finalRequest);
    }
  }

  Future<OidcTokenResponse> executeToken({
    required OidcTokenHookRequest request,
    required OidcRequestHookExecution<OidcTokenHookRequest, OidcTokenResponse>
        defaultExecution,
  }) {
    return execute(
      request: request,
      defaultExecution: defaultExecution,
      hook: token,
    );
  }

  Future<OidcAuthorizeResponse?> executeAuthorization({
    required OidcAuthorizationHookRequest request,
    required OidcRequestHookExecution<OidcAuthorizationHookRequest,
            OidcAuthorizeResponse?>
        defaultExecution,
  }) {
    return execute(
      request: request,
      defaultExecution: defaultExecution,
      hook: authorization,
    );
  }
}
