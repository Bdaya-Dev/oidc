## 1.1.0

 - **FEAT**(oidc_darwin): add macOS loopback system-browser navigation mode ([#124](https://github.com/Bdaya-Dev/oidc/issues/124)) ([#398](https://github.com/Bdaya-Dev/oidc/issues/398)). ([a8d758f7](https://github.com/Bdaya-Dev/oidc/commit/a8d758f74fd86b93e74fabe6c561235ca4ee3343))

## 1.0.0

> Note: This release has breaking changes.

 - **FIX**: resolve all four library bugs; drive honest unit coverage to ~95% ([#368](https://github.com/Bdaya-Dev/oidc/issues/368)). ([c86bee17](https://github.com/Bdaya-Dev/oidc/commit/c86bee17189a0a70fee947c685e91a55062b1d35))
 - **FIX**(oidc_darwin): implement flowTimeoutSeconds for the Apple ASWebAuthenticationSession flow. ([482f0186](https://github.com/Bdaya-Dev/oidc/commit/482f0186b8cdb37d309118de187e1c8496555d9a))
 - **DOCS**(oidc_darwin): add the on-device verification checklist. ([b22a1c06](https://github.com/Bdaya-Dev/oidc/commit/b22a1c06316a33198dbcd2826bee4fe4f9c608c8))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **FEAT**: initial release of `oidc_darwin`, the unified iOS + macOS
   implementation of the `oidc` plugin. It merges and supersedes `oidc_ios` and
   `oidc_macos` into a single Flutter `sharedDarwinSource` plugin (one Swift
   target, one `Package.swift`, one podspec), driving the
   `ASWebAuthenticationSession` browser primitive via the Pigeon-generated
   `OidcAppleHostApi`.
 - **BREAKING**: replaces `oidc_ios` and `oidc_macos`. Apps that depend on the
   `oidc` umbrella package need no changes; anyone depending on `oidc_ios` or
   `oidc_macos` directly should switch to `oidc_darwin`.
