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
  converters: commonConverters,
)
class OidcTokenRequest extends JsonBasedRequest {
  const OidcTokenRequest({
    required this.grantType,
    this.clientId,
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
    this.redirectUri,
    this.refreshToken,
    this.scope = const [],
    super.extra,
  });

  const OidcTokenRequest.authorizationCode({
    required Uri this.redirectUri,
    required String this.code,
    this.clientId,
    this.scope = const [],
    this.codeVerifier,
    super.extra,
  })  : grantType = OidcConstants_GrantType.authorizationCode,
        username = null,
        password = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null;

  const OidcTokenRequest.password({
    required String this.username,
    required String this.password,
    required this.scope,
    this.clientId,
    super.extra,
  })  : grantType = OidcConstants_GrantType.password,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null;

  const OidcTokenRequest.clientCredentials({
    this.scope = const [],
    this.clientId,
    super.extra,
  })  : grantType = OidcConstants_GrantType.clientCredentials,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        assertion = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null,
        username = null,
        password = null;

  const OidcTokenRequest.saml2({
    required String this.assertion,
    this.scope = const [],
    this.clientId,
    super.extra,
  })  : grantType = OidcConstants_GrantType.saml2Bearer,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null,
        username = null,
        password = null;

  @JsonKey(name: OidcConstants_AuthParameters.grantType)
  final String grantType;
  @JsonKey(name: OidcConstants_AuthParameters.code)
  final String? code;

  /// REQUIRED if client secret (or any other Client Authentication mechanism)
  /// is not available.
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String? clientId;

  /// REQUIRED, if using PKCE.
  ///
  /// Code verifier.
  @JsonKey(name: OidcConstants_AuthParameters.codeVerifier)
  final String? codeVerifier;

  @JsonKey(name: OidcConstants_AuthParameters.username)
  final String? username;
  @JsonKey(name: OidcConstants_AuthParameters.password)
  final String? password;
  @JsonKey(name: OidcConstants_AuthParameters.assertion)
  final String? assertion;

  @JsonKey(name: OidcConstants_AuthParameters.audience)
  final String? audience;
  @JsonKey(name: OidcConstants_AuthParameters.subjectTokenType)
  final String? subjectTokenType;
  @JsonKey(name: OidcConstants_AuthParameters.subjectToken)
  final String? subjectToken;
  @JsonKey(name: OidcConstants_AuthParameters.actorTokenType)
  final String? actorTokenType;
  @JsonKey(name: OidcConstants_AuthParameters.actorToken)
  final String? actorToken;

  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  final Uri? redirectUri;
  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  final String? refreshToken;
  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: joinSpaceDelimitedList,
  )
  final List<String> scope;

  @override
  Map<String, dynamic> toMap() {
    return {
      ..._$OidcTokenRequestToJson(this),
      ...super.toMap(),
    };
  }
}
