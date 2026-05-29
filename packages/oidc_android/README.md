# oidc_android

[![openid certification](http://openid.net/wordpress-content/uploads/2016/05/oid-l-certification-mark-l-cmyk-150dpi-90mm.jpg)](https://openid.net/developers/certified-openid-connect-implementations/)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The Android implementation of `package:oidc`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `package:oidc`
normally. This package will be automatically included in your app when you do.

## Redirect handling (required native setup)

This implementation opens the system browser via **Chrome Custom Tabs** and
captures the `redirect_uri` when the browser redirects back to your app. For
that to work, your app's launcher `Activity` must declare an `intent-filter`
that matches your registered `redirect_uri`.

### Custom-scheme redirect (e.g. `com.example.app://callback`)

In `android/app/src/main/AndroidManifest.xml`, on your `MainActivity`:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTask"
    android:exported="true">
    <!-- keep your existing MAIN / LAUNCHER intent-filter -->

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.example.app" android:host="callback" />
    </intent-filter>
</activity>
```

> Do **not** set an empty `android:taskAffinity=""` on this `Activity` — some
> newer Flutter templates add it, which breaks redirect delivery.

### HTTPS App Links

For an `https` redirect, add `android:autoVerify="true"` and host an
`assetlinks.json`. See
<https://developer.android.com/training/app-links/verify-android-applinks>.

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis