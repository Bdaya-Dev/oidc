import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// Prints the current access token, refreshing if needed.
class TokenGetCommand extends OidcBaseCommand {
  /// Creates a [TokenGetCommand].
  TokenGetCommand({super.logger}) {
    argParser.addFlag(
      'auto-refresh',
      defaultsTo: true,
      help:
          'If enabled, refreshes the token automatically when it is expired/expiring soon.',
    );
  }
  @override
  final String name = 'get';

  @override
  final String description =
      'Get the current access token, refreshing if needed.';

  @override
  Future<int> run() async {
    final autoRefresh = argResults?['auto-refresh'] as bool;
    final store = await getStore();
    final manager = await getManager(store: store);

    if (manager == null) {
      logger.err('No active session. Please login first.');
      return ExitCode.software.code;
    }

    try {
      await manager.init();
      var user = manager.currentUser;

      if (user == null) {
        logger.err('No active session. Please login first.');
        return ExitCode.software.code;
      }

      if (autoRefresh) {
        final expiresAt = user.token.calculateExpiresAt();
        if (expiresAt != null &&
            expiresAt.isBefore(
              DateTime.now().add(const Duration(minutes: 1)),
            )) {
          logger.info('Token expired or expiring soon. Refreshing...');
          user = await manager.refreshToken();
        }
      }

      if (user?.token.accessToken == null) {
        logger.err('No access token available.');
        return ExitCode.software.code;
      }

      // Token output is intentionally plain text for easy scripting.
      logger.info(user!.token.accessToken);
      return ExitCode.success.code;
    } on Exception catch (e) {
      logger.err('Error retrieving token: $e');
      return ExitCode.software.code;
    } finally {
      await manager.dispose();
    }
  }
}
