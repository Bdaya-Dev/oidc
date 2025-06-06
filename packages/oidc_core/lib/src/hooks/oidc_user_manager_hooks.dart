import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

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
    this.authorization,
  });
  OidcHookMixin<OidcTokenHookRequest, OidcTokenResponse>? token;
  OidcHookMixin<OidcAuthorizationHookRequest, OidcAuthorizeResponse?>?
      authorization;

  static Future<TResponse> execute<TRequest, TResponse>({
    required TRequest request,
    required OidcRequestHookExecution<TRequest, TResponse> defaultExecution,
    required OidcHookMixin<TRequest, TResponse>? hook,
  }) async {
    if (hook == null) {
      return defaultExecution(request);
    } else {
      if (hook case OidcRequestModifierHookMixin<TRequest, TResponse>()) {
        request = await hook.modifyRequest(request);
      }
      TResponse response;
      if (hook
          case final OidcRequestExecutionHookMixin<TRequest, TResponse>
              executionHookMixin) {
        response =
            await executionHookMixin.modifyExecution(request, defaultExecution);
      } else {
        response = await defaultExecution(request);
      }
      if (hook case OidcResponseModifierHookMixin<TRequest, TResponse>()) {
        response = await hook.modifyResponse(response);
      }
      return response;
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
