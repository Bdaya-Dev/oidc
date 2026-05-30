# oidc_android

[![openid certification](https://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The Android implementation of `package:oidc`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `package:oidc`
normally. This package will be automatically included in your app when you do.

## Redirect handling (native setup)

This implementation opens the system browser via **Chrome Custom Tabs** and
captures the `redirect_uri` when the browser redirects back to your app.

The plugin ships its own transparent redirect receiver
(`OidcRedirectActivity`), so you do **not** add any `<intent-filter>` to your
`MainActivity`, and you do **not** change its `launchMode` or `taskAffinity`.
You only declare the scheme of your `redirect_uri` with a single manifest
placeholder.

### Custom-scheme redirect (recommended, e.g. `com.example.app://oauth2redirect`)

In `android/app/build.gradle`, inside `android { defaultConfig { … } }`:

```gradle
android {
    defaultConfig {
        // ... existing config ...
        manifestPlaceholders += ['oidcRedirectScheme': 'com.example.app']
    }
}
```

That's the entire native setup. Use a reverse-DNS scheme you own (per
[RFC 8252 §7.1](https://datatracker.ietf.org/doc/html/rfc8252#section-7.1)) and
make your `redirect_uri` `com.example.app://oauth2redirect`.

> If you previously used `flutter_appauth`, **remove** the old
> `appAuthRedirectScheme` placeholder and any redirect `<intent-filter>` you
> hand-added to `MainActivity` — they are no longer used.

### HTTPS App Links

For an `https` redirect you additionally need a verified
[Android App Link](https://developer.android.com/training/app-links/verify-android-applinks):
host an `assetlinks.json` for your domain. Custom schemes need no such
verification and are the simpler choice for most apps.

### Note on process death

The redirect is delivered in-memory to the running app. If the OS kills your
app's process while the browser is open (rare, low-memory devices), the
in-flight login cannot be resumed and the user must retry — the same limitation
as comparable browser-based auth plugins.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
