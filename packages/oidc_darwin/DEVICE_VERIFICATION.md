# oidc_darwin — on-device verification checklist

The `oidc_darwin` merge (formerly `oidc_ios` + `oidc_macos`) was verified on the
Dart side only (workspace `pub get`, Pigeon regen, `dart analyze`, and the
package's widget tests). The native `ASWebAuthenticationSession` behavior and the
federated-plugin registration **cannot be verified on Windows / in CI simulators**
and MUST be checked on real hardware before publishing `oidc_darwin@1.0.0`.

Run the `packages/oidc/example` app on each platform.

## iPhone (real device)

- [ ] **Registration:** at runtime, `OidcPlatform.instance is OidcDarwin` is true
      (the historical same-`dartPluginClass`-for-both-platforms registrant bug —
      flutter/flutter#113720 / #137607 — is fixed on current Flutter, but confirm).
- [ ] Full authorize round-trip (login) succeeds and returns to the app.
- [ ] End-session (logout) round-trip succeeds.
- [ ] Cancel mid-flow: dismiss the sheet — no crash (the retained
      `contextProvider`, #213), and the Dart future resolves to "cancelled".
- [ ] Ephemeral session (`prefersEphemeralWebBrowserSession: true`) shows no
      shared cookies.
- [ ] iOS **17.4+** device: the `.https` (Universal-Link) callback branch and
      `additionalHeaderFields` path (requires an Associated Domains entitlement).
- [ ] The Azure end-session `presentationContextInvalid` ("-3") case resolves to
      null (treated as a closed session), not an error.
- [ ] `nativeBrowserEvents()` streams opening/opened/redirectReceived/cancelled/failed.

## Mac (real device)

- [ ] `OidcPlatform.instance is OidcDarwin` is true.
- [ ] Authorize + end-session + cancel + ephemeral, as above.
- [ ] macOS **14.4+**: the `.https` callback + `additionalHeaderFields` path.
- [ ] AppKit presentation anchor resolves (key window → main window → first
      window) — including from an `LSUIElement` / pre-window state if applicable.
- [ ] `nativeBrowserEvents()` streams on macOS.

## Both build systems

- [ ] One pass with **Swift Package Manager** enabled.
- [ ] One pass with **CocoaPods** (SwiftPM disabled) — confirms the single
      `darwin/oidc_darwin.podspec` (`s.ios.`/`s.osx.` split) produces parity.
- [ ] The example's `GeneratedPluginRegistrant.{m,swift}` regenerate to import
      `oidc_darwin` and call `OidcPlugin.register(...)` (do NOT hand-edit — run a
      clean build / `pod install`).

## Notes

- Deployment floors are preserved: iOS 13.0 / macOS 10.15.
- The Pigeon channel name is keyed on `oidc_platform_interface`, not on the impl
  package, so the wire protocol is unchanged by the merge.
