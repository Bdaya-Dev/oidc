import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';

/// Logs in using the Resource Owner Password Credentials grant.
class LoginPasswordCommand extends OidcBaseCommand {
  /// Creates a [LoginPasswordCommand].
  LoginPasswordCommand({super.logger}) {
    argParser
      ..addOption('username', abbr: 'u', help: 'Username.')
      ..addOption('password', help: 'Password.')
      ..addOption('issuer', abbr: 'i', help: 'The Issuer URI.')
      ..addOption('client-id', abbr: 'c', help: 'The Client ID.')
      ..addOption(
        'client-secret',
        abbr: 's',
        help: 'The Client Secret (optional).',
      )
      ..addOption(
        'scopes',
        abbr: 'S',
        defaultsTo: 'openid profile email offline_access',
        help: 'Space separated scopes.',
      )
      ..addOption(
        'redirect-port',
        abbr: 'p',
        defaultsTo: '3000',
        help:
            'Saved in config for future interactive logins; not used for password login.',
      )
      ..addFlag(
        'auto-refresh',
        defaultsTo: true,
        help:
            'If enabled, refreshes the token after login when it is expired/expiring soon.',
      )
      ..addOption(
        'add-to-dart-pub',
        help: 'If provided, adds the token to dart pub for this hosted URL.',
      );
  }
  @override
  final String name = 'password';

  @override
  final String description =
      'Log in using the Resource Owner Password Credentials grant.';

  @override
  Future<int> run() async {
    final username = argResults?['username'] as String?;
    final password = argResults?['password'] as String?;
    final issuerArg = argResults?['issuer'] as String?;
    final clientIdArg = argResults?['client-id'] as String?;
    final clientSecretArg = argResults?['client-secret'] as String?;
    final scopesArg = argResults?['scopes'] as String;
    final portArg = int.parse(argResults?['redirect-port'] as String);
    final autoRefresh = argResults?['auto-refresh'] as bool;
    final hostedUrlArg = argResults?['add-to-dart-pub'] as String?;

    if (username == null || username.trim().isEmpty) {
      logger
        ..err('Error: --username is required.')
        ..info(argParser.usage);
      return ExitCode.usage.code;
    }
    if (password == null || password.isEmpty) {
      logger
        ..err('Error: --password is required.')
        ..info(argParser.usage);
      return ExitCode.usage.code;
    }

    final store = await getStore();
    final existingConfig = await store.getConfig();

    final issuer = (issuerArg != null && issuerArg.trim().isNotEmpty)
        ? issuerArg
        : (existingConfig['issuer'] as String?);
    final clientId = (clientIdArg != null && clientIdArg.trim().isNotEmpty)
        ? clientIdArg
        : (existingConfig['clientId'] as String?);

    if (issuer == null || issuer.trim().isEmpty || clientId == null) {
      logger
        ..err(
          'Error: --issuer and --client-id are required (or must exist in the saved config).',
        )
        ..info(argParser.usage);
      return ExitCode.usage.code;
    }

    final clientSecret = (clientSecretArg != null)
        ? clientSecretArg
        : (existingConfig['clientSecret'] as String?);
    final hostedUrl = (hostedUrlArg != null)
        ? hostedUrlArg
        : (existingConfig['hostedUrl'] as String?);

    final scopes = scopesArg
        .split(RegExp(r'\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);

    // Persist config for subsequent commands.
    final config = {
      'issuer': issuer,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'scopes': scopes,
      'port': portArg,
      'hostedUrl': ?hostedUrl,
    };
    await store.setConfig(config);

    final manager = await getManager(store: store, configOverride: config);
    if (manager == null) {
      logger.err('Failed to create manager.');
      return ExitCode.software.code;
    }

    try {
      logger.info('Initializing manager...');
      await manager.init();

      logger.info('Logging in...');
      var user = await manager.loginPassword(
        username: username,
        password: password,
        scopeOverride: scopes,
      );

      if (user == null) {
        logger.err('Login failed.');
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
          if (user == null) {
            logger.err('Refresh failed.');
            return ExitCode.software.code;
          }
        }
      }

      logger
        ..success('Authentication successful!')
        ..info('Access Token: ${user.token.accessToken}');

      if (hostedUrl != null && user.token.accessToken != null) {
        await addToDartPub(
          logger: logger,
          hostedUrl: hostedUrl,
          token: user.token.accessToken!,
        );
      }

      return ExitCode.success.code;
    } finally {
      await manager.dispose();
    }
  }
}
