import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
part 'source.g.dart';

final class OidcClaimSource extends JsonBasedResponse {
  const OidcClaimSource({
    required super.src,
  });

  factory OidcClaimSource.fromJson(Map<String, dynamic> json) {
    final jwt = json[OidcConstants_JWTClaims.jwt];
    if (jwt != null) {
      return OidcAggregatedClaimSource.fromJson(json);
    }
    final endpoint = json[OidcConstants_JWTClaims.endpoint];
    if (endpoint != null) {
      return OidcDistributedClaimSource.fromJson(json);
    }
    throw ArgumentError.value(json, 'json', 'unknown claim source');
  }
}

@JsonSerializable(
  constructor: '_',
  createFactory: true,
  createToJson: false,
)
final class OidcAggregatedClaimSource extends OidcClaimSource {
  const OidcAggregatedClaimSource._({
    required super.src,
    required this.jwt,
  });

  factory OidcAggregatedClaimSource.fromJson(Map<String, dynamic> json) {
    return _$OidcAggregatedClaimSourceFromJson(json);
  }

  @JsonKey(name: 'JWT')
  final String jwt;
}

@JsonSerializable(
  constructor: '_',
  createFactory: true,
  createToJson: false,
)
final class OidcDistributedClaimSource extends OidcClaimSource {
  const OidcDistributedClaimSource._({
    required super.src,
    required this.endpoint,
    this.accessToken,
  });

  factory OidcDistributedClaimSource.fromJson(Map<String, dynamic> json) {
    return _$OidcDistributedClaimSourceFromJson(json);
  }

  @JsonKey(name: OidcConstants_JWTClaims.endpoint)
  final Uri endpoint;
  @JsonKey(name: OidcConstants_AuthParameters.accessToken)
  final String? accessToken;
}
