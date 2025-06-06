import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';

mixin OidcRequestResponseHookMixin<TRequest, TResponse>
    on OidcHookMixin<TRequest, TResponse> {
  Future<TRequest> modifyRequest(TRequest request);
  Future<TResponse> modifyResponse(TResponse response);
}
