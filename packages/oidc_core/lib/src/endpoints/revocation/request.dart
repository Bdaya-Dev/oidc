import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'request.g.dart';

@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcRevocationRequest extends JsonBasedRequest {
  OidcRevocationRequest({
    required this.token,
    this.tokenTypeHint,
    this.clientId,
    this.clientSecret,
    super.extra,
  });

  @JsonKey(name: OidcConstants_RevocationParameters.token)
  String token;

  @JsonKey(name: OidcConstants_RevocationParameters.tokenTypeHint)
  String? tokenTypeHint;

  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  String? clientId;

  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  String? clientSecret;

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    ..._$OidcRevocationRequestToJson(this),
  };
}
