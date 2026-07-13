## 1.0.0

> Note: This release has breaking changes.

 - **FIX**: resolve all four library bugs; drive honest unit coverage to ~95% ([#368](https://github.com/Bdaya-Dev/oidc/issues/368)). ([c86bee17](https://github.com/Bdaya-Dev/oidc/commit/c86bee17189a0a70fee947c685e91a55062b1d35))
 - **FIX**(oidc_platform_interface): declare meta as a direct dependency. ([21b79a43](https://github.com/Bdaya-Dev/oidc/commit/21b79a436649435c97221a4adf29321c9873d2bd))
 - **FIX**(native): harden iOS threading, simplify Android redirect to one-line setup. ([a7553f32](https://github.com/Bdaya-Dev/oidc/commit/a7553f326c1d67ac2bd057b0864688d73df24661))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **BREAKING** **FEAT**(native): migrate native transport to Pigeon + automate codegen. ([fc7606f3](https://github.com/Bdaya-Dev/oidc/commit/fc7606f3329cc493281a438ff76482436b018709))
 - **BREAKING** **FEAT**(oidc_macos): first-party ASWebAuthenticationSession; drop flutter_appauth. ([dc13f411](https://github.com/Bdaya-Dev/oidc/commit/dc13f411a3bfca4572a0f0e8fea2705365314d3c))
 - **BREAKING** **CHORE**: v1 dependency upgrade + drop the pigeon global-tool wrapper. ([45b62a3e](https://github.com/Bdaya-Dev/oidc/commit/45b62a3ef3f5b42cfb590111c9e37e144bbc11b0))

## 0.7.0+3

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

## 0.7.0+2

 - Update a dependency to the latest release.

## 0.7.0+1

 - Update a dependency to the latest release.

## 0.7.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

## 0.6.0+9

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

## 0.6.0+8

 - Update a dependency to the latest release.

## 0.6.0+7

 - Update a dependency to the latest release.

## 0.6.0+6

 - Update a dependency to the latest release.

## 0.6.0+5

 - Update a dependency to the latest release.

## 0.6.0+4

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

## 0.6.0+3

 - Update a dependency to the latest release.

## 0.6.0+2

 - Update a dependency to the latest release.

## 0.6.0+1

 - Update a dependency to the latest release.

## 0.6.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.5.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.4.0

> Note: This release has breaking changes.

 - Update a dependency to the latest release.
 - **BREAKING** **FEAT**: added `Map<String, dynamic> prepareForRedirectFlow(OidcPlatformSpecificOptions options)` to `OidcPlatform` to solve [issue #31](https://github.com/Bdaya-Dev/oidc/issues/31).

## 0.3.1+2

 - Update a dependency to the latest release.

## 0.3.1+1

 - Update a dependency to the latest release.

## 0.3.1

 - **FEAT**: implement the session management spec.

## 0.3.0+5

 - Update a dependency to the latest release.

## 0.3.0+4

 - Update a dependency to the latest release.

## 0.3.0+3

 - Update a dependency to the latest release.

## 0.3.0+2

 - Update a dependency to the latest release.

## 0.3.0+1

 - Update a dependency to the latest release.

## 0.3.0

> Note: This release has breaking changes.

 - **BREAKING** **CHANGE**: all packages.
 - **BREAKING** **CHANGE**: new platform interface.

## 0.2.1

 - **FEAT**: support logout.

## 0.2.0+1

 - Update a dependency to the latest release.

## 0.2.0

 - Working authorization code flow, without refresh_token support.

## 0.1.0+2

 - Update a dependency to the latest release.

# 0.1.0+1

* Initial release.
