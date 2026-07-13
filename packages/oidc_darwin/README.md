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

## macOS: external-browser (loopback) navigation mode

By default both platforms run the flow inside an in-app
`ASWebAuthenticationSession`. On **macOS only**, you can opt into running the
flow in the user's default system browser instead, capturing the redirect on an
[RFC 8252 §7.3](https://datatracker.ietf.org/doc/html/rfc8252#section-7.3)
loopback interface — the same transport `oidc_desktop` uses on Windows/Linux.
This is useful when you want the login to happen in the user's real browser
(shared session cookies, password managers, extensions) rather than the
isolated `ASWebAuthenticationSession` web view.

Enable it via `OidcPlatformSpecificOptions.macos`:

```dart
const OidcPlatformSpecificOptions(
  macos: OidcNativeOptionsApple(
    navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
    // Optional: bound the wait so an abandoned flow does not hang forever.
    flowTimeoutSeconds: 300,
    // Optional: HTML shown in the browser tab after a successful redirect.
    successfulPageResponse: '<html><body>You may return to the app.</body></html>',
  ),
)
```

When this mode is selected on macOS:

- The authorization URL is opened in the default browser via `url_launcher`.
- A loopback HTTP listener binds `http://127.0.0.1:{port}`. Use a
  `redirect_uri` of `http://127.0.0.1:0` to bind an ephemeral free port — the
  actual port is written back into the `redirect_uri` before the browser is
  launched (identical to `oidc_desktop`).
- The wait for the redirect is bounded by `flowTimeoutSeconds` (a
  `TimeoutException` surfaces as an `OidcException`).

**iOS ignores this setting** — `ASWebAuthenticationSession` remains the only iOS
mechanism (there is no iOS equivalent of opening the default system browser and
binding a loopback interface). The `.ios` field's `navigationMode` is not
consulted.

### Redirect URI registration

Register a loopback redirect URI of the form `http://127.0.0.1:{port}` (path
optional, e.g. `http://127.0.0.1:0/callback`) with your OpenID Provider. Most
providers that follow RFC 8252 allow any port for a `127.0.0.1` loopback
redirect, so registering the literal `http://127.0.0.1` (or with a fixed path)
is typically sufficient even when an ephemeral port is used at runtime.

### App Sandbox entitlements

A sandboxed macOS app must be allowed to bind the loopback listener and to make
the outgoing browser/HTTP connections. Add both of these to your macOS app's
`*.entitlements` files (`Runner/DebugProfile.entitlements` and
`Runner/Release.entitlements`):

```xml
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

`network.server` is required to accept the inbound loopback redirect;
`network.client` is required to reach the OpenID Provider. Without them the App
Sandbox blocks the loopback socket and the flow cannot complete.

> **Note:** the exact entitlement requirement for binding a `127.0.0.1`
> listener under the macOS App Sandbox has not been re-verified on-device for
> this release; confirm against your target macOS version if you ship a
> sandboxed build.

## Migrating from `oidc_ios` / `oidc_macos`

Apps depending on the `oidc` umbrella need no changes. If you depended on
`oidc_ios` or `oidc_macos` directly, depend on `oidc_darwin` instead (or just on
`oidc`). The `OidcPlatformSpecificOptions.ios` and `.macos` option fields are
unchanged — each platform still reads its own field.
