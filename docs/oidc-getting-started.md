# Getting started <!-- omit from toc -->

[![package:oidc][package_image]][package_link]

This document shows how to setup `package:oidc` for the first time.

you can check the [example project](https://github.com/Bdaya-Dev/oidc/tree/main/packages/oidc/example) for the final result.

after following this document, you can check the [Usage Document](oidc-usage.md)


## Adding dependencies

```sh
dart pub add oidc oidc_default_store oidc_core
```

every platform you support has its own configuration and set up.

Native browser handling is **first-party on every platform** (no third-party
auth SDK):

- **Android** — **Chrome Custom Tabs**.
- **iOS** — **ASWebAuthenticationSession** (requires **iOS 13+**).
- **macOS** — **ASWebAuthenticationSession** (requires **macOS 10.15+**).

we also rely on [![flutter_secure_storage][flutter_secure_storage_image]][flutter_secure_storage_link] in our `oidc_default_store` implementation, to encrypt the stored access tokens.

## Android

### Redirect handling (Chrome Custom Tabs)

`oidc_android` opens the system browser via Chrome Custom Tabs and ships its own
transparent redirect receiver (`OidcRedirectActivity`), so you only declare the
**scheme** of your `redirect_uri` with a single manifest placeholder.

go to `android/app/build.gradle`, and add the following under `defaultConfig`:

```diff
defaultConfig {
    applicationId "com.my.app"
    minSdkVersion flutter.minSdkVersion
    targetSdkVersion flutter.targetSdkVersion
    versionCode flutterVersionCode.toInteger()
    versionName flutterVersionName
+   manifestPlaceholders += [
+       'oidcRedirectScheme': 'com.my.app'
+   ]
}
```
replace `com.my.app` with the scheme of your `redirect_uri` (a reverse-DNS
scheme you own, per [RFC 8252 §7.1](https://datatracker.ietf.org/doc/html/rfc8252#section-7.1));
your `redirect_uri` then looks like `com.my.app://oauth2redirect`.

- You do **not** add any `<intent-filter>`, `launchMode`, or `taskAffinity` to
  `MainActivity` — the plugin handles redirect delivery.

> IMPORTANT NOTE
>
> if your `applicationId`/scheme contains an underscore (`_`), replace it with a
> dot (`.`) in the `oidcRedirectScheme` (schemes can't contain underscores).

> **Upgrading from a flutter_appauth-based setup?** Delete the old
> `appAuthRedirectScheme` placeholder and any redirect `<intent-filter>` you
> hand-added to `MainActivity` — `package:oidc` no longer depends on
> `flutter_appauth` on any platform, so they are no longer used.

> **HTTPS redirect (App Links)?** A `https://` `redirect_uri` additionally needs
> a verified [Android App Link](https://developer.android.com/training/app-links/verify-android-applinks)
> (host an `assetlinks.json`). Custom schemes need no verification and are the
> simpler choice for most apps.


### flutter_secure_storage setup

[Source](https://pub.dev/packages/flutter_secure_storage#configure-android-version)

1. In `android/app/build.gradle` set `minSdkVersion` to >= 18.
    ```diff
    defaultConfig {   
        
        applicationId "com.my_app"
    -   minSdkVersion flutter.minSdkVersion
    +   minSdkVersion 21
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        manifestPlaceholders += [
            'oidcRedirectScheme': 'com.my.app'
        ]
    }
    ```
2. **Disable backup**: 
    1. Create the following file in `android\app\src\main\res\xml\backup_rules.xml`
        ```xml
        <?xml version="1.0" encoding="utf-8"?>
        <full-backup-content>
                <exclude domain="sharedpref" path="FlutterSecureStorage"/>
        </full-backup-content>
        ```

    2. Create the following file in `android\app\src\main\res\xml\data_extraction_rules.xml`
        ```xml
        <?xml version="1.0" encoding="utf-8"?>
        <data-extraction-rules>
            <cloud-backup>
                <exclude domain="sharedpref" path="FlutterSecureStorage"/>
            </cloud-backup>
        </data-extraction-rules>
        ```
    3. in `android\app\src\main\AndroidManifest.xml` add the following attributes to `application` tag:
        ```diff
        <application
                android:label="example"
                android:name="${applicationName}"
                android:icon="@mipmap/ic_launcher"
        +   android:fullBackupContent="@xml/backup_rules"
        +   android:dataExtractionRules="@xml/data_extraction_rules"
                >
        ```

### Enable MultiDex
[Source](https://docs.flutter.dev/deployment/android#enabling-multidex-support)

just do `flutter run` from your terminal (not IDE) once, and it will ask you to enable it (press y).

## iOS

### Redirect handling (ASWebAuthenticationSession)

`oidc_darwin` (iOS) uses the system `ASWebAuthenticationSession`, which
registers your `redirect_uri` scheme **at runtime**. You do **not** need a
`CFBundleURLTypes` / `CFBundleURLSchemes` entry in `ios/Info.plist` for the OIDC
redirect, and you do not add any third-party SDK.

Requirements:

- **iOS 13.0+** — set the deployment target accordingly in Xcode and in
  `ios/Podfile` (`platform :ios, '13.0'` or higher).
- For an `https`/Universal-Link `redirect_uri` (optional, iOS 17.4+), your app
  must declare an [Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
  entitlement. Custom schemes need no entitlement and are the simpler choice.

## macOS

### Redirect handling (ASWebAuthenticationSession)

`oidc_darwin` (macOS) uses the system `ASWebAuthenticationSession` (the same
first-party approach as iOS — no third-party SDK), which registers your
`redirect_uri` scheme **at runtime**. You do **not** need a `CFBundleURLTypes` /
`CFBundleURLSchemes` entry in `macos/Info.plist` for the OIDC redirect.

Requirements:

- **macOS 10.15+** — set the deployment target accordingly in Xcode and in
  `macos/Podfile` (`platform :osx, '10.15'` or higher).

### App Sandbox network entitlement (macOS)

macOS runs under the App Sandbox, which **blocks outbound network by default**.
The OIDC flow needs network access, so add the network-client entitlement to
**both** `macos/Runner/DebugProfile.entitlements` **and**
`macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

(For signed/notarized distribution, the
[Hardened Runtime](https://docs.flutter.dev/platform-integration/macos/building#hardened-runtime)
is required and is compatible with these entitlements.)

### flutter_secure_storage setup for macos

[Source](https://pub.dev/packages/flutter_secure_storage#configure-macos-version)

You need to add Keychain Sharing as capability to your macOS runner. To achieve this, please add the following in both your `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` (you need to change both files).
```xml
<key>keychain-access-groups</key>
<array/>
```

## Web

for web, you need a separate html page to be delivered with your app, which will handle oidc-related requests.

you can get the page from the example project:

[redirect.html](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc/example/web/redirect.html)

it doesn't matter where you put the page and what you call it, but it MUST be delivered from your redirect_uri

for example, here is a common configuration using this page:

```dart
final htmlPageLinkDevelopment = Uri.parse('http://localhost:22433/redirect.html');
final htmlPageLinkProduction = Uri.parse('https://mywebsite.com/redirect.html');

final htmlPageLink = kDebugMode ? htmlPageLinkDevelopment : htmlPageLinkProduction;

final redirectUri = htmlPageLink;
final postLogoutRedirectUri = htmlPageLink;
final frontChannelLogoutUri = htmlPageLink.replace(
    queryParameters: {
        ...htmlPageLink.queryParameters,
        'requestType': 'front-channel-logout'
    }
);
```
Note how `frontChannelLogoutUri` needs `requestType=front-channel-logout` for the page to know the request type.

you will have to register these urls with the openid provider first, depending on your configuration.

also the html page is completely customizable, but it's preferred to leave the javascript part as is, since it's well-integrated with the plugin.

[Read more](oidc-usage.md)

### flutter_secure_storage setup for web

[Source](https://pub.dev/packages/flutter_secure_storage#configure-web-version)

Flutter Secure Storage uses an experimental implementation using WebCrypto. Use at your own risk at this time. Feedback welcome to improve it. The intent is that the browser is creating the private key, and as a result, the encrypted strings in local_storage are not portable to other browsers or other machines and will only work on the same domain.

**! It is VERY important that you have HTTP Strict Forward Secrecy enabled and the proper headers applied to your responses or you could be subject to a javascript hijack.**

Please see:

- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security
- https://www.netsparker.com/blog/web-security/http-security-headers/


## Windows

Works out of the box.

## Linux

### flutter_secure_storage setup for linux

[Source](https://pub.dev/packages/flutter_secure_storage#configure-linux-version)

also see these issues: [flutter_secure_storage#545](https://github.com/mogol/flutter_secure_storage/issues/545)


You need `libsecret-1-dev` and `libjsoncpp-dev` on your machine to build the project, and `libsecret-1-0` and `libjsoncpp1` to run the application (add it as a dependency after packaging your app). If you using snapcraft to build the project use the following:
```yml
parts:
  uet-lms:
    source: .
    plugin: flutter
    flutter-target: lib/main.dart
    build-packages:
      - libsecret-1-dev
      - libjsoncpp-dev
    stage-packages:
      - libsecret-1-0
      - libjsoncpp-dev
```
Apart from `libsecret` you also need a keyring service, for that you need either `gnome-keyring` (for Gnome users) or `ksecretsservice` (for KDE users) or other light provider like [secret-service](https://github.com/yousefvand/secret-service).


## Notes

- by default, due to its many configuration points, if the plugin fails to read/write using `flutter_secure_storage`, it will fall back to [shared_preferences](https://pub.dev/packages/shared_preferences), which is NOT secure.

[package_link]: https://pub.dev/packages/oidc
[package_image]: https://img.shields.io/badge/package-oidc-0175C2?logo=dart&logoColor=white

[flutter_secure_storage_link]: https://pub.dev/packages/flutter_secure_storage
[flutter_secure_storage_image]: https://img.shields.io/badge/package-flutter__secure__storage-0175C2?logo=dart&logoColor=white

[flutter_appauth_link]: https://pub.dev/packages/flutter_appauth
[flutter_appauth_image]: https://img.shields.io/badge/package-flutter__appauth-0175C2?logo=dart&logoColor=white