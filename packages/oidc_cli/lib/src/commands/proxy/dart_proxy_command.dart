import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/commands/proxy/pub_proxy_command.dart';

/// `oidc dart` proxy command group.
class DartProxyCommand extends OidcBaseCommand {
  /// Creates a [DartProxyCommand].
  DartProxyCommand({super.logger}) {
    addSubcommand(PubProxyCommand(logger: logger, executable: 'dart'));
  }

  @override
  final String name = 'dart';

  @override
  final String description = 'Proxy commands to dart.';
}
