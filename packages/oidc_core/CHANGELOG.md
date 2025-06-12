## 0.13.1

 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))
 - **FEAT**: enhance OIDC conformance token handling in integration tests and user manager. ([1947c29f](https://github.com/Bdaya-Dev/oidc/commit/1947c29fbd9ab20d0bd62065f697dac2fba1f682))
 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

## 0.13.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

## 0.12.0

> Note: This release has breaking changes.

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

## 0.11.0

> Note: This release has breaking changes.

 - **FIX**: set idTokenHint null if no postLogoutRedirectUri set ([#192](https://github.com/Bdaya-Dev/oidc/issues/192)). ([bcf47cbd](https://github.com/Bdaya-Dev/oidc/commit/bcf47cbde8c36619ce89055b296fd162eb3c30f9))
 - **BREAKING** **CHORE**: regenerate files with new json serializer. ([35523a61](https://github.com/Bdaya-Dev/oidc/commit/35523a617753d3058e7065be79b2a4cf2f322199))

## 0.10.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: minimal implement nonce hashing  ([#172](https://github.com/Bdaya-Dev/oidc/issues/172)). ([d4daf387](https://github.com/Bdaya-Dev/oidc/commit/d4daf387b660332513fcb13dcd1e855098c566ee))

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
