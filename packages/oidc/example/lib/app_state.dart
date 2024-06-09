// ignore_for_file: avoid_redundant_argument_values

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
OidcUserManager currentManager = duendeManager;

final duendeManager = OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse('https://demo.duendesoftware.com'),
  ),
  // this is a public client,
  // so we use [OidcClientAuthentication.none] constructor.
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'interactive.public.short',
  ),
  store: OidcDefaultStore(),

  // keyStore: JsonWebKeyStore(),
  settings: OidcUserManagerSettings(
    frontChannelLogoutUri: Uri(path: 'redirect.html'),
    uiLocales: ['ar'],
    refreshBefore: (token) {
      return const Duration(seconds: 1);
    },
    strictJwtVerification: true,
    // set to true to enable offline auth
    supportOfflineAuth: false,
    // scopes supported by the provider and needed by the client.
    scope: ['openid', 'profile', 'email', 'offline_access'],
    postLogoutRedirectUri: kIsWeb
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid || Platform.isIOS || Platform.isMacOS
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
        : Platform.isIOS || Platform.isMacOS || Platform.isAndroid
            // scheme: reverse domain name notation of your package name.
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
// final certificationManager = OidcUserManager.lazy(
//   discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
//     Uri.parse('https://www.certification.openid.net/test/a/oidc_dart'),
//   ),
//   clientCredentials: const OidcClientAuthentication.clientSecretPost(
//     clientId: 'my_web_client',
//     clientSecret: 'my_web_client_secret',
//   ),
//   store: OidcDefaultStore(),
//   settings: OidcUserManagerSettings(
//     strictJwtVerification: true,
//     scope: ['profile', 'email'],
//     redirectUri: Uri.parse('http://localhost:22433/redirect.html'),
//     frontChannelLogoutUri: Uri.parse(
//       'http://localhost:22433/redirect.html?requestType=front-channel-logout',
//     ),
//     postLogoutRedirectUri: Uri.parse('http://localhost:22433/redirect.html'),
//     userInfoSettings: const OidcUserInfoSettings(
//       accessTokenLocation: OidcUserInfoAccessTokenLocations.formParameter,
//       requestMethod: OidcConstants_RequestMethod.post,
//       sendUserInfoRequest: true,
//       followDistributedClaims: true,
//     ),
//   ),
// );

///===========================

final initMemoizer = AsyncMemoizer<void>();
Future<void> initApp() {
  return initMemoizer.runOnce(() async {
    currentManager.userChanges().listen((event) {
      cachedAuthedUser.$ = event;
      exampleLogger.info(
        'User changed: ${event?.claims.toJson()}, info: ${event?.userInfo}',
      );
    });

    await currentManager.init();
  });
}

final cachedAuthedUser = SharedValue<OidcUser?>(value: null);
