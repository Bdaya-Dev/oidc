import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    final platform = Theme.of(context).platform;
    final mobilePlatforms = [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ];
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: SelectableRegion(
          focusNode: FocusNode(),
          selectionControls: kIsWeb
              ? mobilePlatforms.contains(platform)
                  ? MaterialTextSelectionControls()
                  : DesktopTextSelectionControls()
              : MaterialTextSelectionControls(),
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
              const Divider(),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final res = await app_state.currentManager
                        .loginAuthorizationCodeFlow(
                      // you can change scope too!
                      scopeOverride: [
                        ...app_state.currentManager.settings.scope,
                        'api',
                      ],
                      promptOverride: ['none'],
                      options: const OidcPlatformSpecificOptions(
                        web: OidcPlatformSpecificOptions_Web(
                          navigationMode:
                              OidcPlatformSpecificOptions_Web_NavigationMode
                                  .hiddenIFrame,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('silently authorized user! ${res?.uid}'),
                        ),
                      );
                    }
                  } on OidcException catch (e) {
                    if (e.errorResponse != null) {
                      await app_state.currentManager.forgetUser();
                    }
                  } catch (e, st) {
                    app_state.exampleLogger
                        .severe('Failed to silently authorize user', e, st);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to silently authorize user'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Reauthorize with prompt none'),
              ),
              const Divider(),
              if (kIsWeb) ...[
                Text(
                  'Logout Web Navigation Mode',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<
                      OidcPlatformSpecificOptions_Web_NavigationMode>(
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
                ),
              ],
              ElevatedButton(
                onPressed: () async {
                  await app_state.currentManager.logout(
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
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final res =
                            await app_state.currentManager.refreshToken();
                        if (res == null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'It is not possible to refresh the token.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Manually refreshed token!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'An error occurred trying to '
                                'refresh the token',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Refresh token manually'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await app_state.currentManager.forgetUser();
                    },
                    child: const Text('Forget User'),
                  ),
                ],
              ),
              const Divider(),
              Text('user id: ${user.uid}'),
              const Divider(),
              Text('userInfo endpoint response: ${user.userInfo}'),
              const Divider(),
              Text('id token claims: ${user.claims.toJson()}'),
              const Divider(),
              Text('id token: ${user.idToken}'),
              const Divider(),
              Text('token: ${jsonEncode(user.token.toJson())}'),
            ],
          ),
        ),
      ),
    );
  }
}
