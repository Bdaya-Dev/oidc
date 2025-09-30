import 'oidc_execution_hook_mixin.dart';
import 'oidc_hook_base.dart';

class OidcHook<TRequest, TResponse> extends OidcHookBase<TRequest, TResponse> {
  OidcHook({
    Future<TRequest> Function(TRequest request)? modifyRequest,
    Future<TResponse> Function(
      TRequest response,
      OidcHookExecution<TRequest, TResponse> defaultExecution,
    )?
    modifyExecution,
    Future<TResponse> Function(TResponse response)? modifyResponse,
  }) : modifyRequestFunction = modifyRequest,
       modifyExecutionFunction = modifyExecution,
       modifyResponseFunction = modifyResponse;

  Future<TRequest> Function(TRequest request)? modifyRequestFunction;
  Future<TResponse> Function(
    TRequest response,
    OidcHookExecution<TRequest, TResponse> defaultExecution,
  )?
  modifyExecutionFunction;
  Future<TResponse> Function(TResponse response)? modifyResponseFunction;

  @override
  Future<TResponse> modifyExecution(
    TRequest request,
    OidcHookExecution<TRequest, TResponse> defaultExecution,
  ) {
    final modifyExecutionFunction = this.modifyExecutionFunction;
    if (modifyExecutionFunction != null) {
      return modifyExecutionFunction(request, defaultExecution);
    }
    return defaultExecution(request);
  }

  @override
  Future<TRequest> modifyRequest(TRequest request) {
    final modifyRequestFunction = this.modifyRequestFunction;
    if (modifyRequestFunction != null) {
      return modifyRequestFunction(request);
    }
    return Future.value(request);
  }

  @override
  Future<TResponse> modifyResponse(TResponse response) {
    final modifyResponseFunction = this.modifyResponseFunction;
    if (modifyResponseFunction != null) {
      return modifyResponseFunction(response);
    }
    return Future.value(response);
  }
}
