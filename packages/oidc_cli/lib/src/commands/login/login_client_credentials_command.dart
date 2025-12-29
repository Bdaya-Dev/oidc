import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';
import 'package:oidc_cli/src/utils/oauth_grants.dart';

/// Logs in using the `client_credentials` grant.
class LoginClientCredentialsCommand extends OidcBaseCommand {
  /// Creates a [LoginClientCredentialsCommand].
  LoginClientCredentialsCommand({super.logger}) {
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
        help:
            'Space separated scopes. If omitted, uses saved config scopes (if any).',
      )
      ..addOption(
        'add-to-dart-pub',
        help:
            'If provided, runs `dart pub token add <hostedUrl>` and pipes the access token to it.',
      );
  }
  @override
  final String name = 'client-credentials';

  @override
  final String description =
      'Request an access token using the client_credentials grant and print it.';

  @override
  Future<int> run() async {
    final store = await getStore();
    final existingConfig = await store.getConfig();

    final issuerArg = argResults?['issuer'] as String?;
    final clientIdArg = argResults?['client-id'] as String?;
    final clientSecretArg = argResults?['client-secret'] as String?;
    final scopesArg = argResults?['scopes'] as String?;
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

    final scopes = (scopesArg != null && scopesArg.trim().isNotEmpty)
        ? scopesArg
              .split(RegExp(r'\s+'))
              .where((s) => s.trim().isNotEmpty)
              .toList(growable: false)
        : ((existingConfig['scopes'] as List<dynamic>?)?.cast<String>() ??
              const <String>[]);

    final hostedUrl = (hostedUrlArg != null)
        ? hostedUrlArg
        : (existingConfig['hostedUrl'] as String?);

    final token = await requestClientCredentialsAccessToken(
      logger: logger,
      issuer: issuer,
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: scopes,
    );

    if (token == null || token.trim().isEmpty) {
      logger.err('No access token returned.');
      return ExitCode.software.code;
    }

    // Token output is intentionally plain text for easy scripting.
    logger.info(token);

    if (hostedUrl != null && hostedUrl.trim().isNotEmpty) {
      await addToDartPub(logger: logger, hostedUrl: hostedUrl, token: token);
    }

    return ExitCode.success.code;
  }
}
