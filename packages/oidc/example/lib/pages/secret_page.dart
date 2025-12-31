import 'dart:async';
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

class _SecretPageState extends State<SecretPage>
    with SingleTickerProviderStateMixin {
  OidcPlatformSpecificOptions_Web_NavigationMode webNavigationMode =
      OidcPlatformSpecificOptions_Web_NavigationMode.newPage;

  // Offline mode state
  final List<String> _eventLog = [];
  String? _offlineModeReason;
  StreamSubscription<OidcEvent>? _eventSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupEventListener();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    final manager = app_state.currentManagerRx.$;

    // Listen to events
    _eventSubscription = manager.events().listen((event) {
      if (!mounted) return;

      setState(() {
        final timestamp = event.at.toLocal();
        final timeStr =
            '${timestamp.hour.toString().padLeft(2, '0')}:'
            '${timestamp.minute.toString().padLeft(2, '0')}:'
            '${timestamp.second.toString().padLeft(2, '0')}';

        if (event is OidcOfflineModeEnteredEvent) {
          _offlineModeReason = event.reason.name;

          _eventLog.insert(
            0,
            '[$timeStr] OFFLINE MODE ENTERED\n'
            'Reason: ${event.reason.name}\n'
            'Last sync: ${_formatLastSync(event.lastSuccessfulServerContact)}',
          );
        } else if (event is OidcOfflineModeExitedEvent) {
          _offlineModeReason = null;

          _eventLog.insert(
            0,
            '[$timeStr] OFFLINE MODE EXITED\n'
            'Network restored: ${event.networkRestored}\n'
            'Synced at: ${_formatLastSync(event.lastSuccessfulServerContact)}',
          );
        } else if (event is OidcOfflineAuthWarningEvent) {
          _eventLog.insert(
            0,
            '[$timeStr] WARNING\n'
            'Type: ${event.warningType.name}\n'
            'Message: ${event.message}',
          );
        } else if (event is OidcTokenExpiredEvent) {
          _eventLog.insert(0, '[$timeStr] Token Expired');
        } else if (event is OidcTokenExpiringEvent) {
          _eventLog.insert(0, '[$timeStr] Token Expiring Soon');
        }

        // Keep only last 20 events
        if (_eventLog.length > 20) {
          _eventLog.removeRange(20, _eventLog.length);
        }
      });
    });
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';

    final local = lastSync.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final manager = app_state.currentManagerRx.of(context);
    final user = app_state.cachedAuthedUser.of(context);
    if (user == null) {
      // put a guard here as well, just in case
      // the redirect doesn't fire up in time.
      return const SizedBox.shrink();
    }
    final isOffline = manager.isInOfflineMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protected Area'),
        backgroundColor: isOffline ? Colors.orange : null,
        actions: [
          if (isOffline)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20),
                  SizedBox(width: 8),
                  Text('Offline Mode'),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => GoRouter.of(context).go('/'),
            tooltip: 'Back to Home',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.data_object), text: 'Token Data'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverviewTab(manager, user), _buildTokenDataTab(user)],
      ),
    );
  }

  Widget _buildOverviewTab(OidcUserManager manager, OidcUser user) {
    final isOffline = manager.isInOfflineMode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Offline Status Card
        Card(
          color: isOffline ? Colors.red.shade50 : Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOffline ? Icons.cloud_off : Icons.cloud_done,
                      size: 32,
                      color: isOffline ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOffline ? 'OFFLINE MODE' : 'ONLINE',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: isOffline ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (_offlineModeReason != null)
                            Text(
                              'Reason: $_offlineModeReason',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.sync),
                  title: const Text('Last Server Contact'),
                  subtitle: Text(
                    _formatLastSync(manager.lastSuccessfulServerContact),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.settings),
                  title: const Text('Offline Auth Enabled'),
                  subtitle: Text(
                    manager.settings.supportOfflineAuth ? 'Yes' : 'No',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // User Info Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'ID: ${user.uid}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Actions Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                // Token and Auth actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _tryRefreshToken(manager),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Manual Token Refresh'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final res = await manager.loginAuthorizationCodeFlow(
                            scopeOverride: [...manager.settings.scope, 'api'],
                            promptOverride: ['none'],
                            options: const OidcPlatformSpecificOptions(
                              web: OidcPlatformSpecificOptions_Web(
                                navigationMode:
                                    OidcPlatformSpecificOptions_Web_NavigationMode
                                        .hiddenIFrame,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Silently authorized user! ${res?.uid}',
                              ),
                            ),
                          );
                        } on OidcException catch (e) {
                          if (e.errorResponse != null) {
                            await manager.forgetUser();
                          }
                        } catch (e, st) {
                          app_state.exampleLogger.severe(
                            'Failed to silently authorize user',
                            e,
                            st,
                          );
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Silent Reauth'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await manager.forgetUser();
                      },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Forget User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                // Logout section with web navigation mode
                if (kIsWeb) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Logout',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Web Navigation Mode',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            DropdownButton<
                              OidcPlatformSpecificOptions_Web_NavigationMode
                            >(
                              isExpanded: true,
                              items:
                                  OidcPlatformSpecificOptions_Web_NavigationMode
                                      .values
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e.name),
                                        ),
                                      )
                                      .toList(),
                              value: webNavigationMode,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  webNavigationMode = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await manager.logout(
                            originalUri: Uri.parse('/'),
                            options: OidcPlatformSpecificOptions(
                              web: OidcPlatformSpecificOptions_Web(
                                navigationMode: webNavigationMode,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await manager.logout(originalUri: Uri.parse('/'));
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Event Log (if offline auth is enabled) - at the bottom
        if (manager.settings.supportOfflineAuth) ...[
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Event Log',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(_eventLog.clear);
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear Log'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(8),
                  child: _eventLog.isEmpty
                      ? const Center(
                          child: Text(
                            'No events yet.\nTry testing token refresh.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _eventLog.length,
                          itemBuilder: (context, index) {
                            final log = _eventLog[index];
                            final isError = log.contains(
                              'OFFLINE MODE ENTERED',
                            );
                            final isWarning = log.contains('WARNING');
                            final isSuccess = log.contains(
                              'OFFLINE MODE EXITED',
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isError
                                    ? Colors.red.shade50
                                    : isWarning
                                    ? Colors.orange.shade50
                                    : isSuccess
                                    ? Colors.green.shade50
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenDataTab(OidcUser user) {
    final platform = Theme.of(context).platform;
    final mobilePlatforms = [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ];

    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: kIsWeb
          ? mobilePlatforms.contains(platform)
                ? MaterialTextSelectionControls()
                : DesktopTextSelectionControls()
          : MaterialTextSelectionControls(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDataCard('User ID', user.uid ?? 'N/A'),
          _buildDataCard('UserInfo Response', user.userInfo.toString()),
          _buildDataCard('ID Token Claims', jsonEncode(user.claims.toJson())),
          _buildDataCard('ID Token', user.idToken),
          _buildDataCard('Token', jsonEncode(user.token.toJson())),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryRefreshToken(OidcUserManager manager) async {
    final messenger = ScaffoldMessenger.of(context);

    // Track offline state before the call
    final wasOffline = manager.isInOfflineMode;

    try {
      final result = await manager.refreshToken();

      // Check offline state after the call
      final nowOffline = manager.isInOfflineMode;

      if (result != null) {
        // Got a new token - successful refresh
        if (wasOffline && !nowOffline) {
          // Exited offline mode - network restored!
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Network restored - Token refreshed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Normal refresh while online
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Token refreshed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (!wasOffline && nowOffline) {
        // Just entered offline mode - event listener already logged it
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Network unavailable - Continuing in offline mode',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // result == null, but no offline mode change
        // Either: no refresh token, or already offline
        if (!nowOffline) {
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Text('No refresh token available'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        // If already offline, no snackbar - the event log shows activity
      }
    } catch (e) {
      // Only genuine errors (non-network) reach here when offline auth is enabled
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Refresh failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
