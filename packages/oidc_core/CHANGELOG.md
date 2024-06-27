## 0.8.0

> Note: This release has breaking changes.

- **BREAKING** : Remove hashed nonce from secure storage.
- **FEAT**: hash nonce before sending it to auth server (spec: https://openid.net/specs/openid-connect-core-1_0.html#NonceNotes).
- **FEAT**: compare the hashed nonce with IDToken nonce.

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
