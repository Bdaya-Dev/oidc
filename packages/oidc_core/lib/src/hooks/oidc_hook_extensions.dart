import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

import 'oidc_execution_hook_mixin.dart';

Future<TResponse> oidcExecuteHook<TRequest, TResponse>({
  required TRequest request,
  required OidcHookExecution<TRequest, TResponse> defaultExecution,
  required OidcHookMixin<TRequest, TResponse>? hook,
}) async {
  if (hook == null) {
    // If no hook is provided, execute the default execution directly.
    // This is a fallback to ensure that the request can still be processed.
    return defaultExecution(request);
  }
  if (hook
      case final OidcRequestModifierHookMixin<TRequest, TResponse>
          hookModifyRequest) {
    request = await hookModifyRequest.modifyRequest(request);
  }
  TResponse response;
  if (hook case final OidcExecutionHookMixin<TRequest, TResponse> hookExecute) {
    response = await hookExecute.modifyExecution(request, defaultExecution);
  } else {
    response = await defaultExecution(request);
  }
  if (hook
      case final OidcResponseModifierHookMixin<TRequest, TResponse>
          hookModifyResponse) {
    response = await hookModifyResponse.modifyResponse(response);
  }
  return response;
}

extension OidcHookExtensions<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse>? {
  Future<TResponse> execute({
    required TRequest request,
    required OidcHookExecution<TRequest, TResponse> defaultExecution,
  }) async {
    return oidcExecuteHook<TRequest, TResponse>(
      request: request,
      defaultExecution: defaultExecution,
      hook: this,
    );
  }
}
