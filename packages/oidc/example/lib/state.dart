import 'dart:io';

import 'package:async/async.dart';
import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

//This file represents a global state, which is bad
//in a production app (since you can't test it).

//usually you would use a dependency injection library
//and put these in a service.
final exampleLogger = Logger('oidc.example');
final initMemoizer = AsyncMemoizer<void>();
Future<void> initApp() {
  return initMemoizer.runOnce(() async {
    manager.userChanges().listen((event) {
      cachedAuthedUser.$ = event;
      exampleLogger.info('User changed: ${event?.claims.toJson()}');
    });

    await manager.init();
  });
}

final cachedAuthedUser = SharedValue<OidcUser?>(value: null);
final manager = OidcUserManager.lazy(
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
    scope: ['openid', 'profile', 'email', 'offline_access', 'api'],

    /// you must run this app with --web-port 22433
    redirectUri: kIsWeb
        ? Uri.parse('http://localhost:22433/redirect.html')
        : Platform.isAndroid
            ? Uri.parse('com.bdayadev.oidc.example:/oauth2redirect')
            : Uri(),
  ),
);
