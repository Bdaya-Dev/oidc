import 'package:oidc_core/src/hooks/oidc_execution_hook_mixin.dart';

import 'oidc_hook_mixin.dart';

/// A group of OIDC hooks that can be executed together.
///
/// This class combines multiple OIDC hooks.
///
/// Type parameters:
/// - [TRequest]: The type of the request object
/// - [TResponse]: The type of the response object
///
/// Example usage:
/// ```dart
/// final hookGroup = OidcHookGroup<MyRequest, MyResponse>(
///   hooks: [hook1, hook2, hook3],
///   executionHook: myExecutionHook,
/// );
/// ```
class OidcHookGroup<TRequest, TResponse>
    with
        OidcHookMixin<TRequest, TResponse>,
        OidcResponseModifierHookMixin<TRequest, TResponse>,
        OidcRequestModifierHookMixin<TRequest, TResponse>,
        OidcExecutionHookMixin<TRequest, TResponse> {
  OidcHookGroup({
    required this.hooks,
    this.executionHook,
  });

  List<OidcHookMixin<TRequest, TResponse>> hooks;
  OidcExecutionHookMixin<TRequest, TResponse>? executionHook;

  @override
  Future<TRequest> modifyRequest(TRequest request) async {
    var modifiedRequest = request;
    for (final hook in hooks) {
      if (hook
          case final OidcRequestModifierHookMixin<TRequest, TResponse>
              requestModifierHook) {
        modifiedRequest =
            await requestModifierHook.modifyRequest(modifiedRequest);
      }
    }
    return modifiedRequest;
  }

  @override
  Future<TResponse> modifyResponse(TResponse response) async {
    var modifiedResponse = response;
    for (final hook in hooks) {
      if (hook
          case final OidcResponseModifierHookMixin<TRequest, TResponse>
              responseModifierHook) {
        modifiedResponse =
            await responseModifierHook.modifyResponse(modifiedResponse);
      }
    }
    return modifiedResponse;
  }

  @override
  Future<TResponse> modifyExecution(TRequest request,
      OidcHookExecution<TRequest, TResponse> defaultExecution) {
    final executionHook = this.executionHook;
    if (executionHook != null) {
      return executionHook.modifyExecution(request, defaultExecution);
    } else {
      return defaultExecution(request);
    }
  }
}
