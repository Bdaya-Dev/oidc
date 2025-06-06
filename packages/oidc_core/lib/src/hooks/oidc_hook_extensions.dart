import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

import 'oidc_execution_hook_mixin.dart';

Future<TResponse> oidcExecuteHook<TRequest, TResponse>({
  required TRequest request,
  required OidcHookExecution<TRequest, TResponse> defaultExecution,
  required OidcHookMixin<TRequest, TResponse>? hook,
}) {
  if (hook == null) {
    // If no hook is provided, execute the default execution directly.
    // This is a fallback to ensure that the request can still be processed.
    return defaultExecution(request);
  }
  return hook.execute(
    request: request,
    defaultExecution: defaultExecution,
  );
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
