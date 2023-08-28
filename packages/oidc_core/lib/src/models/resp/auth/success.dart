import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'success.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
)
class OidcSuccessAuthResponse extends OidcAuthResponseBase {
  static const kcode = 'code';
  static const kaccessToken = 'access_token';
  static const kidToken = 'id_token';

  @JsonKey(name: kcode)
  final String? code;
  @JsonKey(name: kaccessToken)
  final String? accessToken;
  @JsonKey(name: kidToken)
  final String? idToken;
  @JsonKey(name: 'token_type')
  final String? tokenType;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'scope')
  final String? scope;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @JsonKey(name: 'expires_in')
  final Duration? expiresIn;

  factory OidcSuccessAuthResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcSuccessAuthResponseFromJson(src);

  const OidcSuccessAuthResponse({
    this.code,
    super.sessionState,
    super.state,
    this.tokenType,
    this.refreshToken,
    this.scope,
    this.expiresAt,
    this.expiresIn,
    this.accessToken,
    this.idToken,
  });
}
