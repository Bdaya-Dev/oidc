import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'response.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
  constructor: '_',
)
class OidcEndSessionResponse extends JsonBasedResponse {
  const OidcEndSessionResponse._({
    required super.src,
    this.state,
  });

  factory OidcEndSessionResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcEndSessionResponseFromJson(src);

  @JsonKey(name: OidcConstants_AuthParameters.state)
  final String? state;
}
