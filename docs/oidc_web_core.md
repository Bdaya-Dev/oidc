# [![package:oidc_web_core][package_image]][package_link]

An alternative to `package:oidc` for dart web apps, that does NOT depend on flutter.

This can be used in things like [ngdart](https://pub.dev/packages/ngdart).

The package uses [package:web](https://dart.dev/interop/js-interop/package-web) to access browser APIs, making it also WASM compatible.

Learn more about developing dart web apps in: [dart.dev/web](https://dart.dev/web)

## Getting started

The setup here is similar to what is done in [package:oidc](oidc-getting-started.md#web)

### Add the dependencies

```bash
dart pub add oidc_web_core oidc_core
```

### Add redirect.html page

You need a separate html page to be delivered with your app, which will handle oidc-related requests.

you can get the page from the example project:

[redirect.html](https://github.com/Bdaya-Dev/oidc/blob/main/packages/oidc/example/web/redirect.html)

it doesn't matter where you put the page and what you call it, but it MUST be delivered from your redirect_uri

for example, here is a common configuration using this page:

```dart
final htmlPageLinkDevelopment = Uri.parse('http://127.0.0.1:22433/redirect.html');
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

also the html page is completely customizable, but it's preferred to leave the javascript part as is, since it's well-integrated with the plugin. All user-visible copy lives in a single `messages` object near the top of the script and is safe to translate.

#### How the page talks to the app

The page and the app exchange messages over a `BroadcastChannel`:

- on load, the page posts the incoming redirect to the app as a small JSON envelope: `{"v":2,"type":"redirect","uri":"<full redirect url>"}`;
- once the app has processed it (the token exchange finished — or failed), the app posts an acknowledgement back: `{"v":2,"type":"ack","status":"ok"|"error","message":"<short message>"}`.

The page only shows a **success** state after an `ok` ack — so it no longer claims "Operation Successful" when the app-side exchange actually failed. It shows an **error** state on an `error` ack, or when the provider returned an error directly in the redirect (`error`/`error_description`/`error_uri`, per [RFC 6749 §4.1.2.1](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.2.1)). If no ack arrives within ~10s (e.g. an older app version that never acks), or the browser refuses to close a tab the script didn't open (email-link tabs), it falls back to a neutral "you can now close this tab" state.

The app still accepts the older bare-URL message, so an outdated copy of the page keeps working after you upgrade the package. The reverse does not hold: this v2 page needs the matching (v2-aware) package version.

#### Upgrading

`redirect.html` is copied into your own project, not shipped by the package, so `dart pub upgrade` never updates it. When you upgrade `oidc_web_core`, **re-copy the page** from the example so the app and the page stay on the same wire version.

#### Troubleshooting

- **The page never loads (blank tab, or your host/proxy's `502`/`504`).** None of the javascript above can run if the `redirect_uri` doesn't actually serve this page. Make sure your host or reverse proxy serves `redirect.html` at the exact `redirect_uri` path in every environment. While that tab is broken the app receives nothing, so the pending login stays unresolved — return to the app to cancel it (or let it time out) and retry once the page is served correctly.

## Usage

using this package is identical to [package:oidc](oidc-usage.md)

you can also see an [example here](https://github.com/Bdaya-Dev/oidc/tree/main/packages/oidc_web_core/example) of a dart web app using this package

1. Define the manager
    ```dart
    final manager = OidcUserManagerWeb.lazy(
        discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
            Uri.parse('https://demo.duendesoftware.com'),
        ),
        // this is a public client,
        // so we use [OidcClientAuthentication.none] constructor.
        clientCredentials: const OidcClientAuthentication.none(
            clientId: 'interactive.public.short',
        ),
        // Use a web-only store
        store: const OidcWebStore(),
        settings: OidcUserManagerSettings(
            frontChannelLogoutUri: Uri(path: 'redirect.html'),
            uiLocales: ['en', 'ar'],
            refreshBefore: (token) {
                return const Duration(seconds: 1);
            },
            // scopes supported by the provider and needed by the client.
            scope: ['openid', 'profile', 'email', 'offline_access'],
            
            // this url must be an actual html page.
            // see the file in /web/redirect.html for an example.
            //
            // for debugging in flutter, you must run this app with --web-port 22433
            postLogoutRedirectUri: Uri.parse('http://127.0.0.1:22433/redirect.html'),
            redirectUri: Uri.parse('http://127.0.0.1:22433/redirect.html'),
        ),
    );
    ```
2. Init the manager
    ```dart
    await manager.init();
    ```
3. Access the user
    ```dart
    manager.userChanges().listen((user) {});
    ```
    or
    ```dart
    manager.currentUser;
    ```
4. Login
    ```dart
    final user = await manager.loginAuthorizationCodeFlow();
    ```
5. Logout
    ```dart
    await manager.logout();
    ```

--- 

[package_link]: https://pub.dev/packages/oidc_web_core
[package_image]: https://img.shields.io/badge/package-oidc__web__core-0175C2?logo=dart&logoColor=white
