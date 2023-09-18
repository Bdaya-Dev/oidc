# Using the plugin  <!-- omit from toc -->

all the classes that are exposed by this plugin start with `Oidc*`.


## OidcUserManager

### Construction

The main class this plugin provides, as the name suggests, it manages the current user session.

> NOTE: you should only maintain a single instance of this class in your app.

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

an instance of `OidcStore`, we provide 2 types of stores out of the box, depending on your use case:

1. `OidcMemoryStore` from [package:oidc_core](oidc_core.md); which stores the auth state in memory (good for CLI apps or during testing).
2. `OidcDefaultStore` from [package:oidc_default_store](oidc_default_store.md); which persists the auth state on disk or `localStorage` on web, And tries to encrypt the data if possible.

#### settings

settings to control the behavior of the instance.

- `bool strictJwtVerification = false`: whether JWTs are strictly verified.
- `Uri redirectUri`: the redirect uri that was configured with the provider.
- `Uri? postLogoutRedirectUri`: the post logout redirect uri that was configured with the provider.
- `Uri? frontChannelLogoutUri`: the uri of the front channel logout flow. this Uri MUST be registered with the OP first. the OP will call this Uri when it wants to logout the user.
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

- `OidcPlatformSpecificOptions? options`: platform specific options to control auth requests:
    - `bool allowInsecureConnections`: Whether to allow non-HTTPS endpoints; for `android` 🤖 platform only.
    - `bool preferEphemeralSession`: Whether to use an ephemeral session that prevents cookies and other browser data being shared with the user's normal browser session.
        This property is only applicable to `iOS`/`MacOs` 🍏 versions 13 and above.
    - Native options: these are options that apply to desktop 🖥️ platforms (linux + windows) that use [loopback interface redirection](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3), to customize how the server responds to redirect responses:
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

after constructing the manager with the proper settings, you MUST call the `manager.init()` function, which will do the following:
    

### Login

#### Auth code flow

#### Implicit flow

#### Resource Owner Password flow

### Logout

## OidcFlutter



[http_link]: https://pub.dev/packages/http
[http_image]: https://img.shields.io/badge/package-http-0175C2?logo=dart&logoColor=white

[jose_plus_link]: https://pub.dev/packages/jose_plus#create-a-jwt
[jose_plus_image]: https://img.shields.io/badge/package-jose__plus-0175C2?logo=dart&logoColor=white