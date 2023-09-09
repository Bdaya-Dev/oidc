// ignore_for_file: avoid_print

import 'package:oidc_core/oidc_core.dart';

void main() async {
  final googleIdp = Uri.parse('https://accounts.google.com/');

  final parsedMetadata = await OidcEndpoints.getProviderMetadata(
    OidcUtils.getWellKnownUriFromBase(googleIdp),
  );
  print(parsedMetadata);
}
