import 'package:dio/dio.dart';
import 'package:oidc/oidc.dart';

/// a Dio interceptor that automatically adds accessToken from the current user.
class OidcUserManagerInterceptor extends Interceptor {
  const OidcUserManagerInterceptor({
    required this.userManager,
  });

  final OidcUserManager userManager;

  static const kAuthorizationHeader = 'Authorization';

  void _tryAppendAccessToken(RequestOptions options) {
    if (options.headers.containsKey(kAuthorizationHeader)) {
      // do nothing if header already exists.
      return;
    }
    final accessToken = userManager.currentUser?.token.accessToken;
    if (accessToken != null) {
      options.headers[kAuthorizationHeader] = 'Bearer $accessToken';
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _tryAppendAccessToken(options);
    handler.next(options);
  }
}
