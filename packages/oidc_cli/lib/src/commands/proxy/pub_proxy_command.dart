import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';
import 'package:oidc_cli/src/utils/oauth_grants.dart';

/// Proxies `<tool> pub ...` while ensuring the pub token is set.
class PubProxyCommand extends OidcBaseCommand {
  /// Creates a [PubProxyCommand].
  PubProxyCommand({required this.executable, super.logger}) {
    argParser
      ..addOption(
        'hosted-url',
        help:
            'Hosted pub repository URL (overrides saved config.hostedUrl). '
            'If omitted, uses config.hostedUrl when available.',
      )
      ..addFlag(
        'auto-refresh',
        defaultsTo: true,
        help:
            'If enabled, refreshes the stored-session token when it is expired/expiring soon before using it for pub.',
      )
      ..addFlag(
        'client-credentials',
        negatable: false,
        help:
            'If set, and no stored session token exists, request an access '
            'token using the client_credentials grant (requires issuer/client-id '
            'and often client-secret).',
      )
      ..addOption(
        'issuer',
        abbr: 'i',
        help:
            'Issuer URI for client_credentials fallback (overrides config.issuer).',
      )
      ..addOption(
        'client-id',
        abbr: 'c',
        help:
            'Client ID for client_credentials fallback (overrides config.clientId).',
      )
      ..addOption(
        'client-secret',
        abbr: 's',
        help:
            'Client secret for client_credentials fallback (overrides config.clientSecret).',
      )
      ..addOption(
        'scopes',
        abbr: 'S',
        help:
            'Space separated scopes for client_credentials fallback (overrides config.scopes).',
      );
  }

  /// The tool executable name to proxy (for example, `dart` or `flutter`).
  final String executable;

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Proxy commands to `<tool> pub ...` and ensure pub token from the '
      'current OIDC session (when configured).';

  @override
  Future<int> run() async {
    final store = await getStore();
    final config = await store.getConfig();
    final hostedUrlArg = argResults?['hosted-url'] as String?;
    final hostedUrl = (hostedUrlArg != null && hostedUrlArg.trim().isNotEmpty)
        ? hostedUrlArg
        : (config['hostedUrl'] as String?);

    final autoRefresh = argResults?['auto-refresh'] as bool;
    final useClientCredentials =
        (argResults?['client-credentials'] as bool?) ?? false;

    final rest = argResults?.rest ?? const <String>[];

    final isExplicitTokenAdd =
        rest.length >= 2 && rest[0] == 'token' && rest[1] == 'add';

    if (!isExplicitTokenAdd &&
        hostedUrl != null &&
        hostedUrl.trim().isNotEmpty) {
      var token = await getAccessTokenFromStoredSession(
        store: store,
        autoRefresh: autoRefresh,
      );

      if (token == null || token.trim().isEmpty) {
        if (!useClientCredentials) {
          logger.err(
            'No active session/token found for pub. '
            'Run `oidc login --add-to-dart-pub <hostedUrl>` first,\n'
            'or pass `--client-credentials` '
            '(with issuer/client-id/client-secret as needed) '
            'to fetch a token on-demand.',
          );
          return ExitCode.software.code;
        }

        token = await _getAccessTokenViaClientCredentials(config: config);

        if (token == null || token.trim().isEmpty) {
          logger.err('Failed to obtain access token via client_credentials.');
          return ExitCode.software.code;
        }
      }

      await addToDartPub(logger: logger, hostedUrl: hostedUrl, token: token);
    }

    final process = await Process.start(executable, [
      'pub',
      ...rest,
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;
    return exitCode;
  }

  Future<String?> _getAccessTokenViaClientCredentials({
    required Map<String, dynamic> config,
  }) async {
    final issuerArg = argResults?['issuer'] as String?;
    final clientIdArg = argResults?['client-id'] as String?;
    final clientSecretArg = argResults?['client-secret'] as String?;
    final scopesArg = argResults?['scopes'] as String?;

    final issuer = (issuerArg != null && issuerArg.trim().isNotEmpty)
        ? issuerArg
        : (config['issuer'] as String?);
    final clientId = (clientIdArg != null && clientIdArg.trim().isNotEmpty)
        ? clientIdArg
        : (config['clientId'] as String?);
    final clientSecret = (clientSecretArg != null)
        ? clientSecretArg
        : (config['clientSecret'] as String?);

    if (issuer == null || issuer.trim().isEmpty || clientId == null) {
      logger.err(
        'Error: `--client-credentials` requires --issuer and --client-id (or saved config.issuer/config.clientId).',
      );
      return null;
    }

    final scopes = (scopesArg != null && scopesArg.trim().isNotEmpty)
        ? scopesArg
              .split(RegExp(r'\s+'))
              .where((s) => s.trim().isNotEmpty)
              .toList(growable: false)
        : ((config['scopes'] as List<dynamic>?)?.cast<String>() ??
              const <String>[]);

    return requestClientCredentialsAccessToken(
      logger: logger,
      issuer: issuer,
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: scopes,
    );
  }
}
