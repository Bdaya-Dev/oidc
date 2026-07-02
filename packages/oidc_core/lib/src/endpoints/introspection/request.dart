import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'request.g.dart';

/// An OAuth 2.0 Token Introspection request (RFC 7662 §2.1).
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcIntrospectionRequest extends JsonBasedRequest {
  OidcIntrospectionRequest({
    required this.token,
    this.tokenTypeHint,
    this.clientId,
    this.clientSecret,
    super.extra,
  });

  /// REQUIRED. The string value of the token to introspect.
  @JsonKey(name: OidcConstants_RevocationParameters.token)
  String token;

  /// OPTIONAL. A hint about the type of the submitted token, e.g.
  /// `access_token` or `refresh_token`.
  @JsonKey(name: OidcConstants_RevocationParameters.tokenTypeHint)
  String? tokenTypeHint;

  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  String? clientId;

  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  String? clientSecret;

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    ..._$OidcIntrospectionRequestToJson(this),
  };
}
