import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'response.g.dart';

/// Response from a token revocation endpoint.
///
/// According to RFC 7009, a successful revocation response has no content
/// and returns HTTP status code 200.
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcRevocationResponse extends JsonBasedResponse {
  const OidcRevocationResponse({
    required super.src,
  });

  /// Factory constructor to create a [OidcRevocationResponse] from a JSON map.
  factory OidcRevocationResponse.fromJson(Map<String, dynamic> src) {
    return _$OidcRevocationResponseFromJson(src);
  }
}
