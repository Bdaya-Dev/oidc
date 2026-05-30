# oidc_macos

[![openid certification](https://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The macOS implementation of `package:oidc`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `oidc`
normally. This package will be automatically included in your app when you do.

## Native setup

### Redirect handling (ASWebAuthenticationSession)

`oidc_macos` opens the system browser via
[`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
— the same first-party approach as iOS, with no third-party SDK. It registers
your `redirect_uri` scheme **at runtime**, so you do **not** add a
`CFBundleURLTypes` / `CFBundleURLSchemes` entry to `macos/Runner/Info.plist`.

- **Minimum macOS 10.15.** Set the deployment target to `10.15` or higher in
  Xcode and in your app's `macos/Podfile` (`platform :osx, '10.15'`).

### App Sandbox & entitlements

macOS apps run under the App Sandbox, which **blocks outbound network access by
default**. The OIDC flow talks to your provider over the network, so add the
network-client entitlement to **both** entitlements files
(`macos/Runner/DebugProfile.entitlements` **and** `macos/Runner/Release.entitlements`
— you must edit both):

```xml
<key>com.apple.security.network.client</key>
<true/>
```

`flutter_secure_storage` additionally needs Keychain Sharing:

```xml
<key>keychain-access-groups</key>
<array/>
```

If you distribute a signed/notarized build, the
[Hardened Runtime](https://docs.flutter.dev/platform-integration/macos/building#hardened-runtime)
is required; the entitlements above are compatible with it.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
