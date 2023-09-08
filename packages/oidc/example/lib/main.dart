import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_example/pages/home.dart';
import 'package:oidc_example/pages/secret-page.dart';
import 'package:oidc_example/state.dart' as app_state;

import 'pages/auth.dart';

// you must run this app with --web-port 22433

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(
    SharedValue.wrapApp(
      MaterialApp.router(
        theme: ThemeData(
          useMaterial3: true,
        ),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/secret-route',
              redirect: (context, state) {
                final user = app_state.cachedAuthedUser.of(context);
                if (user == null) {
                  return Uri(
                    path: '/auth',
                    queryParameters: {
                      OidcConstants_Store.originalUri: state.uri.toString(),
                    },
                  ).toString();
                }
                return null;
              },
              builder: (context, state) => const SecretPage(),
            ),
            GoRoute(
              path: '/auth',
              redirect: (context, state) {
                //
                final user = app_state.cachedAuthedUser.of(context);
                if (user != null) {
                  final originalUri = state
                      .uri.queryParameters[OidcConstants_Store.originalUri];
                  if (originalUri != null) {
                    return originalUri;
                  }
                  return '/secret-route';
                }
                return null;
              },
              builder: (context, state) => const AuthPage(),
            )
          ],
        ),
        builder: (context, child) {
          /// A platform-agnostic way to initialize
          /// the app state before displaying the routes.
          return FutureBuilder(
            future: app_state.initApp(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(snapshot.error.toString()),
                );
              }
              return child!;
            },
          );
        },
      ),
    ),
  );
}
