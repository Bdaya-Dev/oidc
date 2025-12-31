import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// Prints the current login status.
class StatusCommand extends OidcBaseCommand {
  /// Creates a [StatusCommand].
  StatusCommand({super.logger});

  @override
  final String name = 'status';
  @override
  final String description = 'Show current login status.';

  @override
  Future<int> run() async {
    final store = await getStore();
    final manager = await getManager(store: store);

    if (manager == null) {
      logger.info('Not logged in (no configuration found).');
      return 0;
    }

    try {
      await manager.init();
      final user = manager.currentUser;
      if (user == null) {
        logger.info('Not logged in.');
      } else {
        logger.info('Logged in.');
        final claims = user.aggregatedClaims;
        if (claims.containsKey('email')) {
          logger.info('User: ${claims['email']}');
        } else if (claims.containsKey('sub')) {
          logger.info('User ID: ${claims['sub']}');
        }

        final expiresAt = user.token.calculateExpiresAt();
        if (expiresAt != null) {
          logger.info('Token expires at: $expiresAt');
          if (expiresAt.isBefore(DateTime.now())) {
            logger.warn('(Expired)');
          }
        }
      }
    } finally {
      await manager.dispose();
    }

    return 0;
  }
}
