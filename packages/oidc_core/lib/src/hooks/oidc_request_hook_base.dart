import 'package:oidc_core/src/hooks/oidc_request_response_hook_mixin.dart';

import 'oidc_hook_mixin.dart';
import 'oidc_request_execution_hook_mixin.dart';

abstract class OidcRequestHookBase<TRequest, TResponse>
    with
        OidcHookMixin<TRequest, TResponse>,
        OidcRequestModifierHookMixin<TRequest, TResponse>,
        OidcResponseModifierHookMixin<TRequest, TResponse>,
        OidcRequestExecutionHookMixin<TRequest, TResponse> {}
