
# [![package:oidc_core][package_image]][package_link]

This is the core package written in pure dart, and maps the oidc spec to dart classes.

you can check the [CLI example](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc_core/example/main.dart), showing how to use this package to implement the auth code flow in a CLI environment.

## OidcUtils

### getOpenIdConfigWellKnownUri

you can use this function to append `.well-known/openid-configuration` to any Uri

## OidcReadOnlyStore + OidcStore

The abstract store implementation that needs to be implemented in order to have a persistent session.

we use this to store state, tokens, etc...

this was inspired by [oidc-client-ts](https://github.com/authts/oidc-client-ts/blob/main/src/StateStore.ts), but we have further improved this by adding the concept of namespaces.

So instead of having to maintain `n` stores, you only need one smart store, that is able to decide where to store things based on namespace.

### OidcStoreNamespace

this is an enum that contains all the possible namespaces

- `session`: Stores ephemeral information, such as the current state id and nonce.
- `state`: Stores states, this maps state id to state data.
- `stateResponse`: Stores unprocessed state responses, all the data stored in this namespace are `Uri`s that were the result of a redirect, which the app hasn't processed yet.
- `request`: Stores unprocessed requests from the openid provider (mainly frontchannel logout).
- `discoveryDocument`: caches discovery documents.
- `secureTokens`: stores sensitive tokens, like `access_token` and `id_token`.

!!! info Considerations for web

    On the web platform, since we use an external `redirect.html` page, implementations of the store MUST match the used page.

    we made a default implementation in [package:oidc_default_store](oidc_default_store.md) and [package:oidc_web_core](oidc_web_store.md), which matches the `redirect.html` page provided in our examples.

### OidcMemoryStore

A simple implementation of `OidcStore`, used mainly on CLI apps and for testing.

It stores everything in memory, and doesn't persist anything.

## OidcUserManagerBase

An abstract class containing all the base logic needed to implement oidc spec and maintain a user, regardless of platform.

Example implementations:

- CLI: example [here](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc_core/example/cli_user_manager.dart)
- Flutter: `OidcUserManager` in [package:oidc](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc/lib/src/managers/user_manager.dart)
- Dart Web: `OidcUserManagerWeb` in [package:oidc_web_core](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc_web_core/lib/src/user_manager_web.dart)


## OidcEvent

The base class for all events, this contains an `at` property that stores when the event occurred.

### OidcPreLogoutEvent

Occurs before a user is forgotten, either via `forgetUser()` or via `logout()`.

## OidcPkcePair

you can use this to generate PKCE key pairs.

## OidcConstants_*

A set of classes that map the oauth + openid connect constants to compile time constants for easier usage.


## OidcToken

A serializable token.
This contains information about the `access_token`/`id_token` that was received from the `/token` endpoint.

Token properties are:

- `creationTime`: when the token was created.
- `scope`: scopes that this token allows.
- `accessToken`: The issued access token. This is used to request resources from the server.
- `tokenType`: How to use the token. This is almost always `Bearer`, which indicates the use in the authorization header `Authorization: Bearer {accessToken}`.
- `idToken`: the issued id token that contains information about the user.
- `expiresIn`: the duration starting from `creationTime`, in which this token is considered valid.
- `refreshToken`: the issued refresh token. If available, we use this to request new access tokens once they expire.
- `extra`: extra values to extend the token.

The only thing required to create a token is its `creationTime`.

to create a token, you can use one of the following:

- `fromJson`: to deserialize a token that was serialized using `toJson`
- `fromResponse`: to create a token from a raw `OidcTokenResponse` that you get from the `/token` endpoint.

There are also some useful methods that the token provides:

- `calculateExpiresAt`: calculates the exact datetime for the token to expire. This is calculated as `creationTime + expiresIn`.
- `calculateExpiresInFromNow`: calculates how much time left from now, for the token to expire, you can also override `now` and `creationTime` if you want. This is calculated as `expiresAt - now`.
- `isAccessTokenAboutToExpire`: determine if the access token is about to expire, with an optional `tolerance` parameter (defaults to 1 minute). you can also override the `now` and `creationTime` parameters.
- `isAccessTokenExpired`: determine if the access token has expired. This simply calls `isAccessTokenAboutToExpire` with `tolerance: Duration.zero`
- `toJson`: used to serialize the token into json.


## OidcUser

A wrapper around `OidcToken` that requires the existence of `id_token` to understand information about the user; thus implementing the OIDC spec.

to create a user, you should call `fromIdToken` which takes the following parameters:

- `OidcToken token`: the source token, this MUST contain `idToken`.
- `strictVerification`: if true, will throw an error if we fail to verify the signature of the JWT id token.
!!! Warning
    The current jose package we use is unmaintained, and has multiple problems, so setting `strictVerification: true` might throw random errors.

    you MUST test if it works before using it in production.

    see this issue for more information: [oidc#9](https://github.com/Bdaya-Dev/oidc/issues/9).

- `keystore`: the store that contains information about the public json web keys.
- `attributes`: extra attributes to put with the user for customization.
- `userInfo`: the response from the `/userinfo` endpoint.

### Changing user properties

since the `OidcUser` is immutable, you need to create a new instance of it if you want to change its properties.

this is done using these functions:

- `withUserInfo`: changes the response of the `/userinfo` endpoint.
- `replaceToken`: replaces the token that identifies the user with a new token, while leaving everything else.
    this is used in refresh token rotation to change the latest token the user has.
- `setAttributes`: merges input attributes with existing attributes.
- `clearAttributes`: removes all attributes.

## OidcException

Most of the errors thrown by this library are of type `OidcException`.

it contains the following properties:

- `message`: a message that describes the error.
- `errorResponse`: the error response coming from the auth server, if it exists.
- `internalException` and `internalStackTrace`, if this error contains other internal errors.
- `extra`: some extra parameters that describe the error, this can contain the raw `Request`/`Response` objects from `package:http`.

## OidcTokenEventsManager

Manages token events.

you can load a token, and the watch its events in the `expiring`/`expired` streams.

## OidcEndpoints

Contains methods that help you implement the OIDC spec yourself.

- `prepareAuthorizationCodeFlowRequest`: this is used to prepare an opinionated authorization code flow request, by creating a PKCE pair and a state parameter.
- `prepareImplicitFlowRequest`: this is used to prepare an opinionated implicit flow request, by creating a state parameter.
- `getProviderMetadata`: gets and parses provider metadata from the authorization server's well-known endpoint.
- `parseAuthorizeResponse`: parses the uri that you get from the authorization flow, and returns useful information.
- `token`: sends a request to the `/token` endpoint.
- `userInfo`: sends a request to the `/userinfo` endpoint.
- `deviceAuthorization`: sends a request to the device authorization endpoint.

--- 

[package_link]: https://pub.dev/packages/oidc_core
[package_image]: https://img.shields.io/badge/package-oidc__core-0175C2?logo=dart&logoColor=white