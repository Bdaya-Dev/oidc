## 1.0.0

 - **FEAT**: initial release of `oidc_darwin`, the unified iOS + macOS
   implementation of the `oidc` plugin. It merges and supersedes `oidc_ios` and
   `oidc_macos` into a single Flutter `sharedDarwinSource` plugin (one Swift
   target, one `Package.swift`, one podspec), driving the
   `ASWebAuthenticationSession` browser primitive via the Pigeon-generated
   `OidcAppleHostApi`.
 - **BREAKING**: replaces `oidc_ios` and `oidc_macos`. Apps that depend on the
   `oidc` umbrella package need no changes; anyone depending on `oidc_ios` or
   `oidc_macos` directly should switch to `oidc_darwin`.
