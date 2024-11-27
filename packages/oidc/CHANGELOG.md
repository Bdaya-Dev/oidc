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
