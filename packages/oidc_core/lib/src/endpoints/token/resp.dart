import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/helpers/converters.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'resp.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: commonConverters,
)
class OidcTokenResponse extends JsonBasedResponse {
  const OidcTokenResponse({
    required super.src,
    required this.accessToken,
    required this.tokenType,
    this.scope = const [],
    this.idToken,
    this.refreshToken,
    this.expiresIn,
    this.expiresAt,
  });

  factory OidcTokenResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcTokenResponseFromJson(src);

  @JsonKey(name: 'scope', fromJson: splitSpaceDelimitedString)
  final List<String> scope;

  /// REQUIRED.
  ///
  /// The access token issued by the authorization server.
  @JsonKey(name: 'access_token')
  final String accessToken;

  /// REQUIRED.
  ///
  /// The type of the access token issued.
  ///
  /// Value is case insensitive.
  @JsonKey(name: 'token_type')
  final String tokenType;

  /// REQUIRED, in the OIDC spec.
  ///
  /// ID Token value associated with the authenticated session.
  @JsonKey(name: 'id_token')
  final String? idToken;

  bool get isOidc => idToken?.isNotEmpty ?? false;

  /// RECOMMENDED.
  ///
  /// The lifetime in seconds of the access token.
  ///
  /// For example, the value 3600 denotes that the access token will expire in
  /// one hour from the time the response was generated.
  ///
  /// If omitted, the authorization server SHOULD provide the expiration time
  /// via other means or document the default value.
  @JsonKey(name: 'expires_in')
  final Duration? expiresIn;

  /// OPTIONAL.
  ///
  /// The refresh token, which can be used to obtain new access tokens based on
  /// the grant passed in the corresponding token request.
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;

  /// NOT WITHIN SPEC, but some Identity Providers include this.
  @JsonKey(name: 'expires_at', readValue: readDateTime)
  final DateTime? expiresAt;
}
