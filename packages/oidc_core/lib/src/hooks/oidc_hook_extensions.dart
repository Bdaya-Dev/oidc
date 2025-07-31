import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

import 'oidc_execution_hook_mixin.dart';

/// Extension to provide execute functionality for nullable hooks.
///
/// This extension enables calling execute() on nullable OidcHookMixin instances,
/// providing a clean API that handles null checks automatically.
///
/// **Design Rationale**: The extension operates on nullable types
/// (`OidcHookMixin?`) while the mixin method operates on non-nullable types.
/// This distinction prevents method resolution conflicts:
/// - Non-nullable instances call the mixin method directly
/// - Nullable instances use this extension method
///
/// **Method Resolution**:
/// ```dart
/// OidcHook hook = OidcHook();          // Non-nullable
/// hook.execute(...);                   // → Calls mixin method
///
/// OidcHook? nullableHook = getHook();  // Nullable
/// nullableHook.execute(...);           // → Calls extension method
/// ```
///
/// The extension simply delegates to the mixin method after null checking,
/// ensuring consistent behavior across both nullable and non-nullable usage.
extension OidcHookExtensions<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse>? {
  Future<TResponse> execute({
    required TRequest request,
    required OidcHookExecution<TRequest, TResponse> defaultExecution,
  }) async {
    final hook = this;
    if (hook == null) {
      // If no hook is provided, execute the default execution directly
      return defaultExecution(request);
    }

    // Delegate to the hook's execute method
    return hook.execute(
      request: request,
      defaultExecution: defaultExecution,
    );
  }
}
