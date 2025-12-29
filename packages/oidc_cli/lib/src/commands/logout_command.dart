import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// Logs out and clears the stored session.
class LogoutCommand extends OidcBaseCommand {
  /// Creates a [LogoutCommand].
  LogoutCommand({super.logger});

  @override
  final String name = 'logout';
  @override
  final String description = 'Log out and clear stored session.';

  @override
  Future<int> run() async {
    final store = await getStore();
    final manager = await getManager(store: store);

    if (manager != null) {
      try {
        await manager.init();
        // Favored over full logout: revoke tokens.
        // We use forgetUser: false because we will do a more thorough cleanup manually.
        logger.info('Revoking refresh token...');
        await manager.revokeRefreshToken(forgetUser: false);
        logger.info('Revoking access token...');
        await manager.revokeAccessToken(forgetUser: false);

        await manager.forgetUser();
      } on Exception catch (e) {
        logger.warn('Failed to perform remote logout/revocation: $e');
      } finally {
        await manager.dispose();
      }
    }
    try {
      // ensure store is cleared of tokens
      await store.removeAll('oidc');
      logger.success('Logged out successfully.');
      return ExitCode.success.code;
    } on Exception catch (e) {
      logger.err('Error clearing local store: $e');
      return ExitCode.software.code;
    }
  }
}
