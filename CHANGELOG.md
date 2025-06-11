# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-06-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc` - `v0.11.1`](#oidc---v0111)
 - [`oidc_core` - `v0.13.1`](#oidc_core---v0131)
 - [`oidc_default_store` - `v0.3.1`](#oidc_default_store---v031)
 - [`oidc_desktop` - `v0.5.1`](#oidc_desktop---v051)
 - [`oidc_linux` - `v0.3.1`](#oidc_linux---v031)
 - [`oidc_web_core` - `v0.3.1`](#oidc_web_core---v031)
 - [`oidc_platform_interface` - `v0.6.0+6`](#oidc_platform_interface---v0606)
 - [`oidc_ios` - `v0.7.0+2`](#oidc_ios---v0702)
 - [`oidc_macos` - `v0.7.0+2`](#oidc_macos---v0702)
 - [`oidc_android` - `v0.7.0+2`](#oidc_android---v0702)
 - [`oidc_web` - `v0.6.0+6`](#oidc_web---v0606)
 - [`oidc_flutter_appauth` - `v0.6.0+2`](#oidc_flutter_appauth---v0602)
 - [`oidc_windows` - `v0.3.1+11`](#oidc_windows---v03111)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+6`
 - `oidc_ios` - `v0.7.0+2`
 - `oidc_macos` - `v0.7.0+2`
 - `oidc_android` - `v0.7.0+2`
 - `oidc_web` - `v0.6.0+6`
 - `oidc_flutter_appauth` - `v0.6.0+2`
 - `oidc_windows` - `v0.3.1+11`

---

#### `oidc` - `v0.11.1`

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

#### `oidc_core` - `v0.13.1`

 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))
 - **FEAT**: enhance OIDC conformance token handling in integration tests and user manager. ([1947c29f](https://github.com/Bdaya-Dev/oidc/commit/1947c29fbd9ab20d0bd62065f697dac2fba1f682))
 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

#### `oidc_default_store` - `v0.3.1`

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

#### `oidc_desktop` - `v0.5.1`

 - **FIX**: enable headless mode for Chrome in default Linux applications setup. ([dda1c2dc](https://github.com/Bdaya-Dev/oidc/commit/dda1c2dc9f43a034d553eb043294b80e000f82f3))
 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))
 - **FEAT**: improve auth URL launching with enhanced error handling and logging. ([58f3881a](https://github.com/Bdaya-Dev/oidc/commit/58f3881a3e629896acf933862bb1e6a131bb6b4e))

#### `oidc_linux` - `v0.3.1`

 - **FIX**: enable headless mode for Chrome in default Linux applications setup. ([dda1c2dc](https://github.com/Bdaya-Dev/oidc/commit/dda1c2dc9f43a034d553eb043294b80e000f82f3))
 - **FIX**: add headless option to chrome launch for improved URL handling. ([30256871](https://github.com/Bdaya-Dev/oidc/commit/30256871e2af74a5e7870aae19ff4eb887ba231d))
 - **FIX**: update URL launcher to use google-chrome-stable with logging options. ([59600c29](https://github.com/Bdaya-Dev/oidc/commit/59600c29f5fec728a47f545c8a9f8757113a8885))
 - **FIX**: update browser launch command for headless mode and improve logging in OidcLinux. ([11ba5fa9](https://github.com/Bdaya-Dev/oidc/commit/11ba5fa9a53d734a2a2a4590246fedbbfb510640))
 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))

#### `oidc_web_core` - `v0.3.1`

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))


## 2025-06-06

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.11.0`](#oidc---v0110)
 - [`oidc_core` - `v0.13.0`](#oidc_core---v0130)
 - [`oidc_default_store` - `v0.3.0`](#oidc_default_store---v030)

Packages with other changes:

 - [`oidc_web_core` - `v0.3.0+5`](#oidc_web_core---v0305)
 - [`oidc_desktop` - `v0.5.0+5`](#oidc_desktop---v0505)
 - [`oidc_ios` - `v0.7.0+1`](#oidc_ios---v0701)
 - [`oidc_platform_interface` - `v0.6.0+5`](#oidc_platform_interface---v0605)
 - [`oidc_macos` - `v0.7.0+1`](#oidc_macos---v0701)
 - [`oidc_android` - `v0.7.0+1`](#oidc_android---v0701)
 - [`oidc_web` - `v0.6.0+5`](#oidc_web---v0605)
 - [`oidc_linux` - `v0.3.0+16`](#oidc_linux---v03016)
 - [`oidc_flutter_appauth` - `v0.6.0+1`](#oidc_flutter_appauth---v0601)
 - [`oidc_windows` - `v0.3.1+10`](#oidc_windows---v03110)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_web_core` - `v0.3.0+5`
 - `oidc_desktop` - `v0.5.0+5`
 - `oidc_ios` - `v0.7.0+1`
 - `oidc_platform_interface` - `v0.6.0+5`
 - `oidc_macos` - `v0.7.0+1`
 - `oidc_android` - `v0.7.0+1`
 - `oidc_web` - `v0.6.0+5`
 - `oidc_linux` - `v0.3.0+16`
 - `oidc_flutter_appauth` - `v0.6.0+1`
 - `oidc_windows` - `v0.3.1+10`

---

#### `oidc` - `v0.11.0`

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

#### `oidc_core` - `v0.13.0`

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

#### `oidc_default_store` - `v0.3.0`

 - **FIX**: oidc_default_store init() loads the shared preferences again and does not check if already given in ctor [#226](https://github.com/Bdaya-Dev/oidc/issues/226). ([111b0a98](https://github.com/Bdaya-Dev/oidc/commit/111b0a98e2eb57b32ab3c9ace3d9b543a2683f34))
 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))


## 2025-04-16

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.10.0`](#oidc---v0100)
 - [`oidc_android` - `v0.7.0`](#oidc_android---v070)
 - [`oidc_core` - `v0.12.0`](#oidc_core---v0120)
 - [`oidc_flutter_appauth` - `v0.6.0`](#oidc_flutter_appauth---v060)
 - [`oidc_ios` - `v0.7.0`](#oidc_ios---v070)
 - [`oidc_macos` - `v0.7.0`](#oidc_macos---v070)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+15`](#oidc_default_store---v02015)
 - [`oidc_platform_interface` - `v0.6.0+4`](#oidc_platform_interface---v0604)
 - [`oidc_web_core` - `v0.3.0+4`](#oidc_web_core---v0304)
 - [`oidc_linux` - `v0.3.0+15`](#oidc_linux---v03015)
 - [`oidc_windows` - `v0.3.1+9`](#oidc_windows---v0319)
 - [`oidc_desktop` - `v0.5.0+4`](#oidc_desktop---v0504)
 - [`oidc_web` - `v0.6.0+4`](#oidc_web---v0604)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_linux` - `v0.3.0+15`
 - `oidc_windows` - `v0.3.1+9`
 - `oidc_desktop` - `v0.5.0+4`
 - `oidc_web` - `v0.6.0+4`

---

#### `oidc` - `v0.10.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_android` - `v0.7.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_core` - `v0.12.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_flutter_appauth` - `v0.6.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_ios` - `v0.7.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_macos` - `v0.7.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_default_store` - `v0.2.0+15`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

#### `oidc_platform_interface` - `v0.6.0+4`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

#### `oidc_web_core` - `v0.3.0+4`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))


## 2025-04-13

### Changes

---

Packages with breaking changes:

 - [`oidc_core` - `v0.11.0`](#oidc_core---v0110)

Packages with other changes:

 - [`oidc_platform_interface` - `v0.6.0+3`](#oidc_platform_interface---v0603)
 - [`oidc_android` - `v0.6.0+3`](#oidc_android---v0603)
 - [`oidc_linux` - `v0.3.0+14`](#oidc_linux---v03014)
 - [`oidc_ios` - `v0.6.0+3`](#oidc_ios---v0603)
 - [`oidc_windows` - `v0.3.1+8`](#oidc_windows---v0318)
 - [`oidc_flutter_appauth` - `v0.5.0+3`](#oidc_flutter_appauth---v0503)
 - [`oidc_macos` - `v0.6.0+3`](#oidc_macos---v0603)
 - [`oidc_desktop` - `v0.5.0+3`](#oidc_desktop---v0503)
 - [`oidc_default_store` - `v0.2.0+14`](#oidc_default_store---v02014)
 - [`oidc_web_core` - `v0.3.0+3`](#oidc_web_core---v0303)
 - [`oidc_web` - `v0.6.0+3`](#oidc_web---v0603)
 - [`oidc` - `v0.9.0+3`](#oidc---v0903)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+3`
 - `oidc_android` - `v0.6.0+3`
 - `oidc_linux` - `v0.3.0+14`
 - `oidc_ios` - `v0.6.0+3`
 - `oidc_windows` - `v0.3.1+8`
 - `oidc_flutter_appauth` - `v0.5.0+3`
 - `oidc_macos` - `v0.6.0+3`
 - `oidc_desktop` - `v0.5.0+3`
 - `oidc_default_store` - `v0.2.0+14`
 - `oidc_web_core` - `v0.3.0+3`
 - `oidc_web` - `v0.6.0+3`
 - `oidc` - `v0.9.0+3`

---

#### `oidc_core` - `v0.11.0`

 - **FIX**: set idTokenHint null if no postLogoutRedirectUri set ([#192](https://github.com/Bdaya-Dev/oidc/issues/192)). ([bcf47cbd](https://github.com/Bdaya-Dev/oidc/commit/bcf47cbde8c36619ce89055b296fd162eb3c30f9))
 - **BREAKING** **CHORE**: regenerate files with new json serializer. ([35523a61](https://github.com/Bdaya-Dev/oidc/commit/35523a617753d3058e7065be79b2a4cf2f322199))


## 2025-04-12

### Changes

---

Packages with breaking changes:

 - [`oidc_core` - `v0.10.0`](#oidc_core---v0100)

Packages with other changes:

 - [`oidc_platform_interface` - `v0.6.0+2`](#oidc_platform_interface---v0602)
 - [`oidc_linux` - `v0.3.0+13`](#oidc_linux---v03013)
 - [`oidc_android` - `v0.6.0+2`](#oidc_android---v0602)
 - [`oidc_ios` - `v0.6.0+2`](#oidc_ios---v0602)
 - [`oidc_windows` - `v0.3.1+7`](#oidc_windows---v0317)
 - [`oidc_flutter_appauth` - `v0.5.0+2`](#oidc_flutter_appauth---v0502)
 - [`oidc_macos` - `v0.6.0+2`](#oidc_macos---v0602)
 - [`oidc_desktop` - `v0.5.0+2`](#oidc_desktop---v0502)
 - [`oidc_web_core` - `v0.3.0+2`](#oidc_web_core---v0302)
 - [`oidc_default_store` - `v0.2.0+13`](#oidc_default_store---v02013)
 - [`oidc_web` - `v0.6.0+2`](#oidc_web---v0602)
 - [`oidc` - `v0.9.0+2`](#oidc---v0902)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+2`
 - `oidc_linux` - `v0.3.0+13`
 - `oidc_android` - `v0.6.0+2`
 - `oidc_ios` - `v0.6.0+2`
 - `oidc_windows` - `v0.3.1+7`
 - `oidc_flutter_appauth` - `v0.5.0+2`
 - `oidc_macos` - `v0.6.0+2`
 - `oidc_desktop` - `v0.5.0+2`
 - `oidc_web_core` - `v0.3.0+2`
 - `oidc_default_store` - `v0.2.0+13`
 - `oidc_web` - `v0.6.0+2`
 - `oidc` - `v0.9.0+2`

---

#### `oidc_core` - `v0.10.0`

 - **BREAKING** **FEAT**: minimal implement nonce hashing  ([#172](https://github.com/Bdaya-Dev/oidc/issues/172)). ([d4daf387](https://github.com/Bdaya-Dev/oidc/commit/d4daf387b660332513fcb13dcd1e855098c566ee))


## 2024-11-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc_core` - `v0.9.1`](#oidc_core---v091)
 - [`oidc` - `v0.9.0+1`](#oidc---v0901)
 - [`oidc_flutter_appauth` - `v0.5.0+1`](#oidc_flutter_appauth---v0501)
 - [`oidc_desktop` - `v0.5.0+1`](#oidc_desktop---v0501)
 - [`oidc_ios` - `v0.6.0+1`](#oidc_ios---v0601)
 - [`oidc_web` - `v0.6.0+1`](#oidc_web---v0601)
 - [`oidc_android` - `v0.6.0+1`](#oidc_android---v0601)
 - [`oidc_default_store` - `v0.2.0+12`](#oidc_default_store---v02012)
 - [`oidc_platform_interface` - `v0.6.0+1`](#oidc_platform_interface---v0601)
 - [`oidc_windows` - `v0.3.1+6`](#oidc_windows---v0316)
 - [`oidc_linux` - `v0.3.0+12`](#oidc_linux---v03012)
 - [`oidc_web_core` - `v0.3.0+1`](#oidc_web_core---v0301)
 - [`oidc_macos` - `v0.6.0+1`](#oidc_macos---v0601)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc` - `v0.9.0+1`
 - `oidc_flutter_appauth` - `v0.5.0+1`
 - `oidc_desktop` - `v0.5.0+1`
 - `oidc_ios` - `v0.6.0+1`
 - `oidc_web` - `v0.6.0+1`
 - `oidc_android` - `v0.6.0+1`
 - `oidc_default_store` - `v0.2.0+12`
 - `oidc_platform_interface` - `v0.6.0+1`
 - `oidc_windows` - `v0.3.1+6`
 - `oidc_linux` - `v0.3.0+12`
 - `oidc_web_core` - `v0.3.0+1`
 - `oidc_macos` - `v0.6.0+1`

---

#### `oidc_core` - `v0.9.1`

 - **FEAT**: Added `OidcTokenExpiredEvent` and `OidcTokenExpiringEvent` ([#91](https://github.com/Bdaya-Dev/oidc/issues/91)). ([85ba41ce](https://github.com/Bdaya-Dev/oidc/commit/85ba41cef689b852e102a65ec6550580489fb4bc))


## 2024-11-24

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.9.0`](#oidc---v090)
 - [`oidc_android` - `v0.6.0`](#oidc_android---v060)
 - [`oidc_core` - `v0.9.0`](#oidc_core---v090)
 - [`oidc_desktop` - `v0.5.0`](#oidc_desktop---v050)
 - [`oidc_flutter_appauth` - `v0.5.0`](#oidc_flutter_appauth---v050)
 - [`oidc_ios` - `v0.6.0`](#oidc_ios---v060)
 - [`oidc_macos` - `v0.6.0`](#oidc_macos---v060)
 - [`oidc_platform_interface` - `v0.6.0`](#oidc_platform_interface---v060)
 - [`oidc_web` - `v0.6.0`](#oidc_web---v060)
 - [`oidc_web_core` - `v0.3.0`](#oidc_web_core---v030)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+11`](#oidc_default_store---v02011)
 - [`oidc_windows` - `v0.3.1+5`](#oidc_windows---v0315)
 - [`oidc_linux` - `v0.3.0+11`](#oidc_linux---v03011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_default_store` - `v0.2.0+11`
 - `oidc_windows` - `v0.3.1+5`
 - `oidc_linux` - `v0.3.0+11`

---

#### `oidc` - `v0.9.0`

 - **FIX**: oidc not passing options properly. ([b2fdf5fe](https://github.com/Bdaya-Dev/oidc/commit/b2fdf5fe38787e0b1d89c192545accefa99f9a7d))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_android` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_core` - `v0.9.0`

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_desktop` - `v0.5.0`

 - **FIX**: typo in oidc_desktop. ([a6f67bd8](https://github.com/Bdaya-Dev/oidc/commit/a6f67bd8dd514bfa397649624272df550737e23e))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_flutter_appauth` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_ios` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_macos` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_platform_interface` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web` - `v0.6.0`

 - **FEAT**: depend on oidc_web_core. ([f3331a8e](https://github.com/Bdaya-Dev/oidc/commit/f3331a8e2d3e39c5cb8d7728d104e1bb8d8ece75))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web_core` - `v0.3.0`

 - **REVERT**: local version. ([e948477a](https://github.com/Bdaya-Dev/oidc/commit/e948477a7134b36f2cd7f80186632c0a57516afd))
 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))


## 2024-11-24

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.8.0`](#oidc---v080)
 - [`oidc_android` - `v0.5.0`](#oidc_android---v050)
 - [`oidc_core` - `v0.8.0`](#oidc_core---v080)
 - [`oidc_desktop` - `v0.4.0`](#oidc_desktop---v040)
 - [`oidc_flutter_appauth` - `v0.4.0`](#oidc_flutter_appauth---v040)
 - [`oidc_ios` - `v0.5.0`](#oidc_ios---v050)
 - [`oidc_macos` - `v0.5.0`](#oidc_macos---v050)
 - [`oidc_platform_interface` - `v0.5.0`](#oidc_platform_interface---v050)
 - [`oidc_web` - `v0.5.0`](#oidc_web---v050)
 - [`oidc_web_core` - `v0.2.0`](#oidc_web_core---v020)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+10`](#oidc_default_store---v02010)
 - [`oidc_windows` - `v0.3.1+4`](#oidc_windows---v0314)
 - [`oidc_linux` - `v0.3.0+10`](#oidc_linux---v03010)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_default_store` - `v0.2.0+10`
 - `oidc_windows` - `v0.3.1+4`
 - `oidc_linux` - `v0.3.0+10`

---

#### `oidc` - `v0.8.0`

 - **FIX**: oidc not passing options properly. ([b2fdf5fe](https://github.com/Bdaya-Dev/oidc/commit/b2fdf5fe38787e0b1d89c192545accefa99f9a7d))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_android` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_core` - `v0.8.0`

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_desktop` - `v0.4.0`

 - **FIX**: typo in oidc_desktop. ([a6f67bd8](https://github.com/Bdaya-Dev/oidc/commit/a6f67bd8dd514bfa397649624272df550737e23e))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_flutter_appauth` - `v0.4.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_ios` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_macos` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_platform_interface` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web` - `v0.5.0`

 - **FEAT**: depend on oidc_web_core. ([f3331a8e](https://github.com/Bdaya-Dev/oidc/commit/f3331a8e2d3e39c5cb8d7728d104e1bb8d8ece75))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web_core` - `v0.2.0`

 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

