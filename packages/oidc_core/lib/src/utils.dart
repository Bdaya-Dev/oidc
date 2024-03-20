import 'dart:async';

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

  static Object? readDurationSeconds(Map<dynamic, dynamic> p1, String p2) {
    final res = p1[p2];
    if (res == null) {
      return null;
    }
    if (res is int) {
      return res;
    }
    return int.tryParse(res.toString());
  }

  static Duration? durationFromJson(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is int) {
      return Duration(seconds: json);
    }
    final seconds = int.tryParse(json.toString());
    if (seconds == null) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  static int? durationToJson(Duration? value) {
    return value?.inSeconds;
  }

  static List<String>? splitSpaceDelimitedStringNullable(Object? value) {
    if (value == null) {
      return null;
    }
    return splitSpaceDelimitedString(value);
  }

  static List<String> splitSpaceDelimitedString(Object? value) {
    if (value == null) {
      return [];
    }
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is String) {
      if (value.isEmpty) {
        return [];
      }
      return value.split(' ');
    }
    throw ArgumentError.value(
      value,
      'value',
      'parameter be null or List or String',
    );
  }

  static String? dateTimeToJson(DateTime? value) {
    if (value == null) {
      return null;
    }
    return value.toIso8601String();
  }

  static DateTime dateTimeFromJsonRequired(dynamic rawValue) {
    if (rawValue is String) {
      return DateTime.parse(rawValue);
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

  static DateTime? dateTimeFromJson(dynamic rawValue) {
    if (rawValue == null) {
      return null;
    }
    return dateTimeFromJsonRequired(rawValue);
  }

  static const commonConverters = <JsonConverter<dynamic, dynamic>>[
    OidcNumericDateConverter(),
    OidcDurationSecondsConverter(),
  ];

  static Map<String, Object> serializeQueryParameters(
      Map<String, Object?> input) {
    final result = <String, Object>{};
    for (final element in input.entries) {
      final k = element.key;
      final v = element.value;
      if (v == null) {
        continue;
      }
      if (v is Iterable) {
        result[k] = v.map((e) => e.toString()).toList();
      } else {
        result[k] = v.toString();
      }
    }
    return result;
  }
}

extension OidcDateTime on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
  static DateTime fromSecondsSinceEpoch(int seconds) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

/// Utilities for the Oidc spec
class OidcUtils {
  /// Takes a base Url and adds /.well-known/openid-configuration to it
  static Uri getOpenIdConfigWellKnownUri(Uri base) {
    return base.replace(
      pathSegments: [
        ...base.pathSegments,
        '.well-known',
        'openid-configuration',
      ],
    );
  }
}
