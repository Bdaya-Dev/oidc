import 'package:oidc_core/src/hooks/oidc_request_response_hook_mixin.dart';

import 'oidc_hook_mixin.dart';

class OidcHookGroup<TRequest, TResponse>
    with
        OidcHookMixin<TRequest, TResponse>,
        OidcResponseModifierHookMixin<TRequest, TResponse>,
        OidcRequestModifierHookMixin<TRequest, TResponse> {
  OidcHookGroup({
    required this.hooks,
  });

  final List<OidcHookMixin<TRequest, TResponse>> hooks;

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
}
