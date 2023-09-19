import 'package:json_annotation/json_annotation.dart';

///
class OidcNumericDateConverter extends JsonConverter<DateTime, int> {
  ///
  const OidcNumericDateConverter();

  @override
  DateTime fromJson(int json) {
    return DateTime.fromMillisecondsSinceEpoch(
      json * 1000,
      isUtc: true,
    );
  }

  @override
  int toJson(DateTime object) {
    return (object.millisecondsSinceEpoch / 1000).ceil();
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
