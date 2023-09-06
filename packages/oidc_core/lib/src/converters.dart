import 'package:json_annotation/json_annotation.dart';

///
class OidcUriJsonConverter extends JsonConverter<Uri, String> {
  /// Creates a UriJsonConverter
  const OidcUriJsonConverter();

  @override
  Uri fromJson(String json) {
    return Uri.parse(json);
  }

  @override
  String toJson(Uri object) {
    return object.toString();
  }
}

///
class OidcDateTimeEpochConverter extends JsonConverter<DateTime, int> {
  ///
  const OidcDateTimeEpochConverter();

  @override
  DateTime fromJson(int json) {
    return DateTime.fromMillisecondsSinceEpoch(
      json,
      isUtc: true,
    );
  }

  @override
  int toJson(DateTime object) {
    return object.millisecondsSinceEpoch;
  }
}

///
class OidcDurationSecondsConverter extends JsonConverter<Duration, int> {
  ///
  const OidcDurationSecondsConverter();

  @override
  Duration fromJson(int json) {
    return Duration(seconds: json);
  }

  @override
  int toJson(Duration object) {
    return object.inSeconds;
  }
}
