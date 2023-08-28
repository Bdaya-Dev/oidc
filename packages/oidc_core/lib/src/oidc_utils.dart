import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/resp/metadata.dart';

class OidcUtils {
  static Uri getWellKnownUriFromBase(Uri base) {
    return base.replace(pathSegments: [
      ...base.pathSegments,
      '.well-known',
      'openid-configuration',
    ]);
  }

  /// Gets the Oidc provider metadata from a '.well-known' url
  static Future<OidcProviderMetadata> getConfiguration(
    Uri wellKnownUri, {
    Map<String, String>? headers,
  }) async {
    final resp = await http.get(
      wellKnownUri,
      headers: headers,
    );
    final decoded = jsonDecode(resp.body);
    return OidcProviderMetadata.fromJson(decoded);
  }
}
