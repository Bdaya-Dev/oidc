import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// Refreshes the current access token and prints it.
class TokenRefreshCommand extends OidcBaseCommand {
  /// Creates a [TokenRefreshCommand].
  TokenRefreshCommand({super.logger});

  @override
  final String name = 'refresh';

  @override
  final String description = 'Refresh the current access token and print it.';

  @override
  Future<int> run() async {
    final store = await getStore();
    final manager = await getManager(store: store);

    if (manager == null) {
      logger.err('No active session. Please login first.');
      return ExitCode.software.code;
    }

    try {
      await manager.init();
      final user = manager.currentUser;

      if (user == null) {
        logger.err('No active session. Please login first.');
        return ExitCode.software.code;
      }

      logger.info('Refreshing token...');
      final refreshedUser = await manager.refreshToken();

      if (refreshedUser?.token.accessToken == null) {
        logger.err('No access token available.');
        return ExitCode.software.code;
      }

      // Token output is intentionally plain text for easy scripting.
      logger.info(refreshedUser!.token.accessToken);
      return ExitCode.success.code;
    } on Exception catch (e) {
      logger.err('Error refreshing token: $e');
      return ExitCode.software.code;
    } finally {
      await manager.dispose();
    }
  }
}
