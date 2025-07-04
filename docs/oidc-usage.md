# Using the plugin 

all the classes that are exposed by this plugin start with `Oidc*`.

## OidcUserManager

### Construction

`OidcUserManager` is the main class this plugin provides, as the name suggests, it manages the current user session.

you have two ways to construct it, depending on the availability of the [Discovery Document](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfig).

1. If you have the discovery document already:
    ```dart
    final manager = OidcUserManager(
        discoveryDocument: OidcProviderMetadata.fromJson({
            'issuer': 'https://server.example.com',
            'authorization_endpoint':
                'https://server.example.com/connect/authorize',
            'token_endpoint': 'https://server.example.com/connect/token',
            //...other metadata
        }),
        //...other parameters.
    );
    ```
2. If you don't have the discovery document
    ```dart
    final manager = OidcUserManager.lazy(
        // discoveryDocumentUri:
        //     Uri.parse('https://server.example.com/.well-known/openid-configuration'),
        //or
        discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://server.example.com'),
        ),
        //...other parameters.
    );
    ```

aside from the discovery document, both constructors share the same parameters:

#### Constructing multiple user managers

If you want to support multiple identity providers, you can construct multiple `OidcUserManager` instances, each with its own discovery document and `id`.

```dart
final googleManager = OidcUserManager.lazy(
    id: 'google',
    discoveryDocumentUri: Uri.parse('https://accounts.google.com/.well-known/openid-configuration'),
    //...other parameters.
);
final microsoftManager = OidcUserManager.lazy(
    id: 'microsoft',
    discoveryDocumentUri: Uri.parse('https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration'),
    //...other parameters.
);
```

#### clientCredentials

an `OidcClientAuthentication` describes [how the client authenticates with the identity provider](https://openid.net/specs/openid-connect-core-1_0.html#ClientAuthentication), which has the following constructors:

1. `.none`: good for public clients, only the `clientId` is required.
    ```dart
    OidcClientAuthentication.none(clientId: 'my_client_id')
    ```
2. `.clientSecretBasic`: good for confidential clients that can keep a secret.
    ```dart
    OidcClientAuthentication.clientSecretBasic(
        clientId: 'my_client_id',
        clientSecret: 'my_client_secret',
    )
    ```
    this uses the HTTP Basic authentication scheme.
3. `.clientSecretPost`: same as `clientSecretBasic`, but passes the `clientId` and `clientSecret` as form parameters, instead of `Authorization` header.
    ```dart
    OidcClientAuthentication.clientSecretPost(
        clientId: 'my_client_id',
        clientSecret: 'my_client_secret',
    )
    ```
4. `.clientSecretJwt`: you create a JWT based on the `clientId` and `clientSecret`, instead of passing the secret directly.
    ```dart
    OidcClientAuthentication.clientSecretJwt(
        clientId: 'my_client_id',
        clientAssertion: 'PHNhbWxwOl ... ZT',
    )
    ```
5. `.privateKeyJwt`: similar to `clientSecretJwt`, but you first have to create an Asymmetric key pair, and sign the JWT using the public key.
    ```dart
    OidcClientAuthentication.privateKeyJwt(
        clientId: 'my_client_id',
        clientAssertion: 'PHNhbWxwOl ... ZT',
    )
    ```

how you create/obtain the jwt is outside the scope of this package.
you can use [![package:jose_plus][jose_plus_image]][jose_plus_link] to help you.


#### store

an instance of `OidcStore`, we provide 3 types of stores out of the box, depending on your use case:

1. `OidcMemoryStore` from [package:oidc_core](oidc_core.md); which stores the auth state in memory (good for CLI apps or during testing).
2. `OidcDefaultStore` from [package:oidc_default_store](oidc_default_store.md); which persists the auth state on disk or `localStorage` on web, And tries to encrypt the data if possible.
3. `OidcWebStore` from [package:oidc_web_core](oidc_web_core.md); which persists the auth state on `localStorage`/`session_storage` on web.

#### settings

settings to control the behavior of the instance.

- `bool supportOfflineAuth = false`: whether the app should keep expired tokens if it's not able to contact the server.

    !!! Warning
        Enabling offline auth can be a security risk, as it allows the app to keep tokens that are no longer valid.
        And it may open up unexpected attack vectors.

- `bool strictJwtVerification = false`: whether JWTs are strictly verified.
- `Uri redirectUri`: the redirect uri that was configured with the provider.
- `Uri? postLogoutRedirectUri`: the post logout redirect uri that was configured with the provider.
- `Uri? frontChannelLogoutUri`: the uri of the front channel logout flow. this Uri MUST be registered with the OP first. the OP will call this Uri when it wants to logout the user.
- `Future<String?> Function(OidcToken token) getIdToken`: pass this function to control how an idToken is fetched from a token response. This can be used to trick the user manager into using a JWT `access_token` as an `id_token` for example. 
- `frontChannelRequestListeningOptions`: the options to use when listening for front channel logout requests.
    ```dart
    frontChannelRequestListeningOptions: OidcFrontChannelRequestListeningOptions(
        //currently only supports web.
        web: OidcFrontChannelRequestListeningOptions_Web(
            broadcastChannel: 'oidc_flutter_web/request'
        )
    )
    ```
> Note that this channel needs to be the same as the one in your [redirect.html](oidc-getting-started.md/#web) page.


- `Duration expiryTolerance`: also known as clock skew, it's a small duration that lengthens the token expiry time, to account for communication delays; default is 1 minute.

- `Duration? Function(OidcToken token)? refreshBefore`: a function that controls how you want the automatic refresh_token handling to work.
    you receive a token, and you decide for it how early the token gets refreshed.
    for example:
    - if `Duration.zero` is returned, the token gets refreshed once it's expired.
    - if `null` is returned, automatic refresh is disabled.

    by default, this is a function that returns `Duration(minutes: 1)` for every token, which means that all tokens are refreshed 1 minute before they expire.

- `Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn`: a function that overrides a token's expires_in value, it's not recommended to change this, since it's only used for testing.

- `OidcSessionManagementSettings sessionManagementSettings`: contains settings for the session management spec:
    - `bool enabled`: (default false) whether to enable checking the session.
    - `Duration interval`: (default 5 minutes) how often to check the current user session.
    - `bool stopIfErrorReceived`: (default true) whether to stop checking the current user session if the OP sends an `error` message.

- `OidcPlatformSpecificOptions? options`: platform specific options to control auth requests:
    - `bool allowInsecureConnections`: Whether to allow non-HTTPS endpoints; for `android` 🤖 platform only.
    - `OidcAppAuthExternalUserAgent externalUserAgent`: Selects the strategy for opening external browser in ios📱and macos 💻:
        - `asWebAuthenticationSession` (default)
            Uses the [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession) APIs where possible.
            
            This is the default for macOS and iOS 12 and above. On iOS 11, it will
            use [SFAuthenticationSession](https://developer.apple.com/documentation/safariservices/sfauthenticationsession)
            instead.
            
            Behind the scenes, the plugin makes use of the default external user-agent
            provided by the AppAuth iOS SDK. This will use the best user-agent
            available on the device. Specifically, on iOS it will use [OIDExternalUserAgentIOS](https://openid.github.io/AppAuth-iOS/docs/latest/interface_o_i_d_external_user_agent_i_o_s.html)
            and on macOS it will use [OIDExternalUserAgentMac](https://openid.github.io/AppAuth-iOS/docs/latest/interface_o_i_d_external_user_agent_mac.html).
            
            Using this follows the best practices on using the appropriate native APIs
            based on the OS version.
        - `ephemeralAsWebAuthenticationSession`: 
            Indicates a preference in using an ephemeral sessions by using the [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession) APIs where possible.
            This is only applicable to macOS and iOS 12 and above. On these platforms, the session will not share browser data with user's normal browser session and does not keep the cache.

            Like `asWebAuthenticationSession`, it fallback to use [SFAuthenticationSession](https://developer.apple.com/documentation/safariservices/sfauthenticationsession)
            on iOS 11 where there's no support for ephemeral sessions.
        - `sfSafariViewController`: 
            Uses the [SFSafariViewController](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller) APIs. This does not share browser data with the user's normal browser session but keeps the cache.

            This is only applicable to iOS. On macOS, it will use the same behavior as         `asWebAuthenticationSession`.
            One reason for using this is when applications trigger an end session request but wants to avoid the prompt that would have appeared when the [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession) APIs are used. 

            In this case, there's concern that the system-generated prompt would confuse the user as they are trying to sign out but the prompt states that it's taking the user through a sign-in flow.

            Note that as this does not follow the best practices on using the appropriate native APIs based on the OS version, developers should use this at their own discretion.
        
    - Native options: these are options that apply to desktop 🖥️ platforms (linux $$+ windows) that use [loopback interface redirection](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3), to customize how the server responds to redirect responses:
        - `String? successfulPageResponse`: What to return if a URI is matched
        - `String? methodMismatchResponse`: What to return if a method other than `GET` is requested.
        - `String? notFoundResponse`: What to return if a different path is used.
    - Web 🌐 options:
        - `OidcPlatformSpecificOptions_Web_NavigationMode navigationMode`: how the auth request is launched; possible values are:
            - `samePage`: NOT RECOMMENDED; since you have to reload your app and lose current ui state.
            - `newPage`: RECOMMENDED, navigates in a new tab.
            - `popup`: NOT RECOMMENDED; since some browsers block popups.
> you can also pass `popupWidth` and `popupHeight` to control the popup window dimensions.
        - `String broadcastChannel`: The broadcast channel to use when receiving messages from the browser; defaults to: `oidc_flutter_web/redirect`
> Note: This MUST be the same as the one in your  [redirect.html](oidc-getting-started.md/#web) page.

##### Hooks

`OidcUserManagerHooks? hooks`: a set of hooks that allow you to customize the behavior of the user manager.

- All hooks inherit `OidcHookMixin<TRequest, TResponse>`, which is just a marker mixin.
- By default, we support the following hooks:
    - `token`: to hook into the token request and response.
    - `authorization`: to hook into the authorization request and response.

To define a hook you can either extend `OidcHookBase`, or use the `OidcHook` class directly.

###### Example: 

To remove the scope from the `refresh_token` request, you can define a hook like this:

```dart
OidcUserManagerSettings(
  hooks: OidcUserManagerHooks(
    token:  OidcHook(
      modifyRequest: (request) {
        if (request.request.grantType == 'refresh_token') {
          // Remove the scope from refresh_token requests
          request.request.scope = null;
        }
        return Future.value(request);
      },
    ),
  ),
),
```

You can also group multiple hooks together, for example:

```dart
hooks: OidcUserManagerHooks(
  token: OidcHookGroup(
    // Only modifyRequest, modifyResponse hooks can be chained.
    hooks: [
      OidcHook(
        modifyResponse: (response) {
          logger.info(
            'Modifying token response: ${response.src}',
          );
          return Future.value(response);
        },
      ),
    ],
    // Only a single executionHook can be defined for the group.
    executionHook: OidcHook(
      modifyExecution: (request, defaultExecution) async {
        logger.info(
          'Executing token request: ${request.request.toMap()}',
        );
        final response = await defaultExecution(request);
        logger.info(
          'Executed token request: ${response.src}',
        );
        return response;
      },
    ),
  ),
),
```

##### Default Auth request parameters

These are [parameters that you send with the auth request](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest), and you can either define them in the `login*` functions, or define the default values here.

- `List<String> scope`: possible values are in `OidcConstants_Scopes`
    - openid
    - profile
    - email
    - address
    - phone
- `List<String> prompt`: possible values are in `OidcConstants_AuthorizeRequest_Prompt`
    - none
    - login
    - consent
    - selectAccount
- `String? display`: possible values are in `OidcConstants_AuthorizeRequest_Display`
    - page
    - popup
    - touch
    - wap
- `List<String>? uiLocales`
- `List<String>? acrValues`
- `Duration? maxAge`
- `Map<String, dynamic>? extraAuthenticationParameters`: these are extra parameters that you can send with every authentication request.
- `Map<String, String>? extraTokenHeaders`: these are extra headers that you can send with every token request.
- `Map<String, dynamic>? extraTokenParameters`: these are extra parameters that you can send with every token request.


#### httpClient

We depend on [![package:http][http_image]][http_link], and you can provide your own http client which will let you intercept and modify request/response behavior.

#### keyStore

A custom keystore from [![package:jose_plus][jose_plus_image]][jose_plus_link], if you want to maintain your own store.
this is used for validating the JWT signature.

### Initialization

After constructing the manager with the proper settings, you MUST call the `manager.init()` function, which will do the following:

1. If the function has already been initialized (checked via the hasInit variable), it simply returns. This is because certain configurations and setups do not need to be repeated.
2. initialize the passed store (calls `OidcStore.init()`)
3. ensure that the discovery document has been retrieved (if the lazy constructor was used).
4. if the discovery document contains a `jwks_uri` adds it the to the keystore.
5. handle various state management tasks. It loads logout requests and state results (from samePage redirects), also attempts to load cached tokens if there are no state results or logout requests.
6. If the loaded token has expired and a refresh token exists, it attempts to refresh it, otherwise the token will be removed form the store.
7. Starts Listening to incoming Front Channel Logout requests.
8. Starts listening to token expiry events for automatic `refresh_token` circulation.

### Login

#### loginAuthorizationCodeFlow

If you provided the [settings](#settings) earlier, there are no required parameters here, so you can just call `manager.loginAuthorizationCodeFlow()`.
however there are some new parameters:

- `originalUri`: mainly used for `samePage` navigation on web; this is the Uri the user will navigate to after they are redirected to the `redirect.html` page
- `extraStateData`: arbitrary data that you want to persist in the state parameter, note that this MUST be json serializable.
- `idTokenHintOverride`: pass an `id_token_hint`.
- `includeIdTokenHintFromCurrentUser`: if true, will include the current `id_token` as the `idTokenHint` parameter.
> Note that this is ignored if `idTokenHintOverride` is assigned.
- if you pass `options` here and at the [settings](#settings), they WILL NOT get merged, and the options from the login request takes precedence. 
- `extraParameters`: extra parameters that will get passed to the auth server as part of the request.
    These ARE merged with `settings.extraAuthenticationParameters`.

- `extraTokenParameters`: extra parameters that will get passed to the auth server when making the token request. These ARE merged with `settings.extraTokenParameters`.
- `extraTokenHeaders`: extra parameters that will get passed to the auth server when making the token request. These ARE merged with `settings.extraTokenHeaders`.

#### loginImplicitFlow

Same parameters as `loginAuthorizationCodeFlow`, but you MUST specify the `responseType`.

possible values are in `OidcConstants_AuthorizationEndpoint_ResponseType`:

- `idToken`
- `token`
- `code`

and any combination of them.

!!! Warning
    This flow is [deprecated](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics-23#name-implicit-grant) due to security concerns, and is only available for backward-compatibility with providers that don't support invoking the token endpoint without a client_secret (like [google](https://developers.google.com/identity/protocols/oauth2/javascript-implicit-flow)).

#### loginPassword

you only need to provide the `username` and the `password`.
you can also pass `scopeOverride` to override the scopes from `settings.scopes`.

### Logout

The word "Logout" can have different behaviors depending on the context:

#### Forgetting the user

- this is as simple as calling `forgetUser()` which will clear the cache, and unassign the `currentUser`.
- this DOES NOT inform the identity provider that the user has logged out, nor revoke the token.

!!! Note
    A user that logs in after being forgotten, might not get prompted to enter their username/password again, keeping them in an infinite loop unable to change their credentials.

    To counter this, you need to specify the `prompt` parameter when logging in (e.g. `prompt: ["login"]`), or logout from the Identity provider.

#### Logging out from the identity provider.

This can be done by calling `logout` with the following optional parameters:

- `logoutHint`: can be the email/username or any documented value.
- `postLogoutRedirectUriOverride`: if assigned, overrides the value passed in `settings.postLogoutRedirectUri`.
- `originalUri`: mainly used for `samePage` navigation on web; this is the Uri the user will navigate to after they are redirected to the `redirect.html` page.
- `extraStateData`: arbitrary data that you want to persist in the state parameter, note that this MUST be json serializable.
- `uiLocalesOverride`: overrides the value passed in `settings.uiLocales`.
- `options`: platform-specific navigation options, which are the same as `settings.options`.
- `extraParameters`: extra parameters to pass to the logout request.

### Listening to currentUser changes

Whenever a user logs in, logs out, or a token gets refreshed automatically, an event is added to the `userChanges()` stream.

This is similar to firebase auth, and can be used to track the current session.

You can also get access to the current authenticated user via `currentUser` property.

### Listening to events

Events are an advanced form of user changes, since they occur in more places than the `currentUser` stream, and help the developer hook into every flow.

for example you might want to make an API call before logging out the user, then you would do:

```dart
manager.events().listen((event) {
  switch (event) {
    case OidcPreLogoutEvent(:final currentUser):
      // make an api call with the currentUser.
      break;
    default:
  }
});
```

### Revoking tokens

The `OidcUserManager` provides methods to revoke tokens at the authorization server, making them invalid for future use.

#### revokeAccessToken

Revokes the current user's access token, making it invalid for accessing protected resources.

```dart
// Revoke current user's access token and forget user
await manager.revokeAccessToken();

// Revoke specific token without forgetting user
await manager.revokeAccessToken(
  overrideAccessToken: 'specific_token',
  forgetUser: false,
);

// Revoke with custom headers
await manager.revokeAccessToken(
  headers: {'Custom-Header': 'value'},
  extraBodyFields: {'custom_param': 'value'},
);
```

**Parameters:**
- `discoveryDocumentOverride`: Optional discovery document to use instead of the default
- `options`: Platform-specific options for the revocation request
- `forgetUser`: Whether to forget the current user after successful revocation (defaults to `true`)
- `overrideAccessToken`: Specific access token to revoke instead of the current user's token
- `revocationEndpointOverride`: Custom revocation endpoint URL to use
- `extraBodyFields`: Additional fields to include in the revocation request body
- `headers`: Additional HTTP headers to include in the request

#### revokeRefreshToken

Revokes the current user's refresh token, making it invalid for obtaining new access tokens.

```dart
// Revoke current user's refresh token
await manager.revokeRefreshToken();

// Revoke specific refresh token with custom endpoint
await manager.revokeRefreshToken(
  overrideRefreshToken: 'specific_refresh_token',
  revocationEndpointOverride: Uri.parse('https://custom.revoke.endpoint'),
);
```

**Parameters:**
- `discoveryDocumentOverride`: Optional discovery document to use instead of the default
- `options`: Platform-specific options for the revocation request
- `forgetUser`: Whether to forget the current user after successful revocation (defaults to `true`)
- `overrideRefreshToken`: Specific refresh token to revoke instead of the current user's token
- `revocationEndpointOverride`: Custom revocation endpoint URL to use
- `extraBodyFields`: Additional fields to include in the revocation request body
- `headers`: Additional HTTP headers to include in the request

**Behavior:**
- Both methods return early if no current user exists
- Both methods return early if the respective token is not available to revoke
- Both methods return early if the authorization server doesn't provide a revocation endpoint
- Both methods call `forgetUser()` automatically after successful revocation when `forgetUser` is `true`
- Both methods use the hooks system to allow customization of the revocation process

!!! Note
    Token revocation is a best-effort operation. Some authorization servers may not support token revocation, in which case these methods will return without error. Always check your authorization server's capabilities before relying on token revocation.

### Refreshing the token manually

You can refresh the token manually by calling `manager.refreshToken()`.

You can also override the refresh token `manager.refreshToken(overrideRefreshToken: 'my_refresh_token')`.

It will either return `OidcUser` with the new token, `null` or throw an [OidcException].

`null` is returned in the following cases:

- The discovery document doesn't have `grant_types_supported` include `refresh_token` 
- The current user is null.
- The current user's refresh token is null.

### Overriding the discovery document

There are cases where you want to change some properties in the retrieved discovery document, either permanently, or for a specific method.

e.g., you might want to have a register and a login button where the register button overrides the discovery document's `authorizationEndpoint` parameter, but the login button uses the idp provided value.

We use [package:copy_with_extension_gen](https://pub.dev/packages/copy_with_extension_gen) to generate `copyWith` extension methods to help consumers override specific parts of the `OidcProviderMetadata` discovery document.

#### Permanent override

You can do that via the `discoveryDocument` setter in `OidcUserManager`, e.g.

```dart
final userManager = OidcUserManager.lazy(/*...*/);
await userManager.init();
userManager.discoveryDocument = userManager.discoveryDocument.copyWith(/*...*/);
```

#### Per-method override

You can pass the `OidcProviderMetadata? discoveryDocumentOverride` parameter in some methods.

Example:

```dart
final userManager = OidcUserManager.lazy(/*...*/);
await userManager.init();
await userManager.loginAuthorizationCodeFlow(
    discoveryDocumentOverride: userManager.discoveryDocument.copyWith(
        authorizationEndpoint: "https://idp.com/register", //change to register url instead of login
    )
);
```

### Dispose

If you aren't maintaining a single instance of the `OidcUserManager` class, you might want to `dispose()` it when you are done with the instance.

This will stop refreshing the tokens, and stop listening to logout requests.

It will also raise a `done` event in the `userChanges()` stream.

## OidcFlutter

The class `OidcFlutter` exposes static methods for the underlying platform implementations, if you don't want to use the `OidcUserManager` class.

They are defined as such:

```dart
/// starts the authorization flow, and returns the response.
///
/// on android/ios/macos, if the `request.responseType` is set to anything other than `code`, it returns null.
///
/// NOTE: this DOES NOT do token exchange.
///
/// consider using [OidcEndpoints.getProviderMetadata] to get the [metadata] parameter if you don't have it.
static Future<OidcAuthorizeResponse?> getPlatformAuthorizationResponse({
    required OidcProviderMetadata metadata,
    required OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options = const OidcPlatformSpecificOptions(),
});

/// starts the end session flow, and returns the response.
///
/// consider using [OidcEndpoints.getProviderMetadata] to get the [metadata] parameter if you don't have it.
static Future<OidcEndSessionResponse?> getPlatformEndSessionResponse({
    required OidcProviderMetadata metadata,
    required OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options = const OidcPlatformSpecificOptions(),
});

/// Listens to incoming front channel logout requests.
///
/// [listenTo] parameter determines which path should be listened for to receive
/// the request.
///
/// on windows/linux/macosx this starts a server on the same prt
static Stream<OidcFrontChannelLogoutIncomingRequest> listenToFrontChannelLogoutRequests({
    required Uri listenTo,
    OidcFrontChannelRequestListeningOptions options = const OidcFrontChannelRequestListeningOptions(),
});
```



[http_link]: https://pub.dev/packages/http
[http_image]: https://img.shields.io/badge/package-http-0175C2?logo=dart&logoColor=white

[jose_plus_link]: https://pub.dev/packages/jose_plus#create-a-jwt
[jose_plus_image]: https://img.shields.io/badge/package-jose__plus-0175C2?logo=dart&logoColor=white