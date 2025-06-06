typedef OidcRequestHookExecution<TRequest, TResponse> = Future<TResponse>
    Function(TRequest request);
mixin OidcRequestExecutionHookMixin<TRequest, TResponse> {
  Future<TResponse> modifyExecution(
    TRequest request,
    OidcRequestHookExecution<TRequest, TResponse> defaultExecution,
  );
}
