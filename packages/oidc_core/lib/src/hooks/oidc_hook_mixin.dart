import 'oidc_execution_hook_mixin.dart';

mixin OidcHookMixin<TRequest, TResponse> {
  /// Executes the hook with request transformation and response modification.
  ///
  /// This is the main entry point for hook execution. Implementations must
  /// provide their complete execution logic, including any request/response
  /// modifications and execution control.
  ///
  /// **Design Note**: This method is abstract to enable proper polymorphism
  /// and prevent the infinite recursion issues that occurred with extension
  /// methods. Each implementation has full control over its execution strategy.
  ///
  /// **Implementation Guidelines**:
  /// - Apply request modifications before calling defaultExecution
  /// - Handle execution control if needed (or delegate to defaultExecution)
  /// - Apply response modifications before returning
  ///
  /// **Example Implementation**:
  /// ```dart
  /// Future<TResponse> execute({...}) async {
  ///   final modifiedRequest = await modifyRequest(request);
  ///   final response = await defaultExecution(modifiedRequest);
  ///   return await modifyResponse(response);
  /// }
  /// ```
  Future<TResponse> execute({
    required TRequest request,
    required OidcHookExecution<TRequest, TResponse> defaultExecution,
  });
}

mixin OidcRequestModifierHookMixin<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse> {
  Future<TRequest> modifyRequest(TRequest request);
}

mixin OidcResponseModifierHookMixin<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse> {
  Future<TResponse> modifyResponse(TResponse response);
}
