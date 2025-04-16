import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
part 'req.g.dart';

/// See https://developer.okta.com/docs/reference/api/oidc/
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcTokenRequest extends JsonBasedRequest {
  OidcTokenRequest({
    required this.grantType,
    this.clientId,
    this.clientSecret,
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
    this.scope,
    this.deviceCode,
    super.extra,
  });

  OidcTokenRequest.authorizationCode({
    required String this.code,
    required this.scope,
    this.redirectUri,
    this.clientId,
    this.clientSecret,
    this.codeVerifier,
    super.extra,
  })  : grantType = OidcConstants_GrantType.authorizationCode,
        username = null,
        password = null,
        assertion = null,
        deviceCode = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null;

  OidcTokenRequest.refreshToken({
    required String this.refreshToken,
    this.clientId,
    this.clientSecret,
    this.scope,
    super.extra,
  })  : grantType = OidcConstants_GrantType.refreshToken,
        codeVerifier = null,
        redirectUri = null,
        username = null,
        deviceCode = null,
        password = null,
        assertion = null,
        code = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null;

  OidcTokenRequest.password({
    required String this.username,
    required String this.password,
    required List<String> this.scope,
    this.clientId,
    this.clientSecret,
    super.extra,
  })  : grantType = OidcConstants_GrantType.password,
        code = null,
        codeVerifier = null,
        redirectUri = null,
        assertion = null,
        deviceCode = null,
        audience = null,
        subjectTokenType = null,
        subjectToken = null,
        actorTokenType = null,
        actorToken = null,
        refreshToken = null;

  OidcTokenRequest.clientCredentials({
    this.scope,
    this.clientId,
    this.clientSecret,
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
        deviceCode = null,
        password = null;

  OidcTokenRequest.saml2({
    required String this.assertion,
    this.scope,
    this.clientId,
    this.clientSecret,
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
        password = null,
        deviceCode = null;

  OidcTokenRequest.deviceCode({
    required String this.deviceCode,
    this.clientId,
    this.clientSecret,
    this.scope,
    super.extra,
  })  : grantType = OidcConstants_GrantType.deviceCode,
        code = null,
        assertion = null,
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

  /// REQUIRED, if using the Authorization Code Flow.
  ///
  /// This is the code you received from the /authorize response
  @JsonKey(name: OidcConstants_AuthParameters.code)
  final String? code;

  /// REQUIRED if client secret (or any other Client Authentication mechanism)
  /// is not available.
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String? clientId;

  /// REQUIRED if client secret (or any other Client Authentication mechanism)
  /// is not available.
  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  final String? clientSecret;

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

  @JsonKey(name: OidcConstants_AuthParameters.deviceCode)
  final String? deviceCode;

  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  final Uri? redirectUri;

  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  final String? refreshToken;

  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  final List<String>? scope;

  @override
  Map<String, dynamic> toMap() {
    return {
      ..._$OidcTokenRequestToJson(this),
      ...super.toMap(),
    };
  }
}
