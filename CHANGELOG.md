# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

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

