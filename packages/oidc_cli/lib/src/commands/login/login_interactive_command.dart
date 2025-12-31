import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';

/// Performs an interactive login using the authorization code flow.
class LoginInteractiveCommand extends OidcBaseCommand {
  /// Creates a [LoginInteractiveCommand].
  LoginInteractiveCommand({super.logger}) {
    argParser
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
        help: 'Local port for redirect.',
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
  final String name = 'interactive';

  @override
  final String description =
      'Log in using the Authorization Code flow with a local loopback redirect.';

  @override
  Future<int> run() async {
    final issuer = argResults?['issuer'] as String?;
    final clientId = argResults?['client-id'] as String?;
    final clientSecret = argResults?['client-secret'] as String?;
    final scopes = (argResults?['scopes'] as String)
        .split(RegExp(r'\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    final port = int.parse(argResults?['redirect-port'] as String);
    final autoRefresh = argResults?['auto-refresh'] as bool;
    final hostedUrl = argResults?['add-to-dart-pub'] as String?;

    if (issuer == null || clientId == null) {
      logger
        ..err('Error: --issuer and --client-id are required.')
        ..info(argParser.usage);
      return ExitCode.usage.code;
    }

    final store = await getStore();
    // Save config first
    final config = {
      'issuer': issuer,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'scopes': scopes,
      'port': port,
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
      var user = await manager.loginAuthorizationCodeFlow();

      if (user == null) {
        logger.err('Login failed.');
        return ExitCode.software.code;
      }

      if (autoRefresh) {
        // If the token is already near expiry, refresh it so that callers (and
        // `--add-to-dart-pub`) get a fresh access token.
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
