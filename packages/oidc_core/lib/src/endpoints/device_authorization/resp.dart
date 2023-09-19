import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
part 'resp.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
  constructor: '_',
)
class OidcDeviceAuthorizationResponse extends JsonBasedResponse {
  const OidcDeviceAuthorizationResponse._({
    required super.src,
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  ///
  factory OidcDeviceAuthorizationResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcDeviceAuthorizationResponseFromJson(src);

  @JsonKey(name: OidcConstants_AuthParameters.deviceCode)
  final String deviceCode;

  @JsonKey(name: OidcConstants_AuthParameters.userCode)
  final String userCode;

  @JsonKey(name: OidcConstants_AuthParameters.verificationUri)
  final Uri verificationUri;

  @JsonKey(name: OidcConstants_AuthParameters.verificationUriComplete)
  final Uri? verificationUriComplete;

  @JsonKey(name: OidcConstants_AuthParameters.expiresIn)
  final Duration expiresIn;

  @JsonKey(name: OidcConstants_AuthParameters.interval)
  final Duration? interval;
}
