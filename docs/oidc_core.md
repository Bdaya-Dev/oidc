
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

When a response for a signed-in user has no `id_token` (typically a refresh, which OpenID Connect Core §12.2 allows),
`replaceToken` keeps the previous id_token and records that in the token: `OidcToken.idTokenRetainedFromPriorResponse` is
`true`. The flag is persisted with the token, and `OidcToken.fromResponse` never takes it from a server response.

## ID token validation

`OidcUserManagerBase.validateUser` checks an id_token's claims and returns the list of problems it found. Which checks apply
can depend on the flow that produced the token, so `validateUser`, `validateAndSaveUser` and `createUserFromToken` take an
`OidcIdTokenValidationContext`:

```dart
const OidcIdTokenValidationContext({
  OidcIdTokenSource source = OidcIdTokenSource.tokenEndpoint,
  String? authorizationCode, // the code returned with the id_token, checked against c_hash
  String? accessToken,       // the access_token returned with the id_token, checked against at_hash
  Duration? maxAge,          // the max_age that was requested, checked against auth_time
});
```

The hash rules are judged from the response's own tokens. When a user is already signed in, the user built for a new
response keeps the previous session's access_token if the response returned none, so the access_token to check is passed in
the context. For `authorizationEndpoint`, `accessToken: null` means the response returned no access_token (`id_token`,
`code id_token`). For the other sources, `null` falls back to the user's own access_token. `createUserFromToken` fills
`accessToken` in from the response token it is given.

The `at_hash` and `c_hash` rules per `OidcIdTokenSource`:

| source | `at_hash` | `c_hash` |
|---|---|---|
| `authorizationEndpoint` (implicit, hybrid front channel) | required when the response returned an access_token, and must match it | required when the response returned a code, and must match it |
| `tokenEndpoint` (code exchange, password, device code) | checked when present | checked when present |
| `refresh` | checked when present, only if the refresh returned a new id_token | same |
| `storedSession` (`init()` revalidating the stored session) | checked when present, unless the stored id_token was retained from an earlier response | same |

An id_token retained from an earlier response (`idTokenRetainedFromPriorResponse`) was not issued with the current tokens,
so its hashes are never required. A refresh, and the stored session it produced, do not compare them either (§12.2). Any
other response that kept the previous id_token, such as a password re-login whose response has no id_token, still
compares a hash the kept id_token carries, as before.

### When validation fails

`validateAndSaveUser` returns `null` and clears the pending nonce. It does not touch the stored session or `currentUser`, so
a login or refresh response that fails validation leaves an already signed-in session in place.

A stored session that fails revalidation during `init()` is handled by the cached-token loader. It calls
`OidcUserManagerSettings.shouldRemoveInvalidToken` (by default the session is removed unless `supportOfflineAuth` is on). If
the policy keeps it, the token stays in the store. Either way no user is signed in with it: if `init()` had already signed a
user in with that session (by refreshing it, or by cache-first restoring it), that user is signed out again.

### Migrating from 3.x

These are breaking changes for code that subclasses `OidcUserManagerBase`:

- `validateUser({user, metadata, authorizationCode, maxAge})` is now `validateUser({user, metadata, context})`.
- `validateAndSaveUser({user, metadata, authorizationCode, maxAge, reactToUserInfoUnauthorized})` is now
  `validateAndSaveUser({user, metadata, context, reactToUserInfoUnauthorized})`.
- `createUserFromToken({..., authorizationCode, maxAge, ...})` is now `createUserFromToken({..., context, ...})`.
- `OidcIdTokenValidationContext.accessToken` is the access_token returned with the id_token. For the
  `authorizationEndpoint` source, `at_hash` is checked against it and never against the validated user's token.

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

If you call `validateUser` or `validateAndSaveUser` for an id_token that came from the authorization endpoint, pass
`source: OidcIdTokenSource.authorizationEndpoint` and the access_token of that response as `accessToken` to get the
required-hash checks. Without `accessToken`, that source treats the response as having returned no access_token.

Behavior changes:

- `validateAndSaveUser` no longer deletes the stored token, user info and attributes when validation fails. If your subclass
  relied on that, remove the session yourself (for example with `forgetUser()`).
- `shouldRemoveInvalidToken` returning `false` now really keeps the stored token. Before, it had already been deleted.
- An implicit `id_token token` response whose id_token has no `at_hash` is now rejected (OpenID Connect Core §3.2.2.10).
- A refresh that keeps the old id_token no longer fails the `at_hash` check, either right away or when the app restarts.
- `at_hash` is compared with the access_token of the response that returned the id_token, not with one a signed-in user
  kept from an earlier response.
- When `init()` refreshes the stored session and the revalidation that follows fails, the refreshed user is now signed out
  even if `shouldRemoveInvalidToken` keeps the session in the store.

## Discovery document issuer validation

Per OIDC Discovery 1.0 §4.3 / RFC 8414 §3.3, `OidcUserManagerSettings.strictIssuerValidation` (default `true`) rejects a
discovery document whose `issuer` does not match the issuer it was expected to describe. A rejected document is neither
persisted nor kept: after a failed `init()` every flow throws instead of building a request, and a rejected background
(cache-first) refresh keeps the previously validated document. Set `OidcUserManagerSettings.expectedIssuer` when a provider's issuer cannot be derived
from the discovery URL; `strictIssuerValidation: false` only warns instead of rejecting, for providers `expectedIssuer`
cannot describe either.

### Azure AD B2C

With B2C's default "Issuer (iss) claim" setting, the discovery `issuer` is not the discovery URL's prefix: the tenant
domain is replaced by the tenant GUID, the policy segment is dropped, and a trailing slash is added. For example,
`https://fabrikamb2c.b2clogin.com/fabrikamb2c.onmicrosoft.com/B2C_1_susi/v2.0/.well-known/openid-configuration` returns
`"issuer": "https://fabrikamb2c.b2clogin.com/775527ff-9a37-4307-8b3d-cc311f58d925/v2.0/"`. See Microsoft's
[token compatibility settings](https://learn.microsoft.com/azure/active-directory-b2c/tokens-overview#compatibility) and,
for custom policies, [`IssuanceClaimPattern`](https://learn.microsoft.com/azure/active-directory-b2c/jwt-issuer-technical-profile).

Options, most to least preferred:

1. Switch the user flow/custom policy's "Issuer (iss) claim" (`IssuanceClaimPattern` in custom policies) to
   `AuthorityWithTfp`, and use the matching `/tfp/.../.well-known/openid-configuration` discovery URL. The resulting
   issuer (`https://<host>/tfp/<tenant-GUID>/<policy>/v2.0/`) is exactly what that URL derives to, so no `expectedIssuer`
   is needed. This is Microsoft's documented option for OpenID Connect Discovery 1.0 compliance. The comparison is
   case-sensitive, so the discovery URL's tenant and policy segments must use the casing B2C emits in the issuer
   (otherwise set `expectedIssuer`).
2. Keep B2C's default issuer format and set `expectedIssuer` to the actual issuer B2C returns (as in the example above).
3. Last resort: set `strictIssuerValidation: false`.

### Microsoft Entra ID multi-tenant (`/common`, `/organizations`)

Entra's multi-tenant discovery `issuer` is a template (`https://login.microsoftonline.com/{tenantid}/v2.0`) rather than a
concrete URL. `OidcUtils.discoveryIssuerMatches` matches that template against an `expectedIssuer` pinned to a concrete
tenant (`https://login.microsoftonline.com/<tenant>/v2.0`), so pinning `expectedIssuer` is all a multi-tenant RP needs; see
[#389](https://github.com/Bdaya-Dev/oidc/issues/389).

### Other Entra authorities

| Authority | Discovery `issuer` | What to set |
| --- | --- | --- |
| Tenant by domain name, e.g. `.../contoso.onmicrosoft.com/v2.0` | `https://login.microsoftonline.com/<tenant-GUID>/v2.0` | Use the GUID authority, or `expectedIssuer` = that issuer |
| `.../consumers/v2.0` | `https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0` (concrete, not a template) | `expectedIssuer` = that issuer |
| v1 `https://login.microsoftonline.com/common` | `https://sts.windows.net/{tenantid}/` | `expectedIssuer` = `https://sts.windows.net/<tenant-GUID>/` |

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