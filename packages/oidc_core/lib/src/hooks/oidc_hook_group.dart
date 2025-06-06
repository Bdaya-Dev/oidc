import 'package:oidc_core/src/hooks/oidc_request_response_hook_mixin.dart';

import 'oidc_hook_mixin.dart';

class OidcHookGroup<TRequest, TResponse>
    with
        OidcHookMixin<TRequest, TResponse>,
        OidcRequestResponseHookMixin<TRequest, TResponse> {
  OidcHookGroup({
    required this.hooks,
  });

  final List<OidcRequestResponseHookMixin<TRequest, TResponse>> hooks;

  @override
  Future<TRequest> modifyRequest(TRequest request) async {
    var modifiedRequest = request;
    for (final hook in hooks) {
      modifiedRequest = await hook.modifyRequest(modifiedRequest);
    }
    return modifiedRequest;
  }

  @override
  Future<TResponse> modifyResponse(TResponse response) async {
    var modifiedResponse = response;
    for (final hook in hooks) {
      modifiedResponse = await hook.modifyResponse(modifiedResponse);
    }
    return response;
  }
}
