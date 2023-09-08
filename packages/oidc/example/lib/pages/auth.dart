// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_example/state.dart' as app_state;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final userNameController = TextEditingController();
  final passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    //remember, you can only enter this route if there is no user.
    final currentRoute = GoRouterState.of(context);
    final originalUri =
        currentRoute.uri.queryParameters[OidcConstants_Store.originalUri];
    final parsedOriginalUri =
        originalUri == null ? null : Uri.tryParse(originalUri);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth page'),
      ),
      body: ListView(
        children: [
          const Text('Resource owner grant'),
          TextField(
            controller: userNameController,
          ),
          TextField(
            controller: passwordController,
          ),
          ElevatedButton(
            onPressed: () {
              // TODO(ahmednfwela): add password login.
            },
            child: const Text('login with Resource owner grant'),
          ),
          const Divider(),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await app_state.manager.loginAuthorizationCodeFlow(
                originalUri: parsedOriginalUri ?? Uri.parse('/'),
                //store any arbitrary data, here we store the authorization
                //start time.
                extraStateData: DateTime.now().toIso8601String(),
                // this translates to the `scope` parameter:  "openid profile"
                scopeOverride: [
                  // defaultScopes is [openid]
                  ...OidcUserManagerSettings.defaultScopes,
                  OidcConstants_Scopes.profile,
                ],
                // login options.
                options: const OidcAuthorizePlatformSpecificOptions(
                  web: OidcAuthorizePlatformOptions_Web(
                    navigationMode:
                        OidcAuthorizePlatformOptions_Web_NavigationMode.newPage,
                    popupHeight: 800,
                    popupWidth: 730,
                  ),
                  // these settings are from https://pub.dev/packages/flutter_appauth.
                  android: OidcAuthorizePlatformOptions_AppAuth(
                    allowInsecureConnections: true,
                    preferEphemeralSession: true,
                  ),
                  ios: OidcAuthorizePlatformOptions_AppAuth(
                    allowInsecureConnections: true,
                    preferEphemeralSession: true,
                  ),
                  macos: OidcAuthorizePlatformOptions_AppAuth(
                    allowInsecureConnections: true,
                    preferEphemeralSession: true,
                  ),
                ),
              );

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'loginAuthorizationCodeFlow returned user id: ${result?.uid}',
                  ),
                ),
              );
            },
            child: const Text('Start Auth code flow'),
          ),
        ],
      ),
    );
  }
}
