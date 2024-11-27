## 0.9.1

 - **FEAT**: Added `OidcTokenExpiredEvent` and `OidcTokenExpiringEvent` ([#91](https://github.com/Bdaya-Dev/oidc/issues/91)). ([85ba41ce](https://github.com/Bdaya-Dev/oidc/commit/85ba41cef689b852e102a65ec6550580489fb4bc))

## 0.9.0

> Note: This release has breaking changes.

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.7.0

> Note: This release has breaking changes.

  - **BREAKING** **DEPS**: update min dart version to 3.4.0
  - **FEAT**: added `OidcUserManagerBase`.     
  - **FIX**: improve `OidcEndpoints` error handling.
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
