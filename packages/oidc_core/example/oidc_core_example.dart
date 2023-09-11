// ignore_for_file: avoid_print

import 'package:oidc_core/oidc_core.dart';

void main() async {
  final idp = Uri.parse('https://demo.duendesoftware.com/');

  final parsedMetadata = await OidcEndpoints.getProviderMetadata(
    OidcUtils.getWellKnownUriFromBase(idp),
  );

  print(parsedMetadata);
}
