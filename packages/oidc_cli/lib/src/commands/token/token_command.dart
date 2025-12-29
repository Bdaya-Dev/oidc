import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/commands/token/token_get_command.dart';
import 'package:oidc_cli/src/commands/token/token_refresh_command.dart';

/// `oidc token` command group.
class TokenCommand extends OidcBaseCommand {
  /// Creates a [TokenCommand].
  TokenCommand({super.logger}) {
    addSubcommand(TokenGetCommand(logger: logger));
    addSubcommand(TokenRefreshCommand(logger: logger));
  }

  @override
  final String name = 'token';
  @override
  final String description = 'Token-related commands.';
}
