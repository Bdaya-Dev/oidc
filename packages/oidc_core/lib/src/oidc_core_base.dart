import 'dart:convert';

import 'package:http/http.dart' as http;
import 'models/metadata.dart';

class OidcUtils {
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
