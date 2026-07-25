# oidc_android

[![openid certification](https://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The Android implementation of `package:oidc`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `package:oidc`
normally. This package will be automatically included in your app when you do.

## Requirements

`minSdkVersion` **23 or higher**, set in `android/app/build.gradle`. This plugin
depends on `androidx.browser:browser:1.10.0`, which declares `minSdk 23`; a
lower value in your app fails the manifest merge at build time.

> Upgrading from 1.0.1 or earlier? Its floor was 21, so raising this is the one
> change that can break your build.

## Redirect handling (native setup)

This implementation opens the system browser via **Auth Tab** (falling back to
**Chrome Custom Tabs**) and captures the `redirect_uri` when the browser
redirects back to your app.

Capture is dual-path, because `AuthTabIntent` does no capability detection —
it deliberately degrades to a plain Custom Tab on browsers without Auth Tab
support:

| Browser | Capture path |
| --- | --- |
| Chrome 137+ | Auth Tab's Activity Result API — survives process death |
| Firefox, Samsung Internet, older Chrome, everything else | the plugin's `OidcRedirectActivity` intent-filter |

Whichever path fires first wins, so you get process-death resilience where the
browser supports it and a working login everywhere else.

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

This placeholder is **required** — the plugin intentionally ships no default,
because a default declared in the library is substituted before the app merge
and would silently shadow your scheme. If you omit it the build fails at the
manifest merge naming `oidcRedirectScheme`, which is deliberate: the failure
mode it replaces is a blank browser tab at runtime with no error at all.

> A URI scheme cannot contain `_` ([RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986#section-3.1)),
> so if your `applicationId` has an underscore, replace it with a dot here.
>
> If you previously used `flutter_appauth`, **remove** the old
> `appAuthRedirectScheme` placeholder and any redirect `<intent-filter>` you
> hand-added to `MainActivity` — they are no longer used.

### HTTPS App Links

For an `https` redirect you additionally need a verified
[Android App Link](https://developer.android.com/training/app-links/verify-android-applinks):
host an `assetlinks.json` for your domain. Custom schemes need no such
verification and are the simpler choice for most apps.

### Activity host

Auth Tab needs a `ComponentActivity` host (e.g. `FlutterFragmentActivity`) to
register its result launcher. A plain `FlutterActivity` still works — the
plugin opens a Custom Tab and the redirect comes back through
`OidcRedirectActivity` — but it does not get Auth Tab's process-death
resilience. Extending `FlutterFragmentActivity` is recommended.

### Note on process death

When Auth Tab handles the flow (Chrome 137+ on a `ComponentActivity` host) the
redirect is delivered through the Activity Result API, which survives process
death. On the intent-filter path the redirect is delivered in-memory to the
running app: if the OS kills your app's process while the browser is open
(rare, low-memory devices), the in-flight login cannot be resumed and the user
must retry — the same limitation as comparable browser-based auth plugins.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
