## 0.9.0

> Note: This release has breaking changes.

 - **FIX**: resolve all four library bugs; drive honest unit coverage to ~95% ([#368](https://github.com/Bdaya-Dev/oidc/issues/368)). ([c86bee17](https://github.com/Bdaya-Dev/oidc/commit/c86bee17189a0a70fee947c685e91a55062b1d35))
 - **FIX**(example): use FlutterFragmentActivity for Auth Tab (ComponentActivity). ([e6e9be47](https://github.com/Bdaya-Dev/oidc/commit/e6e9be47683d80897a6dce6f92433408c89155f4))
 - **FIX**(oidc_android): remove duplicate mainHandler declaration. ([ae0f70c2](https://github.com/Bdaya-Dev/oidc/commit/ae0f70c20b4c011f35365be44673713622eeacc9))
 - **FIX**(oidc_android): use flowId self-check instead of Handler.removeCallbacks. ([c8f585a3](https://github.com/Bdaya-Dev/oidc/commit/c8f585a36912af3ef379fdb88eb046035b8d22dd))
 - **FIX**: pre-v1 correctness — certification claim, license, Android queries, honest native option docs. ([3b8ef447](https://github.com/Bdaya-Dev/oidc/commit/3b8ef447f2a1c0af68ec6711c77d435531fb827f))
 - **FIX**(native): harden iOS threading, simplify Android redirect to one-line setup. ([a7553f32](https://github.com/Bdaya-Dev/oidc/commit/a7553f326c1d67ac2bd057b0864688d73df24661))
 - **FEAT**(android): Auth Tab redirect-capture path (Phase 4, opt-in). ([0b80aaf2](https://github.com/Bdaya-Dev/oidc/commit/0b80aaf2a253f31f7b4fee62e91a0f10fdd1fa25))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **FEAT**(android): apply typed Custom Tabs options natively (Phase 1). ([10e903eb](https://github.com/Bdaya-Dev/oidc/commit/10e903ebcbdb7fa8cb33c7f2f4d30b58db26d33e))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))
 - **BREAKING** **FEAT**(oidc_android): switch to Auth Tab only, remove Custom Tabs path. ([05bf0181](https://github.com/Bdaya-Dev/oidc/commit/05bf01811e299c472d49efb303fb657c939f0bd4))
 - **BREAKING** **FEAT**(oidc_android): add flowTimeoutSeconds to fix headless CI hang. ([01c844f5](https://github.com/Bdaya-Dev/oidc/commit/01c844f5bd98a3d983b9e50f9fa2192ed7013e50))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **BREAKING** **FEAT**(native): migrate native transport to Pigeon + automate codegen. ([fc7606f3](https://github.com/Bdaya-Dev/oidc/commit/fc7606f3329cc493281a438ff76482436b018709))
 - **BREAKING** **FEAT**(oidc_android): replace flutter_appauth with first-party Custom Tabs auth. ([ddd64296](https://github.com/Bdaya-Dev/oidc/commit/ddd642968ca95cc57f0745d3ec59b5d9bc3c290f))

## 0.8.0+3

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

## 0.8.0+2

 - Update a dependency to the latest release.

## 0.8.0+1

 - Update a dependency to the latest release.

## 0.8.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

## 0.7.0+5

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

## 0.7.0+4

 - Update a dependency to the latest release.

## 0.7.0+3

 - Update a dependency to the latest release.

## 0.7.0+2

 - Update a dependency to the latest release.

## 0.7.0+1

 - Update a dependency to the latest release.

## 0.7.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

## 0.6.0+3

 - Update a dependency to the latest release.

## 0.6.0+2

 - Update a dependency to the latest release.

## 0.6.0+1

 - Update a dependency to the latest release.

## 0.6.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.4.0

> Note: This release has breaking changes.

 - Update a dependency to the latest release.

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

## 0.2.1

 - **FEAT**: support logout.

## 0.2.0+2

 - Update a dependency to the latest release.

## 0.2.0+1

 - Update a dependency to the latest release.

## 0.2.0

 - Working authorization code flow, without refresh_token support.

## 0.1.0+2

 - Update a dependency to the latest release.

# 0.1.0+1

- Initial release of this plugin.
