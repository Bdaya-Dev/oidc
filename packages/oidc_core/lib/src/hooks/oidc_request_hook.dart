typedef OidcRequestHookExecution<TRequest, TResponse> = Future<TResponse>
    Function(TRequest request);

class OidcRequestHook<TRequest, TResponse> {
  OidcRequestHook({
    this.modifyRequest,
    this.modifyExecution,
    this.modifyResponse,
  });

  Future<TRequest> Function(TRequest request)? modifyRequest;
  Future<TResponse> Function(
    TRequest response,
    OidcRequestHookExecution<TRequest, TResponse> defaultExecution,
  )? modifyExecution;
  Future<TResponse> Function(TResponse response)? modifyResponse;
}
