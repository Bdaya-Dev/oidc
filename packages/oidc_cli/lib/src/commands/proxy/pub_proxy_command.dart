import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_cli/src/utils/dart_pub.dart';

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

    final rest = argResults?.rest ?? const <String>[];

    final isExplicitTokenAdd =
        rest.length >= 2 && rest[0] == 'token' && rest[1] == 'add';

    if (!isExplicitTokenAdd &&
        hostedUrl != null &&
        hostedUrl.trim().isNotEmpty) {
      final token = await getAccessTokenFromStoredSession(
        store: store,
        autoRefresh: autoRefresh,
      );

      if (token == null || token.trim().isEmpty) {
        logger.err(
          'No active session/token found for pub. '
          'Run `oidc login --add-to-dart-pub <hostedUrl>` first.',
        );
        return ExitCode.software.code;
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
}
