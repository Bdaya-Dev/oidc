import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'error.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
)
class OidcErrorAuthResponse extends OidcAuthResponseBase {
  static const kerror = 'error';

  @JsonKey(name: kerror)
  final String error;
  @JsonKey(name: 'error_description')
  final String? errorDescription;
  @JsonKey(name: 'error_uri')
  final String? errorUri;

  const OidcErrorAuthResponse({
    required this.error,
    this.errorDescription,
    this.errorUri,
    super.sessionState,
    super.state,
  });

  factory OidcErrorAuthResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcErrorAuthResponseFromJson(src);
}
