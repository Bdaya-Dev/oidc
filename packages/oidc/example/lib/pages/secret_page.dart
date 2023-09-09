import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oidc_example/app_state.dart' as app_state;

class SecretPage extends StatelessWidget {
  const SecretPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = app_state.cachedAuthedUser.of(context);
    if (user == null) {
      // put a guard here as well, just in case
      // the redirect doesn't fire up in time.
      return const SizedBox.shrink();
    }
    return Scaffold(
      body: ListView(
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
          ElevatedButton(
            onPressed: app_state.manager.logout,
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
    );
  }
}
