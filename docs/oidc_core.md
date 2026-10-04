
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
- `keystore`: the store that contains information about the public json web keys. When provided, signature
  verification is **always strict** (fail-closed) — an id_token whose signature cannot be verified throws;
  there is no opt-out. When omitted, the id_token is parsed but left unverified.

    !!! Info "Key rotation"
        A `kid` absent from the currently-loaded JWKS triggers one rate-limited, cache-busting JWKS refetch
        before failing (OpenID Connect Core 1.0 §10.1.1), so a routine signing-key rotation at the OP does not
        cause a spurious verification failure.

    !!! Warning "HS256 id_tokens"
        Some OPs (e.g. Auth0, for confidential clients by default) sign id_tokens with the symmetric `HS256`
        algorithm, keyed by the client secret rather than a JWKS-published key. Verifying these requires an
        `oct` key derived from the client secret to be present in `keystore` — `OidcUserManagerBase.init()`
        does this automatically when `clientCredentials` carries a `clientSecret`. Calling `fromIdToken`
        directly (bypassing the manager) must add that key itself.
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

When a refresh response has no `id_token` (allowed by OpenID Connect Core §12.2), `replaceToken` keeps the previous id_token
and records that in the token: `OidcToken.idTokenRetainedFromPriorResponse` is `true`. The flag is persisted with the token,
and `OidcToken.fromResponse` never takes it from a server response.

## ID token validation

`OidcUserManagerBase.validateUser` checks an id_token's claims and returns the list of problems it found. Which checks apply
can depend on the flow that produced the token, so `validateUser`, `validateAndSaveUser` and `createUserFromToken` take an
`OidcIdTokenValidationContext`:

```dart
const OidcIdTokenValidationContext({
  OidcIdTokenSource source = OidcIdTokenSource.tokenEndpoint,
  String? authorizationCode, // the code returned with the id_token, checked against c_hash
  Duration? maxAge,          // the max_age that was requested, checked against auth_time
});
```

The `at_hash` and `c_hash` rules per `OidcIdTokenSource`:

| source | `at_hash` | `c_hash` |
|---|---|---|
| `authorizationEndpoint` (implicit, hybrid front channel) | required when an access_token came with the id_token, and must match | required when a code came with the id_token, and must match |
| `tokenEndpoint` (code exchange, password, device code) | checked when present | checked when present |
| `refresh` | checked when present, only if the refresh returned a new id_token | same |
| `storedSession` (`init()` revalidating the stored session) | checked when present, unless the stored id_token was retained across a refresh | same |

An id_token that was retained from an earlier response (`idTokenRetainedFromPriorResponse`) never has its hashes compared,
whatever the source: they were computed for the tokens of the response that issued it.

### When validation fails

`validateAndSaveUser` returns `null` and clears the pending nonce. It does not touch the stored session or `currentUser`, so
a login or refresh response that fails validation leaves an already signed-in session in place.

A stored session that fails revalidation during `init()` is handled by the cached-token loader. It calls
`OidcUserManagerSettings.shouldRemoveInvalidToken` (by default the session is removed unless `supportOfflineAuth` is on). If
the session is removed, the in-memory user is signed out too. If the policy keeps it, the token stays in the store but no user
is signed in with it.

### Migrating from 3.x

These are breaking changes for code that subclasses `OidcUserManagerBase`:

- `validateUser({user, metadata, authorizationCode, maxAge})` is now `validateUser({user, metadata, context})`.
- `validateAndSaveUser({user, metadata, authorizationCode, maxAge, reactToUserInfoUnauthorized})` is now
  `validateAndSaveUser({user, metadata, context, reactToUserInfoUnauthorized})`.
- `createUserFromToken({..., authorizationCode, maxAge, ...})` is now `createUserFromToken({..., context, ...})`.

Pass the old arguments through the context:

```dart
// before
validateUser(user: user, metadata: metadata, authorizationCode: code, maxAge: maxAge);
// after
validateUser(
  user: user,
  metadata: metadata,
  context: OidcIdTokenValidationContext(authorizationCode: code, maxAge: maxAge),
);
```

If you validate an id_token that came from the authorization endpoint, pass `source: OidcIdTokenSource.authorizationEndpoint`
to get the required-hash checks.

Behavior changes:

- `validateAndSaveUser` no longer deletes the stored token, user info and attributes when validation fails. If your subclass
  relied on that, remove the session yourself (for example with `forgetUser()`).
- `shouldRemoveInvalidToken` returning `false` now really keeps the stored token. Before, it had already been deleted.
- An implicit `id_token token` response whose id_token has no `at_hash` is now rejected (OpenID Connect Core §3.2.2.10).
- A refresh that keeps the old id_token no longer fails the `at_hash` check, either right away or when the app restarts.

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