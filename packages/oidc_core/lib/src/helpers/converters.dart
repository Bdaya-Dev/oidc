import 'package:json_annotation/json_annotation.dart';

String? spaceDelimitedToJson(List<String> value) {
  if (value.isEmpty) {
    return null;
  }
  return value.join(' ');
}

class UriJsonConverter extends JsonConverter<Uri, String> {
  const UriJsonConverter();

  @override
  Uri fromJson(String json) {
    return Uri.parse(json);
  }

  @override
  String toJson(Uri object) {
    return object.toString();
  }
}

class DateTimeEpochConverter extends JsonConverter<DateTime, int> {
  const DateTimeEpochConverter();

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

class DurationSecondsConverter extends JsonConverter<Duration, int> {
  const DurationSecondsConverter();

  @override
  Duration fromJson(int json) {
    return Duration(seconds: json);
  }

  @override
  int toJson(Duration object) {
    return object.inSeconds;
  }
}
