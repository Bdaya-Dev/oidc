# oidc_macos

[![openid certification](https://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The macOS implementation of `package:oidc`.

> macOS currently performs the browser flow via the [AppAuth SDK](https://appauth.io/)
> (through `oidc_flutter_appauth`), unlike iOS/Android which are first-party. A
> first-party migration is tracked for the future.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `oidc`
normally. This package will be automatically included in your app when you do.

## Native setup

### Redirect URL scheme

Register your `redirect_uri` scheme in `macos/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.app</string>
        </array>
    </dict>
</array>
```

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

> iOS needs none of these — `oidc_ios` uses the system `ASWebAuthenticationSession`
> and registers the callback scheme at runtime.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
