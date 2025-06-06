import 'oidc_execution_hook_mixin.dart';
import 'oidc_hook_mixin.dart';

abstract class OidcHookBase<TRequest, TResponse>
    with
        OidcHookMixin<TRequest, TResponse>,
        OidcRequestModifierHookMixin<TRequest, TResponse>,
        OidcResponseModifierHookMixin<TRequest, TResponse>,
        OidcExecutionHookMixin<TRequest, TResponse> {}
