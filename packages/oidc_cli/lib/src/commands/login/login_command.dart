import 'package:oidc_cli/src/commands/login/login_device_command.dart';
import 'package:oidc_cli/src/commands/login/login_interactive_command.dart';
import 'package:oidc_cli/src/commands/login/login_password_command.dart';
import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// `oidc login` command group.
class LoginCommand extends OidcBaseCommand {
  /// Creates a [LoginCommand].
  LoginCommand({super.logger}) {
    addSubcommand(LoginInteractiveCommand(logger: logger));
    addSubcommand(LoginPasswordCommand(logger: logger));
    addSubcommand(LoginDeviceCommand(logger: logger));
  }

  @override
  final String name = 'login';
  @override
  final String description = 'Log in to an OIDC provider.';
}
