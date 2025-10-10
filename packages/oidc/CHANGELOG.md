## 0.13.0

> Note: This release has breaking changes.

 - **FEAT**: add OIDC conformance test suite with API client and test runner. ([a651a7d8](https://github.com/Bdaya-Dev/oidc/commit/a651a7d814a424683d141fcc66156e5d17112baa))
 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FIX**: migrate to simple_secure_storage ([#270](https://github.com/Bdaya-Dev/oidc/issues/270)). ([723560a7](https://github.com/Bdaya-Dev/oidc/commit/723560a7e7d212290205724d7af6799f217ab778))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

## 0.12.1+2

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

## 0.12.1+1

 - Update a dependency to the latest release.

## 0.12.1

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

## 0.12.0
  - **TESTS**: Added integration tests to run the official oidc conformance suite, this pumps our test coverage from 22% to almost 45%, effectively doubling it!
    - Tests are run on ALL platforms (linux, macos, windows, android, ios, web).
    - Tests check the authorization code flow only for now.
  - **BREAKING** **FEAT**: Support for multiple `OidcUserManager` instances, by adding the `id` field to differentiate them.
    - [See docs entry](https://bdaya-dev.github.io/oidc/oidc-usage/#constructing-multiple-user-managers)
  - **FEAT**: Updated the example app to use the new `OidcUserManager.id`, with the ability to add your own custom managers in the UI.
  
  > [!IMPORTANT]
  > We have also officially submitted our package to the openid foundation for [certification](https://github.com/Bdaya-Dev/oidc/issues/11).
  
## 0.11.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

## 0.10.0

> Note: This release has breaking changes.

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

## 0.9.0+3

 - Update a dependency to the latest release.

## 0.9.0+2

 - Update a dependency to the latest release.

## 0.9.0+1

 - Update a dependency to the latest release.

## 0.9.0

> Note: This release has breaking changes.

 - **FIX**: oidc not passing options properly. ([b2fdf5fe](https://github.com/Bdaya-Dev/oidc/commit/b2fdf5fe38787e0b1d89c192545accefa99f9a7d))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.7.0

> Note: This release has breaking changes.

 - **BREAKING** **DEPS**: update min flutter version to 3.22.0 and min dart version to 3.4.0
 - **FEAT**: [WASM](https://docs.flutter.dev/platform-integration/web/wasm) support
 - **BREAKING** **REFACTOR**: moved all the non-flutter code in `OidcUserManager` to the `oidc_core` package as `OidcUserManagerBase`.
   - This means that you will have to add `import 'package:oidc_core/oidc_core.dart'` in addition to the usual `package:oidc` import.
 - **FIX**: improve `OidcEndpoints` error handling.
 - **FIX**: options passed in `OidcUserManagerSettings` were not getting used in implicit auth and logout.
 - **FEAT**: support offline auth via the setting `OidcUserManagerSettings.supportOfflineAuth` (`false` by default). 
   - This will keep the user logged in even if the app can't contact the server.
    > Note: While offline auth is convenient for users with unstable internet, it has a security risk, due to not being able to contact the IdP to refresh the token or get user info.
 - **FEAT**: add `getIdToken` to `OidcUserManagerSettings`.
   - This is useful for OAuth IdPs, As it allows the developer to make `OidcUserManager` use the access token as an id token for example.
 - **FEAT**: fixed some UI logic in the example.

 - **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31).   
 - **FEAT**: introduced a new dart package [oidc_web_core](https://pub.dev/packages/oidc_web_core) which exposes `OidcUserManagerWeb` and `OidcWebStore`. They can be used in dart web apps (like [ngdart](https://pub.dev/packages/ngdart)). And also support WASM.
 - **DOCS**: updated the [docs website](https://bdaya-dev.github.io/oidc/) with new entries to the added features.

## 0.5.2

 - **FEAT**: Use [package:clock](https://pub.dev/packages/clock) to get the current time instead of `DateTime.now()` to simplify testing.
 - **FIX**: Attempt to refresh expired tokens on initialization instead of throwing them away.
   - Now your users will have to login less.
   - This works only when there is a refresh token available.
   - Doesn't work with silent authorization (e.g. implicit auth and `prompt: none`).
 - **DOCS**: Updated docs and example.
 - **DEPS**: Use `jose_plus: ^0.4.4` which uses [package:clock](https://pub.dev/packages/clock) as well for JWT validation.

## 0.5.1

 - **FEAT**: Support overriding the discovery document.
 - **FEAT**: added `events` stream to `OidcUserManager`.

## 0.5.0+1

 - **DOCS**: added `sessionManagementSettings` to the wiki.
 - **DOCS**: add how to use accesstoken to the wiki.

## 0.5.0

 - **BREAKING CHANGE**: separated session management settings into its own class, in `OidcUserManagerSettings.sessionManagementSettings` and disabled it by default.

### Migration Guide

before:
```dart
OidcUserManagerSettings(
    sessionStatusCheckInterval: //...
    sessionStatusCheckStopIfErrorReceived: //...
)
```
after:
```dart
OidcUserManagerSettings(
    sessionManagementSettings: OidcSessionManagementSettings(
        enabled: true, // false by default.
        interval: //...
        stopIfErrorReceived: //...
    )
)
```

## 0.4.3

 - **FEAT**: add `refreshToken()` to `OidcUserManager`.

## 0.4.2

 - **FIX**: incorrect state handling.
 - **FEAT**: improve userInfo handling by adding `userInfoSettings` to `OidcUserManagerSettings`.

## 0.4.1

 - **FIX**: mac os and ios.
 - **FEAT**: added device authorization endpoint.

## 0.4.0+2

 - **DOCS**: fix PKCE link.

## 0.4.0+1

 - Update a dependency to the latest release.

## 0.4.0

## 0.3.1

 - **FEAT**: add response form userInfo endpoint to the user object.

## 0.3.0+1

 - Update a dependency to the latest release.

## 0.3.0

> Note: This release has breaking changes.

 - **BREAKING** **CHANGE**: all packages.

## 0.2.2

 - **FEAT**: support logout.

## 0.2.1

 - **FEAT**: initial version.

## 0.2.0+1

 - Update a dependency to the latest release.

## 0.2.0

 - Working authorization code flow, without refresh_token support.

## 0.1.1+1

 - Update a dependency to the latest release.


## 0.1.1

 - **FEAT**: added more helpers.

## 0.1.0+1

- Initial release of this plugin.
