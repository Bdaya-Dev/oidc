import 'package:json_annotation/json_annotation.dart';

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
