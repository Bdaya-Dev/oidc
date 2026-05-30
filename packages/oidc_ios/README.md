# oidc_ios

[![openid certification](https://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The iOS implementation of `package:oidc`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `package:oidc`
normally. This package will be automatically included in your app when you do.

## Redirect handling (native setup)

This implementation opens the system browser via
[`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
and captures the `redirect_uri` when the browser redirects back to your app.

- **No `Info.plist` URL scheme is required.** `ASWebAuthenticationSession`
  registers your `redirect_uri` scheme at runtime, so you do **not** add a
  `CFBundleURLTypes` / `CFBundleURLSchemes` entry for the OIDC redirect.
- **Minimum iOS 13.0.** Set the deployment target to `13.0` or higher in Xcode
  and in your app's `ios/Podfile` (`platform :ios, '13.0'`).
- **No third-party SDK.** This replaces the previous `flutter_appauth`-based
  iOS path with the system framework.

### HTTPS / Universal-Link redirects (optional, iOS 17.4+)

Custom-scheme `redirect_uri`s (e.g. `com.example.app://oauth2redirect`) work on
iOS 13+ with no extra setup. If you instead use an `https` Universal-Link
`redirect_uri`, your app must declare an
[Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
entitlement; the plugin uses `ASWebAuthenticationSession.Callback.https` on iOS
17.4+ for that case.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
