import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/helpers/converters.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
part 'req.g.dart';

/// See https://developer.okta.com/docs/reference/api/oidc/
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: [
    UriJsonConverter(),
    DurationSecondsConverter(),
  ],
)
class OidcTokenRequestBody extends JsonBasedRequest {
  const OidcTokenRequestBody({
    required this.grantType,
    this.code,
    this.codeVerifier,
    this.username,
    this.password,
    this.assertion,
    this.audience,
    this.subjectTokenType,
    this.subjectToken,
    this.actorTokenType,
    this.actorToken,
    this.authReqId,
    this.redirectUri,
    this.refreshToken,
    this.scope = const [],
    super.extra,
  });

  const OidcTokenRequestBody.authorizationCode({
    required Uri this.redirectUri,
    this.scope = const [],
    this.code,
    this.codeVerifier,
    super.extra,
  })  : grantType = OidcTokenRequestConstants_GrantType.authorizationCode,
        username = null,
        password = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        authReqId = null,
        refreshToken = null;

  const OidcTokenRequestBody.password({
    required String this.username,
    required String this.password,
    required this.scope,
    super.extra,
  })  : grantType = OidcTokenRequestConstants_GrantType.password,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        authReqId = null,
        refreshToken = null;

  const OidcTokenRequestBody.clientCredentials({
    this.scope = const [],
    super.extra,
  })  : grantType = OidcTokenRequestConstants_GrantType.clientCredentials,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        authReqId = null,
        refreshToken = null,
        username = null,
        password = null;

  const OidcTokenRequestBody.saml2({
    required String this.assertion,
    this.scope = const [],
    super.extra,
  })  : grantType = OidcTokenRequestConstants_GrantType.saml2Bearer,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        authReqId = null,
        refreshToken = null,
        username = null,
        password = null;

  @JsonKey(name: 'grant_type')
  final String grantType;
  @JsonKey(name: 'code')
  final String? code;

  /// REQUIRED, if using PKCE.
  ///
  /// Code verifier.
  @JsonKey(name: 'code_verifier')
  final String? codeVerifier;

  @JsonKey(name: 'username')
  final String? username;
  @JsonKey(name: 'password')
  final String? password;
  @JsonKey(name: 'assertion')
  final String? assertion;

  @JsonKey(name: 'audience')
  final String? audience;
  @JsonKey(name: 'subject_token_type')
  final String? subjectTokenType;
  @JsonKey(name: 'subject_token')
  final String? subjectToken;
  @JsonKey(name: 'actor_token_type')
  final String? actorTokenType;
  @JsonKey(name: 'actor_token')
  final String? actorToken;
  @JsonKey(name: 'auth_req_id')
  final String? authReqId;

  @JsonKey(name: 'redirect_uri')
  final Uri? redirectUri;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'scope', toJson: joinSpaceDelimitedList)
  final List<String> scope;
  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
    };
  }
}
