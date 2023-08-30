// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

void main() async {
  final googleUri =
      Uri.parse('https://accounts.google.com/.well-known/openid-configuration');
  final googleConfigResp = await http.get(googleUri);
  final parsedJson = jsonDecode(googleConfigResp.body) as Map<String, dynamic>;
  final parsedMetadata = OidcProviderMetadata.fromJson(parsedJson);
  print(parsedMetadata);
}
