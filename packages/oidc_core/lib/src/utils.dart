import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

Future<http.Response> _sendWithClient({
  required http.Client? client,
  required Future<http.Response> Function(http.Client client) action,
}) async {
  //
  final shouldDispose = client == null;
  client ??= http.Client();
  try {
    return await action(client);
  } finally {
    if (shouldDispose) {
      client.close();
    }
  }
}

/// Utilities for the Oidc spec
class OidcUtils {
  /// Takes a base Url and adds /.well-known/openid-configuration to it
  static Uri getWellKnownUriFromBase(Uri base) {
    return base.replace(
      pathSegments: [
        ...base.pathSegments,
        '.well-known',
        'openid-configuration',
      ],
    );
  }

  /// Gets the Oidc provider metadata from a '.well-known' url
  static Future<OidcProviderMetadata> getConfiguration(
    Uri wellKnownUri, {
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final req = http.Request('GET', wellKnownUri);
    if (headers != null) {
      req.headers.addAll(headers);
    }
    final resp = await _sendWithClient(
      client: client,
      action: (client) => client.send(req).then(http.Response.fromStream),
    );
    if (resp.statusCode != 200) {
      throw OidcException(
        'Server responded with a non-200 statusCode',
        extra: {
          'statusCode': resp.statusCode,
        },
      );
    }
    final decoded = jsonDecode(resp.body);
    return OidcProviderMetadata.fromJson(decoded as Map<String, dynamic>);
  }
}
