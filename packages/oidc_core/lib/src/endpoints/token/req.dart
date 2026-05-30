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
    this.resource,
    this.requestedTokenType,
    super.extra,
  });

  /// Token Exchange (RFC 8693): exchanges a [subjectToken] (and optionally an
  /// [actorToken] for delegation) for a new token, optionally narrowed to an
  /// [audience] and/or [resource]s.
  OidcTokenRequest.tokenExchange({
    required String this.subjectToken,
    required String this.subjectTokenType,
    this.actorToken,
    this.actorTokenType,
    this.audience,
    this.resource,
    this.requestedTokenType,
    this.scope,
    this.clientId,
    this.clientSecret,
    super.extra,
  }) : grantType = OidcConstants_GrantType.tokenExchange,
       code = null,
       codeVerifier = null,
       redirectUri = null,
       assertion = null,
       deviceCode = null,
       refreshToken = null,
       username = null,
       password = null;

  OidcTokenRequest.authorizationCode({
    required String this.code,
    this.redirectUri,
    this.clientId,
    this.clientSecret,
    this.codeVerifier,
    this.resource,
    super.extra,
  }) : grantType = OidcConstants_GrantType.authorizationCode,
       username = null,
       password = null,
       assertion = null,
       deviceCode = null,
       audience = null,
       subjectTokenType = null,
       subjectToken = null,
       actorTokenType = null,
       actorToken = null,
       refreshToken = null,
       scope = null;

  OidcTokenRequest.refreshToken({
    required String this.refreshToken,
    this.clientId,
    this.clientSecret,
    this.scope,
    this.resource,
    super.extra,
  }) : grantType = OidcConstants_GrantType.refreshToken,
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
  }) : grantType = OidcConstants_GrantType.password,
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
  }) : grantType = OidcConstants_GrantType.clientCredentials,
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
  }) : grantType = OidcConstants_GrantType.saml2Bearer,
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
  }) : grantType = OidcConstants_GrantType.deviceCode,
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
  String grantType;

  /// REQUIRED, if using the Authorization Code Flow.
  ///
  /// This is the code you received from the /authorize response
  @JsonKey(name: OidcConstants_AuthParameters.code)
  String? code;

  /// REQUIRED if client secret (or any other Client Authentication mechanism)
  /// is not available.
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  String? clientId;

  /// REQUIRED if client secret (or any other Client Authentication mechanism)
  /// is not available.
  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  String? clientSecret;

  /// REQUIRED, if using PKCE.
  ///
  /// Code verifier.
  @JsonKey(name: OidcConstants_AuthParameters.codeVerifier)
  String? codeVerifier;

  @JsonKey(name: OidcConstants_AuthParameters.username)
  String? username;
  @JsonKey(name: OidcConstants_AuthParameters.password)
  String? password;
  @JsonKey(name: OidcConstants_AuthParameters.assertion)
  String? assertion;

  @JsonKey(name: OidcConstants_AuthParameters.audience)
  String? audience;
  @JsonKey(name: OidcConstants_AuthParameters.subjectTokenType)
  String? subjectTokenType;
  @JsonKey(name: OidcConstants_AuthParameters.subjectToken)
  String? subjectToken;
  @JsonKey(name: OidcConstants_AuthParameters.actorTokenType)
  String? actorTokenType;
  @JsonKey(name: OidcConstants_AuthParameters.actorToken)
  String? actorToken;

  @JsonKey(name: OidcConstants_AuthParameters.deviceCode)
  String? deviceCode;

  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  Uri? redirectUri;

  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  String? refreshToken;

  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String>? scope;

  /// RFC 8707 Resource Indicators: the target resource(s)/service(s) at which
  /// the requested token will be used. Serialized as one repeated `resource`
  /// parameter per value.
  @JsonKey(name: OidcConstants_AuthParameters.resource)
  List<Uri>? resource;

  /// RFC 8693 Token Exchange: an identifier for the type of the requested
  /// security token (e.g. [OidcConstants_TokenExchange_TokenType.accessToken]).
  @JsonKey(name: OidcConstants_AuthParameters.requestedTokenType)
  String? requestedTokenType;

  @override
  Map<String, dynamic> toMap() {
    return {
      ..._$OidcTokenRequestToJson(this),
      ...super.toMap(),
    };
  }
}
