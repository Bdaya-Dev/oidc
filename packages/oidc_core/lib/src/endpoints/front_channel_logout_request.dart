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

  /// OPTIONAL.
  ///
  /// Session ID - String identifier for a Session.
  ///
  /// This represents a Session of a User Agent or device for a logged-in
  /// End-User at an RP.
  ///
  /// Different sid values are used to identify distinct sessions at an OP.
  ///
  /// The sid value need only be unique in the context of a particular issuer.
  ///
  /// Its contents are opaque to the RP.
  ///
  /// Its syntax is the same as an OAuth 2.0 Client Identifier.
  @JsonKey(name: OidcConstants_JWTClaims.sid)
  final String? sid;
}
