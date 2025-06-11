## 0.11.1

 - **FIX**: streamline external user agent configuration and add custom LLDB init file for iOS scheme. ([57b0e347](https://github.com/Bdaya-Dev/oidc/commit/57b0e3473abfa6433cac78d0239d815ac863b07e))
 - **FIX**: add platform-specific options for OIDC user manager and enable GPU validation in macOS scheme. ([e9dd4eaf](https://github.com/Bdaya-Dev/oidc/commit/e9dd4eaf5dd249ea353f6a22c0fe4cc3be4c7ee5))
 - **FIX**: update Chrome executable path in Linux setup script. ([8b50aeab](https://github.com/Bdaya-Dev/oidc/commit/8b50aeab2c6738582421c44c9d8f0b85c131d011))
 - **FIX**: enable headless mode for Chrome in default Linux applications setup. ([dda1c2dc](https://github.com/Bdaya-Dev/oidc/commit/dda1c2dc9f43a034d553eb043294b80e000f82f3))
 - **FIX**: update integration test setup and add script for default Linux applications. ([bc5cc945](https://github.com/Bdaya-Dev/oidc/commit/bc5cc9454f652acc28e0a7ddd93788339a46f508))
 - **FIX**: remove unused import and simplify null check in secret page. ([427ca35a](https://github.com/Bdaya-Dev/oidc/commit/427ca35a9f4720400bd5b51639ab347895505de7))
 - **FIX**: update platform detection for Web and remove WASM support. ([9de7ad56](https://github.com/Bdaya-Dev/oidc/commit/9de7ad56bfe0d9d49479e015a0bcb0c5e53be26b))
 - **FIX**: remove commented-out OIDC conformance token from app_test.dart. ([fe377835](https://github.com/Bdaya-Dev/oidc/commit/fe377835b946bdacb2b180dbbc7a02d8ce1aed71))
 - **FEAT**: enhance OIDC example app UI and initialization logic. ([e6a25de7](https://github.com/Bdaya-Dev/oidc/commit/e6a25de766b777ea06ee4b4cb3c96567a3b81232))
 - **FEAT**: log OIDC conformance token during integration test execution. ([b1db4893](https://github.com/Bdaya-Dev/oidc/commit/b1db489326f5ffdd4b2f16eae04b9795ac8212c9))
 - **FEAT**: enhance OIDC conformance token handling in integration tests and user manager. ([1947c29f](https://github.com/Bdaya-Dev/oidc/commit/1947c29fbd9ab20d0bd62065f697dac2fba1f682))
 - **FEAT**: add OIDC_CONFORMANCE_TOKEN to integration test workflows and adjust test initialization order. ([b74f2960](https://github.com/Bdaya-Dev/oidc/commit/b74f29605313022657e739a6e8b09538a3a9236d))
 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

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
