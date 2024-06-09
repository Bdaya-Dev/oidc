## 0.7.0

> Note: This release has breaking changes.

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
 - **FEAT**: introduced a new package [oidc_web_core](https://pub.dev/packages/oidc_web_core) which exposes the use of `OidcUserManager` in the browser.
 - **DOCS**: updated the [docs website](https://bdaya-dev.github.io/oidc/) with new entries to the added features.

## 0.6.3

 - **DEPS**: Use `jose_plus: ^0.4.4` which uses [package:clock](https://pub.dev/packages/clock) JWT validation to simplify testing.
 - **FEAT**: Added `OidcDateTime` extension which contains `secondsSinceEpoch` and `fromSecondsSinceEpoch` helper methods

## 0.6.2

 - **FIX**: Serialize query parameters.
 - **FIX**: Removed false positive warnings that came from url_launcher

## 0.6.1

 - **FEAT**: Support overriding the discovery document.

## 0.6.0+1

 - **DOCS**: fixed docs link.

## 0.6.0

> Note: This release has breaking changes.

 - **FEAT**: added claimNames and claimSources to OidcUserInfoResponse.
 - **BREAKING** **CHANGE**: changed nonce to get stored in secureTokens namespace.

## 0.5.1

 - **FEAT**: added device authorization endpoint.

## 0.5.0+1

 - **FIX**: added `userInfo` to `fromIdToken`.
 - **DOCS**: added oidc_core docs and updated example.

## 0.5.0

## 0.4.1

 - **FEAT**: add response form userInfo endpoint to the user object.
 - **FEAT**: use package:clock for better testing.

## 0.4.0+1

 - **FIX**: token date calculations.

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **CHANGE**: all packages.

## 0.3.2

 - **FEAT**: support logout.

## 0.3.1

 - **FEAT**: initial version.

## 0.3.0

 - Working authorization code flow, without refresh_token support.

## 0.2.0

 - **FEAT**: added more helpers.

## 0.1.0+1

- Added topics.

## 0.1.0

- Initial version.
