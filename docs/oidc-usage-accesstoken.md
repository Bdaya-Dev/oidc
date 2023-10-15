# Using the access token

`package:oidc`'s role ends once you get the `access_token`/`id_token`, and what you do with it is outside the scope of the package.

However here are common best practices on how you can get and use the `access_token` in different libraries.

## Getting the access token

You can get the access token from the `OidcToken` object, that you can get from the `OidcUser` object.

You can get the `OidcUser` in 2 ways:

1. Reactive way: listening on the `OidcUserManager.userChanges()` stream.
2. Non-Reactive way: `OidcUserManager.currentUser` property.

So the general idea is that when you are sending a request, you would first get the access token, then add it as a header `Authorization: Bearer access_token`.

```dart
const kAuthorizationHeader = 'Authorization';

void tryAppendAccessToken(OidcUserManager userManager, Map<String, dynamic> headers) {
  if (headers.containsKey(kAuthorizationHeader)) {
    // do nothing if header already exists.
    return;
  }
  final accessToken = userManager.currentUser?.token.accessToken;
  if (accessToken == null) {
    // do nothing if there is no access token.
    return;
  }
  headers[kAuthorizationHeader] = 'Bearer $accessToken';
}
```

## package:dio

Best practice is to create an [interceptor](https://pub.dev/packages/dio#interceptors) that is aware of the current `OidcUserManager`.

### Interceptor Example

```dart
import 'package:dio/dio.dart';
import 'package:oidc/oidc.dart';

class OidcUserManagerInterceptors extends Interceptor {
  const OidcUserManagerInterceptors({
    required this.userManager,
  });

  final OidcUserManager userManager;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _tryAppendAccessToken(userManager, options.headers);
    handler.next(options);
  }
}
```

### Usage Example

```dart
dio.interceptors.add(OidcUserManagerInterceptors(userManager: manager));
```

## package:http

Best practice is to create your own `Client` that wraps around another `Client`.

### Client Example
```dart
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

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    _tryAppendAccessToken(userManager, request.headers);
    return originalClient.send(request);
  }
}
```

### Usage Example

```dart
final client = OidcHttpClient(
  originalClient: Client(),
  userManager: manager,
);
// client.get(...);
// client.post(...);
```