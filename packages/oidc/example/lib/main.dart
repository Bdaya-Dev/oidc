import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/pages/add_manager_dialog.dart';
import 'package:oidc_example/pages/auth.dart';
import 'package:oidc_example/pages/home.dart';
import 'package:oidc_example/pages/secret_page.dart';
// you must run this app with --web-port 22433

void main() {
  usePathUrlStrategy();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(
    SharedValue.wrapApp(
      MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
        ),
        routerConfig: GoRouter(
          routes: [
            ShellRoute(
              builder: (context, state, child) {
                final selectedManager = app_state.currentManagerRx.of(context);
                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      'OIDC Example App (Selected Manager: ${selectedManager.id})',
                    ),
                    actions: [
                      if (!selectedManager.didInit)
                        IconButton(
                          icon: const Icon(Icons.play_circle),
                          tooltip: 'Initialize the manager',
                          color: Colors.green,
                          onPressed: () async {
                            await selectedManager.init();
                            // Update the current manager to trigger a rebuild.
                            app_state.currentManagerRx.update((x) => x);
                          },
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                  drawer: Drawer(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text(
                            'OIDC Example',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Select the manager',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        for (final manager
                            in app_state.managersRx.of(context)) ...[
                          ListTile(
                            selected: manager == selectedManager,
                            leading: const Icon(Icons.account_circle),
                            title: Text(manager.id ?? '<No Id>'),
                            onTap: () {
                              app_state.currentManagerRx.$ = manager;
                            },
                          ),
                        ],
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Add a new manager'),
                          onTap: () async {
                            // This will add a new manager.
                            // Show the dialog
                            final newManager =
                                await showDialog<OidcUserManager>(
                              context: context,
                              builder: (context) {
                                return const AddManagerDialog();
                              },
                            );
                            if (newManager == null) {
                              return;
                            }
                            app_state.managersRx.update((managers) {
                              return managers..add(newManager);
                            });
                            app_state.currentManagerRx.$ = newManager;
                          },
                        ),
                        // const Divider(),
                        // ListTile(
                        //   leading: const Icon(Icons.home),
                        //   title: const Text('Home'),
                        //   onTap: () => context.go('/'),
                        // ),
                        // ListTile(
                        //   leading: const Icon(Icons.lock),
                        //   title: const Text('Secret Page'),
                        //   onTap: () => context.go('/secret-route'),
                        // ),
                        // ListTile(
                        //   leading: const Icon(Icons.login),
                        //   title: const Text('Login'),
                        //   onTap: () => context.go('/auth'),
                        // ),
                      ],
                    ),
                  ),
                  body: selectedManager.didInit
                      ? child
                      : const Center(
                          child: Text(
                            'Initialize the manager first! Click on the green play button',
                          ),
                        ),
                );
              },
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
                          // Note that this requires usePathUrlStrategy(); from `package:flutter_web_plugins/url_strategy.dart`
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
                ),
              ],
            ),
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
