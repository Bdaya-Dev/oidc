import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

mixin OidcRequestModifierHookMixin<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse> {
  Future<TRequest> modifyRequest(TRequest request);
}
mixin OidcResponseModifierHookMixin<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse> {
  Future<TResponse> modifyResponse(TResponse response);
}
