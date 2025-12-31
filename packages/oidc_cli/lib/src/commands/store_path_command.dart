import 'dart:io';

import 'package:oidc_cli/src/commands/oidc_base_command.dart';

/// Prints the path to the JSON store file.
class StorePathCommand extends OidcBaseCommand {
  /// Creates a [StorePathCommand].
  StorePathCommand({super.logger});

  @override
  final String name = 'store-path';
  @override
  final String description = 'Print the path to the store JSON file.';

  @override
  Future<int> run() async {
    final store = await getStore();
    logger.info(File(store.file.path).absolute.path);
    return 0;
  }
}
