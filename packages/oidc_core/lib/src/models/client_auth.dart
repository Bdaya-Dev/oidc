import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
part 'client_auth.g.dart';

final _utf8ThenBase64 = utf8.fuse(base64);

@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
)
class OidcClientAuthentication {
  const OidcClientAuthentication.none({
    required this.clientId,
  })  : location = OidcConstants_ClientAuthenticationMethods.none,
        clientSecret = null,
        clientAssertion = null,
        clientAssertionType = null;

  const OidcClientAuthentication.clientSecretBasic({
    required this.clientId,
    required String this.clientSecret,
  })  : location = OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
        clientAssertionType = null,
        clientAssertion = null;

  const OidcClientAuthentication.clientSecretPost({
    required this.clientId,
    required String this.clientSecret,
  })  : location = OidcConstants_ClientAuthenticationMethods.clientSecretPost,
        clientAssertionType = null,
        clientAssertion = null;

  const OidcClientAuthentication.clientSecretJwt({
    required this.clientId,
    required String this.clientAssertion,
  })  : location = OidcConstants_ClientAuthenticationMethods.clientSecretJwt,
        clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
        clientSecret = null;

  const OidcClientAuthentication.privateKeyJwt({
    required this.clientId,
    required String this.clientAssertion,
  })  : location = OidcConstants_ClientAuthenticationMethods.privateKeyJwt,
        clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
        clientSecret = null;

  @JsonKey(includeToJson: false)
  final String location;
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String clientId;
  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  final String? clientSecret;
  @JsonKey(name: OidcConstants_AuthParameters.clientAssertionType)
  final String? clientAssertionType;
  @JsonKey(name: OidcConstants_AuthParameters.clientAssertion)
  final String? clientAssertion;

  String? getAuthorizationHeader() {
    if (location !=
        OidcConstants_ClientAuthenticationMethods.clientSecretBasic) {
      return null;
    }
    if (clientSecret == null) {
      return null;
    }
    final concat = '$clientId:$clientSecret';
    return 'Basic ${_utf8ThenBase64.encode(concat)}';
  }

  Map<String, String> getBodyParameters() =>
      _$OidcClientAuthenticationToJson(this).cast<String, String>();
}
