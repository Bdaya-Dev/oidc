import 'dart:convert';

import 'package:oidc_core/oidc_core.dart';
import 'package:http/http.dart' as http;

void main() async {
  final googleUri =
      Uri.parse('https://accounts.google.com/.well-known/openid-configuration');
  final googleConfigResp = await http.get(googleUri);
  final parsedJson = jsonDecode(googleConfigResp.body);
  final parsedMetadata = OidcProviderMetadata.fromJson(parsedJson);
  print(parsedMetadata.authorizationEndpoint);
}
