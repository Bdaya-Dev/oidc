import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/commands/proxy/pub_proxy_command.dart';

/// `oidc flutter` proxy command group.
class FlutterProxyCommand extends OidcBaseCommand {
  /// Creates a [FlutterProxyCommand].
  FlutterProxyCommand({super.logger}) {
    addSubcommand(PubProxyCommand(logger: logger, executable: 'flutter'));
  }

  @override
  final String name = 'flutter';

  @override
  final String description = 'Proxy commands to flutter.';
}
