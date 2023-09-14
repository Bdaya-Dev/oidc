import 'dart:io';

import 'package:async/async.dart';
import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

//This file represents a global state, which is bad
//in a production app (since you can't test it).

//usually you would use a dependency injection library
//and put these in a service.
final exampleLogger = Logger('oidc.example');


/// Gets the current manager used in the example. 
OidcUserManager get currentManager => duendoManager;

final duendoManager = OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getWellKnownUriFromBase(
    Uri.parse('https://demo.duendesoftware.com'),
  ),
  // this is a public client,
  // so we use [OidcClientAuthentication.none] constructor.
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'interactive.public',
  ),
  store: OidcDefaultStore(
      // useSessionStorageForSessionNamespaceOnWeb: true,
      ),

  // keyStore: JsonWebKeyStore(),
  settings: OidcUserManagerSettings(
    uiLocales: ['ar'],
    refreshBefore: (token) {
      return const Duration(minutes: 10);
    },
    // scopes supported by the provider and needed by the client.
    scope: ['openid', 'profile', 'email', 'offline_access', 'api'],
    postLogoutRedirectUri: kIsWeb
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid
            ? Uri.parse('com.bdayadev.oidc.example:/endsessionredirect')
            : Platform.isWindows || Platform.isLinux
                ? Uri.parse('http://localhost:0')
                : null,
    redirectUri: kIsWeb
        // this url must be an actual html page.
        // see the file in /web/redirect.html for an example.
        //
        // for debugging in flutter, you must run this app with --web-port 22433
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid
            // scheme: reverse domain name notation of your pacakge name.
            // path: anything.
            ? Uri.parse('com.bdayadev.oidc.example:/oauth2redirect')
            : Platform.isWindows || Platform.isLinux
                // using port 0 means that we don't care which port is used,
                // and a random unused port will be assigned.
                //
                // this is safer than passing a port yourself.
                //
                // note that you can also pass a path like /redirect,
                // but it's completely optional.
                ? Uri.parse('http://localhost:0')
                : Uri(),
  ),
);
final certificationManager = OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getWellKnownUriFromBase(
    Uri.parse('https://www.certification.openid.net/test/a/oidc_dart/'),
  ),
  // this is a public client,
  // so we use [OidcClientAuthentication.none] constructor.
  clientCredentials: const OidcClientAuthentication.clientSecretBasic(
    clientId: 'my_web_client',
    clientSecret: 'my_web_client_secret',
  ),
  store: OidcDefaultStore(
      // useSessionStorageForSessionNamespaceOnWeb: true,
      ),

  // keyStore: JsonWebKeyStore(),
  settings: OidcUserManagerSettings(
    uiLocales: ['ar', 'en'],
    refreshBefore: (token) {
      return const Duration(minutes: 10);
    },
    // scopes supported by the provider and needed by the client.
    scope: ['openid'],
    postLogoutRedirectUri: kIsWeb
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid
            ? Uri.parse('com.bdayadev.oidc.example:/endsessionredirect')
            : Platform.isWindows || Platform.isLinux
                ? Uri.parse('http://localhost:0')
                : null,
    redirectUri: kIsWeb
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid
            ? Uri.parse('com.bdayadev.oidc.example:/oauth2redirect')
            : Platform.isWindows || Platform.isLinux
                ? Uri.parse('http://localhost:0')
                : Uri(),
  ),
);
final initMemoizer = AsyncMemoizer<void>();
Future<void> initApp() {
  return initMemoizer.runOnce(() async {
    currentManager.userChanges().listen((event) {
      cachedAuthedUser.$ = event;
      exampleLogger.info('User changed: ${event?.claims.toJson()}');
    });

    await currentManager.init();
  });
}

final cachedAuthedUser = SharedValue<OidcUser?>(value: null);
