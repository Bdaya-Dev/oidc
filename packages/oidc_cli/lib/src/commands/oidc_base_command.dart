import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:oidc_cli/src/cli_user_manager.dart';
import 'package:oidc_cli/src/file_oidc_store.dart';
import 'package:oidc_core/oidc_core.dart';

/// Base class for OIDC-related CLI commands.
abstract class OidcBaseCommand extends Command<int> {
  /// Creates an [OidcBaseCommand] with a shared [Logger].
  OidcBaseCommand({Logger? logger}) : logger = logger ?? Logger();

  /// Logger used for user-facing output and errors.
  final Logger logger;

  /// Resolves the store file path, with support for overrides.
  Future<FileOidcStore> getStore() async {
    final overridePath = globalResults?['store'] as String?;
    if (overridePath != null && overridePath.trim().isNotEmpty) {
      return FileOidcStore.fromPath(overridePath, logger: logger);
    }

    final envOverridePath = Platform.environment['OIDC_CLI_STORE'];
    if (envOverridePath != null && envOverridePath.trim().isNotEmpty) {
      return FileOidcStore.fromPath(envOverridePath, logger: logger);
    }

    return FileOidcStore.userHome(logger: logger);
  }

  /// Creates a [CliUserManager] from the stored configuration.
  Future<CliUserManager?> getManager({
    required FileOidcStore store,
    Map<String, dynamic>? configOverride,
  }) async {
    final config = configOverride ?? await store.getConfig();
    if (config.isEmpty) {
      return null;
    }

    final issuer = config['issuer'] as String;
    final clientId = config['clientId'] as String;
    final clientSecret = config['clientSecret'] as String?;
    final scopes = (config['scopes'] as List<dynamic>).cast<String>();
    final port = config['port'] as int? ?? 3000;

    final clientCredentials = clientSecret == null
        ? OidcClientAuthentication.none(clientId: clientId)
        : OidcClientAuthentication.clientSecretPost(
            clientId: clientId,
            clientSecret: clientSecret,
          );

    return CliUserManager.lazy(
      cliLogger: logger,
      discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
        Uri.parse(issuer),
      ),
      clientCredentials: clientCredentials,
      store: store,
      settings: OidcUserManagerSettings(
        redirectUri: Uri.parse('http://localhost:$port'),
        scope: scopes,
      ),
    );
  }

  /// Retrieves an access token from the stored session, optionally refreshing.
  Future<String?> getAccessTokenFromStoredSession({
    required FileOidcStore store,
    bool autoRefresh = true,
  }) async {
    final manager = await getManager(store: store);
    if (manager == null) {
      return null;
    }

    try {
      await manager.init();
      var user = manager.currentUser;
      if (user == null) {
        return null;
      }

      if (autoRefresh) {
        final expiresAt = user.token.calculateExpiresAt();
        if (expiresAt != null &&
            expiresAt.isBefore(
              DateTime.now().add(const Duration(minutes: 1)),
            )) {
          user = await manager.refreshToken();
        }
      }

      return user?.token.accessToken;
    } finally {
      await manager.dispose();
    }
  }
}
