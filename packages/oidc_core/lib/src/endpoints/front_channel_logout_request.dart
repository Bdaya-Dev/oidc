import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'front_channel_logout_request.g.dart';

@JsonSerializable(
  createToJson: false,
  createFactory: true,
  constructor: '_',
)
class OidcFrontChannelLogoutIncomingRequest extends JsonBasedResponse {
  const OidcFrontChannelLogoutIncomingRequest._({
    required super.src,
    this.iss,
    this.sid,
  });

  factory OidcFrontChannelLogoutIncomingRequest.fromJson(
    Map<String, dynamic> src,
  ) =>
      _$OidcFrontChannelLogoutIncomingRequestFromJson(src);

  @JsonKey(name: OidcConstants_AuthParameters.iss)
  final Uri? iss;

  @JsonKey(name: OidcConstants_JWTClaims.sid)
  final String? sid;
}
