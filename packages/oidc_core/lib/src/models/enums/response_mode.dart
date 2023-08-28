import 'package:json_annotation/json_annotation.dart';

part 'response_mode.g.dart';

@JsonEnum(alwaysCreate: true)
enum OidcResponseMode {
  query,
  fragment,
}

extension OidcResponseModeExt on OidcResponseMode {
  String toJson() => _$OidcResponseModeEnumMap[this]!;
}
