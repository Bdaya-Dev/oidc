import 'package:json_annotation/json_annotation.dart';

import 'client_auth.dart';

part 'exchange.g.dart';

abstract class OidcExchangeRequest {}

@JsonSerializable(
  createFactory: false,
)
class OidcExchangeCodeRequest {
  @JsonKey(includeToJson: false)
  final OidcClientAuthentication? clientAuth;
  @JsonKey(name: 'redirect_uri')
  final Uri? redirectUri;
  @JsonKey(name: 'grant_type')
  final String grantType;
  @JsonKey(name: 'code')
  final String code;
  @JsonKey(name: 'code_verifier')
  final String? codeVerifier;

  const OidcExchangeCodeRequest({
    required this.code,
    required this.grantType,
    this.clientAuth,
    this.redirectUri,
    this.codeVerifier,
  });

  Map<String, dynamic> toJson({bool includeClientAuth = true}) => {
        ..._$OidcExchangeCodeRequestToJson(this),
        if (includeClientAuth) ...?clientAuth?.getBodyParameters(),
      };
}

@JsonSerializable(
  createFactory: false,
)
class OidcExchangeCredentialsRequest {
  /*  client_id?: string;
    client_secret?: string;

    grant_type?: string;
    scope?: string;

    username: string;
    password: string; */
  Map<String, dynamic> toJson() => _$OidcExchangeCredentialsRequestToJson(this);
}

@JsonSerializable(
  createFactory: false,
)
class OidcExchangeRefreshTokenRequest {
  /* client_id?: string;
    client_secret?: string;

    grant_type?: string;
    refresh_token: string;
    scope?: string;
    resource?: string | string[];

    timeoutInSeconds?: number; */
  Map<String, dynamic> toJson() =>
      _$OidcExchangeRefreshTokenRequestToJson(this);
}

@JsonSerializable(
  createFactory: false,
)
class OidcRevokeTokenRequest {
  /* token: string;
    token_type_hint?: "access_token" | "refresh_token"; */
  Map<String, dynamic> toJson() => _$OidcRevokeTokenRequestToJson(this);
}
