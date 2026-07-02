# oidc_darwin

The iOS and macOS ("darwin") implementation of the [`oidc`](https://pub.dev/packages/oidc) plugin.

This is an endorsed federated implementation of `oidc` — you don't use it
directly. Add [`oidc`](https://pub.dev/packages/oidc) to your app and this
package is pulled in automatically on iOS and macOS.

It merges and supersedes the former `oidc_ios` and `oidc_macos` packages into a
single Flutter [`sharedDarwinSource`](https://docs.flutter.dev/packages-and-plugins/developing-packages#sharing-ios-and-macos-code)
plugin: one platform-guarded Swift source, one `Package.swift`, and one podspec
serve both Apple platforms.

## What it does

All OIDC logic (URL building, PKCE, `state`, `nonce`, response parsing) lives in
pure-Dart `oidc_core`. This package only opens the authorization / end-session
URL in an [`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
and returns the captured redirect URI back to Dart. The Dart↔native transport is
the Pigeon-generated `OidcAppleHostApi` plus an event channel for browser
observability events.

- iOS 13+ / macOS 10.15+
- Swift Package Manager and CocoaPods are both supported.
- iOS 17.4+ / macOS 14.4+ additionally support `https` (Universal-Link)
  callbacks and `additionalHeaderFields`.

## Migrating from `oidc_ios` / `oidc_macos`

Apps depending on the `oidc` umbrella need no changes. If you depended on
`oidc_ios` or `oidc_macos` directly, depend on `oidc_darwin` instead (or just on
`oidc`). The `OidcPlatformSpecificOptions.ios` and `.macos` option fields are
unchanged — each platform still reads its own field.
