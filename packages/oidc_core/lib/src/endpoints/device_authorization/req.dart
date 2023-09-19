import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:oidc_core/src/models/json_based_object.dart';

part 'req.g.dart';

/// A class that describes an /authorize request.
///
/// Note: this class does NO special logic.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcDeviceAuthorizationRequest extends JsonBasedRequest {
  /// Create an OidcAuthorizeRequest.
  OidcDeviceAuthorizationRequest({
    this.scope = const [],
    super.extra,
  });

  /// REQUIRED.
  ///
  /// OpenID Connect requests MUST contain the openid scope value.
  ///
  /// If the "openid" scope value is not present,
  /// the behavior is entirely unspecified.
  ///
  /// Other scope values MAY be present.
  ///
  /// Scope values used that are not understood by an implementation
  /// SHOULD be ignored.
  ///
  /// See Sections [5.4](https://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims) and [11](https://openid.net/specs/openid-connect-core-1_0.html#OfflineAccess) for additional scope values defined
  /// by this specification.
  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String> scope;

  /// converts the request into a JSON Map.
  @override
  Map<String, dynamic> toMap() => {
        ..._$OidcDeviceAuthorizationRequestToJson(this),
        ...super.toMap(),
      };
}
