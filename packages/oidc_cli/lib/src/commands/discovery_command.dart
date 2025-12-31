import 'dart:convert';

import 'package:mason_logger/mason_logger.dart' show ExitCode;
import 'package:oidc_cli/src/commands/oidc_base_command.dart';
import 'package:oidc_core/oidc_core.dart';

/// Fetches and prints the OIDC discovery document (provider metadata).
class DiscoveryCommand extends OidcBaseCommand {
  /// Creates a [DiscoveryCommand].
  DiscoveryCommand({super.logger}) {
    argParser
      ..addOption(
        'issuer',
        abbr: 'i',
        help:
            'The Issuer URI. If omitted, uses the issuer saved in the CLI store config (if any).',
      )
      ..addOption(
        'well-known',
        abbr: 'w',
        help:
            'The full ".well-known/openid-configuration" URI. If provided, it takes precedence over --issuer.',
      );
  }
  @override
  final String name = 'discovery';

  @override
  final String description =
      'Fetch and print the OIDC discovery document (provider metadata).';

  @override
  Future<int> run() async {
    final store = await getStore();
    final config = await store.getConfig();

    final issuerArg = argResults?['issuer'] as String?;
    final wellKnownArg = argResults?['well-known'] as String?;

    final issuerFromConfig = config['issuer'] as String?;

    Uri wellKnownUri;
    if (wellKnownArg != null && wellKnownArg.trim().isNotEmpty) {
      wellKnownUri = Uri.parse(wellKnownArg);
    } else {
      final issuer = (issuerArg != null && issuerArg.trim().isNotEmpty)
          ? issuerArg
          : issuerFromConfig;

      if (issuer == null || issuer.trim().isEmpty) {
        logger
          ..err('Error: --issuer (or --well-known) is required.')
          ..info(argParser.usage);
        return ExitCode.usage.code;
      }

      wellKnownUri = OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(issuer));
    }

    try {
      final metadata = await OidcEndpoints.getProviderMetadata(wellKnownUri);
      logger.info(const JsonEncoder.withIndent('  ').convert(metadata.src));
      return ExitCode.success.code;
    } on Exception catch (e) {
      logger.err('Error fetching discovery document: $e');
      return ExitCode.software.code;
    }
  }
}
