import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';

/// Logs in using the `device_code` grant.
class LoginDeviceCommand extends OidcBaseCommand {
  /// Creates a [LoginDeviceCommand].
  LoginDeviceCommand({super.logger}) {
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
        'add-to-dart-pub',
        help:
            'If provided, runs `dart pub token add <hostedUrl>` and pipes the access token to it.',
      );
  }
  @override
  final String name = 'device';

  @override
  final String description =
      'Request an access token using the device_code grant and print it.';

  @override
  Future<int> run() async {
    final store = await getStore();
    final existingConfig = await store.getConfig();

    final issuerArg = argResults?['issuer'] as String?;
    final clientIdArg = argResults?['client-id'] as String?;
    final clientSecretArg = argResults?['client-secret'] as String?;
    final scopesArg = argResults?['scopes'] as String;
    final hostedUrlArg = argResults?['add-to-dart-pub'] as String?;

    final issuer = (issuerArg != null && issuerArg.trim().isNotEmpty)
        ? issuerArg
        : (existingConfig['issuer'] as String?);
    final clientId = (clientIdArg != null && clientIdArg.trim().isNotEmpty)
        ? clientIdArg
        : (existingConfig['clientId'] as String?);
    final clientSecret = (clientSecretArg != null)
        ? clientSecretArg
        : (existingConfig['clientSecret'] as String?);

    if (issuer == null || issuer.trim().isEmpty || clientId == null) {
      logger
        ..err(
          'Error: --issuer and --client-id are required (or must exist in the saved config).',
        )
        ..info(argParser.usage);
      return ExitCode.usage.code;
    }

    final scopes = scopesArg
        .split(RegExp(r'\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);

    final hostedUrl = (hostedUrlArg != null)
        ? hostedUrlArg
        : (existingConfig['hostedUrl'] as String?);

    // Persist config first (mirrors interactive login behavior).
    final config = {
      ...existingConfig,
      'issuer': issuer,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'scopes': scopes,
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

      final user = await manager.loginDeviceCodeFlow(
        scopeOverride: scopes,
        onVerification: (resp) {
          final verificationUri =
              resp.verificationUriComplete ?? resp.verificationUri;
          logger.info('Open this URL to authenticate: $verificationUri');
          if (resp.verificationUriComplete == null) {
            logger.info('User code: ${resp.userCode}');
          }
        },
      );
      final token = user?.token.accessToken;
      if (token == null || token.trim().isEmpty) {
        logger.err('Device authorization did not complete.');
        return ExitCode.software.code;
      }

      // Token output is intentionally plain text for easy scripting.
      logger.info(token);

      if (hostedUrl != null && hostedUrl.trim().isNotEmpty) {
        await addToDartPub(logger: logger, hostedUrl: hostedUrl, token: token);
      }

      return ExitCode.success.code;
    } finally {
      await manager.dispose();
    }
  }
}
