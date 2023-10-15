import 'package:http/http.dart';
import 'package:oidc/oidc.dart';

/// Wraps an http client to automatically add the `Authorization` header.
class OidcHttpClient extends BaseClient {
  OidcHttpClient({
    required this.originalClient,
    required this.userManager,
  });

  final Client originalClient;
  final OidcUserManager userManager;

  static const kAuthorizationHeader = 'Authorization';

  void _tryAppendAccessToken(BaseRequest options) {
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
  Future<StreamedResponse> send(BaseRequest request) {
    _tryAppendAccessToken(request);
    return originalClient.send(request);
  }
}
