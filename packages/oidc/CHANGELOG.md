## 0.5.2

 - Updated docs and example

 - **FIX**: Attempt to refresh expired tokens instead of throwing them away.

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