import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

///
Map<dynamic, dynamic> readSrcMap(Map<dynamic, dynamic> src, String key) {
  return src;
}

abstract class JsonBasedRequest {
  const JsonBasedRequest({
    Map<String, dynamic>? extra,
  }) : extra = extra ?? const {};

  /// Extra parameters to add to the request.
  @JsonKey(
    includeToJson: false,
    includeFromJson: false,
  )
  final Map<String, dynamic> extra;

  void operator []=(String key, dynamic value) => extra[key] = value;

  @mustCallSuper
  @mustBeOverridden
  Map<String, dynamic> toMap() => {...extra};
}

/// A utility for holding an object that is generated from a json map.
abstract class JsonBasedResponse {
  ///
  const JsonBasedResponse({
    required this.src,
  });

  /// The source json object.
  @JsonKey(
    name: '',
    includeFromJson: true,
    includeToJson: false,
    readValue: readSrcMap,
  )
  final Map<String, dynamic> src;

  @override
  String toString() => src.toString();

  /// gets a value from the [src] json
  dynamic operator [](String key) => src[key];
}
