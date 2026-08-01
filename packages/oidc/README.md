# oidc <!-- omit from toc -->
[![openid certification](http://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![Pub Version][pub_badge]][pub_link]
[![last commit][github_last_commit_image]][github_link]
[![codecov][coverage_badge]][coverage_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]


An [OpenId Connect RP (Relying Party)][spec_link] plugin for flutter.

Make sure you read the [![Wiki](https://img.shields.io/badge/wiki-purple)](https://bdaya-dev.github.io/oidc/) for extra information.

## Table Of Contents <!-- omit from toc -->

- [Introduction ✨](#introduction-)
- [Installation 💻](#installation-)
- [Usage 🛠️](#usage-️)
- [Features 📚](#features-)
  - [📜 Conformance](#-conformance)
  - [Implemented specs](#implemented-specs)
  - [WIP Specs](#wip-specs)


## Introduction ✨ 

This federated plugin builds on top of [![oidc_core][oidc_core_image]][oidc_core_link] to add platform-specific handling which is required by the spec (e.g. launching a browser, listening for redirect, etc...).

## Installation 💻

**❗ In order to start using this plugin you must have the [Flutter SDK][flutter_install_link] installed on your machine.**

Add to your `pubspec.yaml`:

```sh
dart pub add oidc oidc_default_store
```

## Usage 🛠️

After following the [Getting Started](https://bdaya-dev.github.io/oidc/oidc-getting-started/) steps, it's as easy as:

```dart
//1. create the manager:
final manager = OidcUserManager.lazy(
    discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
        Uri.parse('https://server.example.com'),
    ),
    // TODO: add other settings
);

//2. init()
await manager.init();

//3. listen to user changes
manager.userChanges().listen((user) {
  print('currentUser changed to $user');
});

//4. login
final newUser = await manager.loginAuthorizationCodeFlow();

//5. logout
await manager.logout();
```

## Features 📚

- 🧩 **Cross platform**: most features work on all platforms that can run flutter (Android, Ios, macos, web, windows, linux).
- 🧰 **High maintenance**: everyone hates having to fix an unmaintained package. you can trust that we will solve issues as soon as they pop up. especially since we use this package in all our production apps.
- ⚙️ **Customizability**: you can customize everything; Where to store the data, provide your own http client, extend requests/responses with your own data; whatever you want, you can do.
- 🚀 **Easy to use**: you mainly need to concern yourself with the `OidcUserManager` class, which is very well documented and has a simple interface.

### 📜 Conformance
- this package is an **[OpenID Connect Certified](https://openid.net/certification/) Relying Party**, and is additionally tested against [multiple conformance profiles](https://github.com/Bdaya-Dev/oidc/issues/11).

### Implemented specs

- [OpenId Connect Core 1.0][oidc_core_spec_link].
    - authorization code, hybrid (`loginHybridFlow`), and implicit flows.
- [OpenId Connect Discovery][discovery_spec_link].
    - §4 Provider Configuration: the `.well-known/openid-configuration` document (also RFC 8414 `.well-known/oauth-authorization-server`), with `issuer` validation and RFC 8414 `signed_metadata` verification.
    - §2 OpenID Provider Issuer Discovery: [WebFinger](https://www.rfc-editor.org/rfc/rfc7033) via `OidcEndpoints.getIssuerViaWebFinger('joe@example.com')`, including §2.1 identifier normalization (`OidcUtils.normalizeWebFingerIdentifier`), HTTPS-only transport with https-only redirects, and client-side `rel` filtering. Resolve the identifier to an issuer first, then pass that issuer to `OidcUserManager` — the manager does not run WebFinger on your behalf. Internationalized host names are not supported: convert them to their punycode A-label (RFC 5891) before calling, or normalization throws.
- [RP Initiated logout][rp_logout_link].
- [Front-Channel Logout][frontchannel_logout_link].
- [Authorization code grant][auth_code_link] with [PKCE][pkce_link].
- [Resource Owner Password Credentials Grant](https://www.rfc-editor.org/rfc/rfc6749#section-1.3.3).
- Automatic [Refresh Token](https://oauth.net/2/grant-types/refresh-token/) rotation.
- [OAuth 2.0 For Native Apps](https://datatracker.ietf.org/doc/html/rfc8252)
- [OAuth 2.0 Device Authorization Grant](https://datatracker.ietf.org/doc/html/rfc8628)
- [Session Management](https://openid.net/specs/openid-connect-session-1_0.html) (Web only)
- [Dynamic Client Registration](https://openid.net/specs/openid-connect-registration-1_0.html) ([RFC 7591](https://www.rfc-editor.org/rfc/rfc7591)).
    - Set `OidcUserManagerSettings.dynamicClientRegistration` and `init()` registers the client at the discovery document's `registration_endpoint` (optionally with an initial access token), then runs as the ISSUED credentials — the `clientCredentials` you pass to the constructor become a pre-registration seed. The issued `token_endpoint_auth_method` is what every back-channel call then uses, and it cannot be overridden — OpenID Connect Core §3.1.3.1 and §12.1 both require a client to "authenticate to the Token Endpoint using the authentication method registered for its `client_id`". `preferredTokenEndpointAuthMethod` decides only when the OP states none, where RFC 7591 §2 would otherwise pick `client_secret_basic` unaided.
    - **The manager registers once per issuer and then leaves it alone.** One immutable record is persisted under one key; every later launch restores it with **zero** network calls. That record is re-issued only when the request this build would send no longer matches the one it was issued for, or when its `client_secret` has expired. Nothing else in the library ever re-derives, rotates or replaces the client identity — see the non-goals below, which name the `OidcEndpoints` call you make instead.
    - **Public clients are supported.** RFC 7591 §3.2.1 makes `client_secret` OPTIONAL, so an OP that issues a `client_id` alone (and states no `token_endpoint_auth_method`) yields a public client authenticating with `none` — §2's `client_secret_basic` default only applies when a secret WAS issued.
    - The manager fills the metadata it can derive from your settings when your `buildRequest` leaves it null: `redirect_uris`, `scope`, `post_logout_redirect_uris`, `grant_types` / `response_types` (which default to `authorization_code` + `refresh_token` / `code`, because RFC 7591 §2 would otherwise register the client for `authorization_code` alone and break the automatic refresh), and `application_type`. **Flows you opt into must be declared:** add `OidcConstants_GrantType.deviceCode` for the device-code flow, or `implicit` plus the matching `responseTypes` for implicit/hybrid.
    - **`application_type` is derived from your redirect uris, not from the platform.** OpenID Connect Registration §2 states it as a client-side rule: a `native` client "MUST only register `redirect_uris` using custom URI schemes or loopback URLs using the `http` scheme", and a `web` client MUST use `https` and MUST NOT use `localhost`. So an Android or iOS app whose redirect is an App Link / Universal Link (`https://app.example.com/callback`) registers as **`web`** — declaring it `native` because it runs on a phone authors a request a conformant OP must reject. Set `applicationType` in your `buildRequest` to override.
    - RFC 7591 §3.2.1 lets the OP substitute its own values; the `scope`, `redirect_uris` and `post_logout_redirect_uris` it returns — not the ones that were requested — are what later authorization / token / end-session requests use. The `client_id` and `token_endpoint_auth_method` from the response likewise become the credentials every back-channel call presents.
    - **Loopback redirects are compared without their port** ([RFC 8252 §7.3](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3): "the authorization server MUST allow any port to be specified at the time of the request for loopback IP redirect URIs"). A desktop app whose listener binds an ephemeral port therefore matches its stored registration on every launch instead of minting a new OP-side client each run, and its authorization request keeps the **live** port even when the OP registered a different one. Only loopback `http` is normalized; every other uri, including `https`, compares byte-for-byte (RFC 3986 §6.2.1).
    - **Web is always registered as a PUBLIC client.** A browser app has nowhere to keep a secret ([OAuth 2.0 for Browser-Based Apps §6.1](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps)): the registration lives in `OidcStoreNamespace.secureTokens`, which on web is browser storage (`localStorage` via `shared_preferences` when no `FlutterSecureStorage` is passed to `OidcDefaultStore`), readable by any injected script. So on web the manager asks for `token_endpoint_auth_method: "none"` unless your `buildRequest` sets one — RFC 7591 §2 would otherwise default the client to the confidential `client_secret_basic` — and **refuses** a response that issues a `client_secret` anyway, with a typed `OidcException` thrown *before* anything is written. A provider that insists on issuing one is telling you the client belongs on a backend. The same refusal applies to a persisted registration carrying a secret, so a client registered on another platform is never replayed in a browser.
    - The record is persisted per-issuer in the secure store and re-used on every later launch — including across `forgetUser()`, since it is app-instance identity, not user identity. Staleness is measured against the request that was actually registered (after the defaults above are applied), not against your settings alone, so a change made *inside* `buildRequest` counts too: the fingerprint covers `redirect_uris`, `post_logout_redirect_uris`, `scope`, `grant_types`, `response_types` and `application_type`. It deliberately ignores `software_statement`, `jwks` and every purely descriptive member (`client_name`, `logo_uri`, …) — those are re-signed or edited on their own schedule, and RFC 7592 §2.2 update is their remedy, not orphaning the OP-side client for a fresh one.
    - **Nothing is ever deleted to make room for something that does not exist yet.** There is exactly one write of the registration key and exactly one removal — `forgetClientRegistration()`, which you call. A record that cannot be read (a locked keychain, an Android key invalidated by a biometric re-enrolment), cannot be parsed, or cannot be converted into credentials is treated as a **cache miss** and left exactly where it is; the replacement overwrites it in place once it has been issued **and** persisted. So an app update that changes the fingerprint and then launches offline keeps running as the previously-issued client — the `client_id` and the RFC 7592 `registration_access_token` survive — instead of being stranded with nothing. The write comes before the in-memory swap for the same reason: RFC 7591 registration is not idempotent, so a registration that could not be persisted is reported as a typed `OidcException` rather than silently minting another OP-side client on every launch.
    - **Non-goals**, each with the clause that makes it optional and the call you make instead. All of them are reachable today: the full RFC 7592 client-management surface already ships as `OidcEndpoints.registerClient` / `readClientConfiguration` / `updateClientConfiguration` / `deleteClientConfiguration`, and `OidcUserManagerBase.clientRegistration` hands you the `registration_client_uri` and `registration_access_token` they need.
        - **No automatic `client_secret` rotation.** RFC 7592 App. A.1: "the authorization server decides the frequency of the credential rotation and not the client" — the §2.1 read is an OP-driven affordance, not a client obligation, and an OP that conformantly returns the registration verbatim leaves a client-driven rotation loop with nothing to make progress on. Against an OP that *does* rotate on a schedule (Zitadel, Keycloak, Okta can be configured to) the session breaks at expiry with a typed `OidcException`; write `catch → OidcEndpoints.readClientConfiguration(...)`, or `catch → forgetClientRegistration() → build a new manager and init()`. The cost of the latter is a re-login and one orphaned OP-side client.
        - **No automatic re-registration when the provider disowns the client.** RFC 6749 §5.2 makes `invalid_client` three-way ambiguous ("unknown client, no client authentication included, or unsupported authentication method") and OpenID Connect Registration §4.4 forbids the 404 that would disambiguate it, so there is no reliable trigger. The rejection is surfaced to you untouched — nothing is re-registered, nothing is deleted — and the same `forgetClientRegistration()` handler applies. 0 of 7 mature RP libraries automate this.
        - **No RFC 7592 `PUT`/`DELETE` from the manager, and no orphan tracking or reaping.** RFC 7591 §5 assigns cleanup of registered-but-unused clients to the authorization server. Orphaned OP-side clients therefore accumulate untracked: one per cache miss, fingerprint change, expired-secret restore, storage fault, cross-manager race and web page load. Nothing counts, caps or reaps them, so **an OP with a per-tenant client quota will eventually reject registrations** with no hint that quota is the cause. Call `OidcEndpoints.deleteClientConfiguration` (§2.3) before `forgetClientRegistration()` if you want the OP-side client retired, and `updateClientConfiguration` (§2.2) to edit one in place.
        - **No cross-manager, cross-tab or cross-process coordination.** `OidcStore` has no compare-and-set, so nothing can be promised: two managers, two browser tabs, or two `OidcStore` objects over one backing store each mint a client and the last writer wins the key. Give managers that are meant to be independent distinct `managerId`s.
        - **No detection of a `client_id` the OP rotated on its own**, and no recovery from a POST whose response was lost in transit (that mints a client no design on any transport can ever name).
        - **`private_key_jwt` and mutual-TLS registrations are not automated**, because their credentials cannot be derived from a registration response — build `OidcClientAuthentication.privateKeyJwtGenerated` (or the mTLS variants) yourself and register the client out of band.
    - Why the non-goals are stated as non-goals rather than gaps: every one of them needs *durable control state* — a retry budget, an attempt counter, a rejection verdict, a generation number, a ledger of minted clients — and every such measure can be destroyed or reset by the very action it gates. There is none here. The store holds exactly one immutable record per issuer, containing only the OP's response and a digest of the request it was issued for, and `packages/oidc_core/test/dcr_invariants_test.dart` counts that mechanically: one write call site, one removal call site, one read call site, in three different methods, with no read-modify-write anywhere.


--- 
Plugin Generated by the [Very Good CLI][very_good_cli_link] 🤖

[flutter_install_link]: https://docs.flutter.dev/get-started/install

[github_link]: https://github.com/Bdaya-Dev/oidc
[github_last_commit_image]: https://img.shields.io/github/last-commit/bdaya-dev/oidc/main
[oidc_core_link]: https://pub.dev/packages/oidc_core
[oidc_core_image]: https://img.shields.io/badge/package-oidc__core-0175C2?logo=dart&logoColor=white

[spec_link]: https://openid.net/wg/connect/specifications/
[oidc_core_spec_link]: https://openid.net/specs/openid-connect-core-1_0.html
[auth_code_link]: https://oauth.net/2/grant-types/authorization-code/
[pkce_link]: https://datatracker.ietf.org/doc/html/rfc7636
[discovery_spec_link]: https://openid.net/specs/openid-connect-discovery-1_0.html
[rp_logout_link]: https://openid.net/specs/openid-connect-rpinitiated-1_0.html
[frontchannel_logout_link]: https://openid.net/specs/openid-connect-frontchannel-1_0.html

[coverage_link]: https://codecov.io/github/Bdaya-Dev/oidc
[coverage_badge]: https://codecov.io/github/Bdaya-Dev/oidc/graph/badge.svg?token=HSEDM6I7TH

[pub_badge]: https://img.shields.io/pub/v/oidc
[pub_link]: https://pub.dev/packages/oidc

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT

[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis

[very_good_cli_link]: https://github.com/VeryGoodOpenSource/very_good_cli