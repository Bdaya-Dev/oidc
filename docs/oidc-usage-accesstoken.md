# Using the access token

`package:oidc` hands you an `access_token`; what you do with it against your own API is outside the scope of the package.

However here are common best practices on how you can get and use the `access_token` in different libraries.

## Getting the access token

Use `OidcUserManager.getAccessToken()`. It returns an access token that is guaranteed to stay valid for at least `minValidity` (30 seconds by default), refreshing it first only when it would not be:

```dart
final accessToken = await userManager.getAccessToken();
```

Three things it does that reading the token yourself does not:

* **it refreshes only when needed** — a still-fresh token is returned without any network call;
* **it coalesces concurrent callers** — N parallel requests that all find a stale token share ONE refresh-token exchange. This matters against a provider that rotates refresh tokens, which [RFC 9700 §2.2.2](https://www.rfc-editor.org/rfc/rfc9700.html#section-2.2.2) requires for public clients ("Refresh tokens for public clients MUST be sender-constrained or use refresh token rotation"): rotation invalidates the previous refresh token on every exchange, so a second concurrent exchange presents an invalidated token and the server "will revoke the active refresh token" ([§4.14.2](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2)) — logging the user out;
* **it tells you when a login is genuinely required** — via a typed exception rather than an OAuth error string you have to match on.

```dart
try {
  final accessToken = await userManager.getAccessToken();
  // ... send the request
} on OidcInteractionRequiredException {
  // The session cannot be renewed silently — start an interactive login.
  await userManager.loginAuthorizationCodeFlow();
}
```

| Situation | Result |
| --- | --- |
| No signed-in user | returns `null` (a state, not an error) |
| Token still valid for `minValidity` | returns it unchanged, no network call |
| Token stale, refresh succeeds | returns the NEW access token |
| Token stale, no refresh token / `invalid_grant` | throws `OidcInteractionRequiredException` |
| Refresh failed for a recoverable reason (network, 5xx) | throws `OidcException` with `kind == OidcTokenRefreshFailureKind.transient` |

Pass `forceRefresh: true` to exchange unconditionally, or a larger `minValidity` when your request may take a while to reach the resource server.

You can still read the raw token off the user object (`userManager.currentUser?.token.accessToken`, or the `userManager.userChanges()` stream) when you want the current value WITHOUT any freshness guarantee — for display, diagnostics, or when you manage renewal yourself.

### Silent re-authentication

When the session has no refresh token — a public web client whose provider does not issue one — `signInSilent()` renews off the provider's own session cookie with a `prompt=none` request in a hidden iframe:

```dart
final user = await userManager.signInSilent();
```

It tries the refresh-token grant first when one is available, and shares the same in-flight exchange as `getAccessToken()`. It throws `OidcInteractionRequiredException` when the provider answers `login_required` / `interaction_required` / `consent_required` / `account_selection_required`.

The `prompt=none` half is **web-only**: on native platforms it degrades to the refresh-token path, and even on web the hidden iframe depends on the provider session cookie being readable in a third-party context, which Safari's ITP blocks and Chrome restricts. Prefer a refresh token where your provider can issue one.

## Sending the token

The general idea is that when you are sending a request, you first get the access token, then add it as an `Authorization` header.

```dart
const kAuthorizationHeader = 'Authorization';

Future<void> tryAppendAccessToken(
  OidcUserManager userManager,
  Map<String, dynamic> headers,
) async {
  if (headers.containsKey(kAuthorizationHeader)) {
    // do nothing if header already exists.
    return;
  }
  final accessToken = await userManager.getAccessToken();
  if (accessToken == null) {
    // do nothing if there is no access token.
    return;
  }
  headers[kAuthorizationHeader] = 'Bearer $accessToken';
}
```

### DPoP-protected resources

When you enabled DPoP (`OidcUserManagerSettings.dpop`), your access token is sender-constrained (RFC 9449) and sending it as a plain `Bearer` throws that guarantee away. Mint a proof for each request with `createDPoPProof` and send the pair — `Authorization: DPoP <token>` plus a `DPoP: <proof>` header:

```dart
Future<void> tryAppendDPoPAccessToken(
  OidcUserManager userManager,
  Uri uri,
  String method,
  Map<String, dynamic> headers,
) async {
  final accessToken = await userManager.getAccessToken();
  if (accessToken == null) {
    return;
  }
  // Pass the same access token you are about to send, so the proof's `ath`
  // claim matches it even if the call above just refreshed.
  final proof = await userManager.createDPoPProof(
    uri: uri,
    method: method,
    accessToken: accessToken,
  );
  headers[kAuthorizationHeader] =
      proof == null ? 'Bearer $accessToken' : 'DPoP $accessToken';
  if (proof != null) {
    headers[oidcDPoPHeaderName] = proof;
  }
}
```

`createDPoPProof` returns `null` when DPoP is not enabled, so the same helper works for both configurations.

A resource server may demand a nonce (RFC 9449 §8): it answers `401` with `error="use_dpop_nonce"` and a `DPoP-Nonce` header. Feed that nonce back and retry once:

```dart
final nonce = response.headers[oidcDPoPNonceHeaderName.toLowerCase()];
if (response.statusCode == 401 && nonce != null) {
  userManager.cacheDPoPNonce(uri, nonce);
  // mint a fresh proof and send the request again, once.
}
```

`userManager.dpopThumbprint` exposes the RFC 7638 thumbprint of the session proof key — the value the provider binds the token to as `cnf.jkt`.

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
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await tryAppendAccessToken(userManager, options.headers);
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
  Future<StreamedResponse> send(BaseRequest request) async {
    await tryAppendAccessToken(userManager, request.headers);
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
