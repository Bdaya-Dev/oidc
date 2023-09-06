import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/converters.dart';

@internal
class OidcInternalUtilities {
  static Future<http.Response> sendWithClient({
    required http.Client? client,
    required http.Request request,
  }) async {
    //
    final shouldDispose = client == null;
    client ??= http.Client();
    try {
      final res = await client.send(request).then(http.Response.fromStream);
      return res;
    } finally {
      if (shouldDispose) {
        client.close();
      }
    }
  }

  /// Converts a list of strings into a space-delimited string
  static String? joinSpaceDelimitedList(List<String>? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.join(' ');
  }

  static List<String> splitSpaceDelimitedString(String? value) {
    if (value == null || value.isEmpty) {
      return [];
    }
    return value.split(' ');
  }

  static DateTime? readDateTime(Map<dynamic, dynamic> src, String key) {
    final rawValue = src[key];
    if (rawValue == null) {
      return null;
    }
    if (rawValue is String) {
      return DateTime.tryParse(rawValue);
    } else if (rawValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        rawValue,
        isUtc: true,
      );
    } else if (rawValue is DateTime) {
      return rawValue;
    }
    throw ArgumentError.value(rawValue, "Value can't be converted to DateTime");
  }

  static const commonConverters = <JsonConverter<dynamic, dynamic>>[
    OidcDateTimeEpochConverter(),
    OidcDurationSecondsConverter()
  ];
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
  static Future<OidcProviderMetadata> getProviderMetadata(
    Uri wellKnownUri, {
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final req = http.Request(OidcConstants_RequestMethod.get, wellKnownUri);
    if (headers != null) {
      req.headers.addAll(headers);
    }
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    if (resp.statusCode != 200) {
      throw OidcException(
        'Server responded with a non-200 statusCode',
        extra: {
          OidcConstants_Exception.request: req,
          OidcConstants_Exception.response: resp,
          OidcConstants_Exception.statusCode: resp.statusCode,
        },
      );
    }
    final decoded = jsonDecode(resp.body);
    return OidcProviderMetadata.fromJson(decoded as Map<String, dynamic>);
  }
}
