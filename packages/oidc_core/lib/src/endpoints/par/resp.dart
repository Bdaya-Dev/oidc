import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
part 'resp.g.dart';

/// The response of a Pushed Authorization Request (PAR).
///
/// See https://datatracker.ietf.org/doc/html/rfc9126#section-2.2
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
  constructor: '_',
)
class OidcPushedAuthorizationResponse extends JsonBasedResponse {
  ///
  const OidcPushedAuthorizationResponse._({
    required super.src,
    required this.requestUri,
    required this.expiresIn,
  });

  ///
  factory OidcPushedAuthorizationResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcPushedAuthorizationResponseFromJson(src);

  /// The request URI corresponding to the authorization request posted. This
  /// URI is a single-use reference to the respective request data at the
  /// subsequent authorization request.
  @JsonKey(name: OidcConstants_AuthParameters.requestUri)
  final Uri requestUri;

  /// The lifetime of the [requestUri]; it expires after this duration.
  @JsonKey(name: OidcConstants_AuthParameters.expiresIn)
  final Duration expiresIn;
}
