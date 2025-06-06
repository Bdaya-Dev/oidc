typedef OidcHookExecution<TRequest, TResponse> = Future<TResponse> Function(
    TRequest request);
mixin OidcExecutionHookMixin<TRequest, TResponse> {
  Future<TResponse> modifyExecution(
    TRequest request,
    OidcHookExecution<TRequest, TResponse> defaultExecution,
  );
}
