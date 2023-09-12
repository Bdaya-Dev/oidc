import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_example/app_state.dart' as app_state;

class SecretPage extends StatefulWidget {
  const SecretPage({super.key});

  @override
  State<SecretPage> createState() => _SecretPageState();
}

class _SecretPageState extends State<SecretPage> {
  OidcPlatformSpecificOptions_Web_NavigationMode webNavigationMode =
      OidcPlatformSpecificOptions_Web_NavigationMode.newPage;
  @override
  Widget build(BuildContext context) {
    final user = app_state.cachedAuthedUser.of(context);
    if (user == null) {
      // put a guard here as well, just in case
      // the redirect doesn't fire up in time.
      return const SizedBox.shrink();
    }
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            Center(
              child: Text(
                'You have entered a guarded route!',
                style: Theme.of(context).textTheme.displayLarge,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).go('/');
              },
              child: const Text('back to home'),
            ),
            DropdownButton<OidcPlatformSpecificOptions_Web_NavigationMode>(
              hint: const Text('Web Navigation Mode'),
              items: OidcPlatformSpecificOptions_Web_NavigationMode.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              value: webNavigationMode,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  webNavigationMode = value;
                });
              },
            ),
            ElevatedButton(
              onPressed: () async {
                await app_state.manager.logout(
                  //after logout, go back to home
                  originalUri: Uri.parse('/'),
                  options: OidcPlatformSpecificOptions(
                    web: OidcPlatformSpecificOptions_Web(
                      navigationMode: webNavigationMode,
                    ),
                  ),
                );
              },
              child: const Text('Logout'),
            ),
            const Divider(),
            Text('user id: ${user.uid}'),
            const Divider(),
            Text('claims: ${user.claims.toJson()}'),
            const Divider(),
            Text('id token: ${user.idToken}'),
            const Divider(),
            Text('metadata: ${user.metadata.toJson()}'),
          ],
        ),
      ),
    );
  }
}
