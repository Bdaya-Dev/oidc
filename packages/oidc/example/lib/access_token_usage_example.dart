import 'package:dio/dio.dart';
import 'package:http/http.dart';
import 'package:oidc/oidc.dart';

const kAuthorizationHeader = 'Authorization';
void _tryAppendAccessToken(
  OidcUserManager userManager,
  Map<String, dynamic> headers,
) {
  if (headers.containsKey(kAuthorizationHeader)) {
    // do nothing if header already exists.
    return;
  }
  final accessToken = userManager.currentUser?.token.accessToken;
  if (accessToken != null) {
    headers[kAuthorizationHeader] = 'Bearer $accessToken';
  }
}

/// a Dio interceptor that automatically adds accessToken from the current user.
class OidcUserManagerInterceptor extends Interceptor {
  const OidcUserManagerInterceptor({
    required this.userManager,
  });

  final OidcUserManager userManager;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _tryAppendAccessToken(userManager, options.headers);
    handler.next(options);
  }
}

/// Wraps an http client to automatically add the `Authorization` header.
class OidcHttpClient extends BaseClient {
  OidcHttpClient({
    required this.originalClient,
    required this.userManager,
  });

  final Client originalClient;
  final OidcUserManager userManager;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    _tryAppendAccessToken(userManager, request.headers);
    return originalClient.send(request);
  }
}
