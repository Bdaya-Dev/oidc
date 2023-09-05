// NOTICE: This file was mostly copied and edited from:
// https://github.com/appsup-dart/openid_client/blob/92a9a055c62c3b302d70a401ef872b5b9dba6f21/lib/src/model/metadata.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/helpers/converters.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'resp.g.dart';

/// The "OpenID Provider Metadata" as standaraized by the spec https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata
/// This also includes some metadata that are defined by other extensions
@JsonSerializable(
  createToJson: false,
  converters: commonConverters,
)
class OidcProviderMetadata extends JsonBasedResponse {
  const OidcProviderMetadata({
    required super.src,
    this.issuer,
    this.authorizationEndpoint,
    this.jwksUri,
    this.responseTypesSupported,
    this.subjectTypesSupported,
    this.idTokenSigningAlgValuesSupported,
    this.tokenEndpoint,
    this.userinfoEndpoint,
    this.registrationEndpoint,
    this.scopesSupported,
    this.responseModesSupported,
    this.grantTypesSupported,
    this.acrValuesSupported,
    this.idTokenEncryptionAlgValuesSupported,
    this.requestObjectSigningAlgValuesSupported,
    this.requestObjectEncryptionAlgValuesSupported,
    this.requestObjectEncryptionEncValuesSupported,
    this.tokenEndpointAuthSigningAlgValuesSupported,
    this.tokenEndpointAuthMethodsSupported,
    this.displayValuesSupported,
    this.claimTypesSupported,
    this.claimsSupported,
    this.serviceDocumentation,
    this.claimsLocalesSupported,
    this.uiLocalesSupported,
    this.pushedAuthorizationRequestEndpoint,
    this.claimsParameterSupported,
    this.requestParameterSupported,
    this.requireRequestUriRegistration,
    this.requestUriParameterSupported,
    this.requirePushedAuthorizationRequests,
    this.opPolicyUri,
    this.opTosUri,
    this.checkSessionIframe,
    this.endSessionEndpoint,
    this.revocationEndpoint,
    this.revocationEndpointAuthMethodsSupported,
    this.revocationEndpointAuthSigningAlgValuesSupported,
    this.introspectionEndpoint,
    this.introspectionEndpointAuthMethodsSupported,
    this.introspectionEndpointAuthSigningAlgValuesSupported,
    this.codeChallengeMethodsSupported,
    this.idTokenEncryptionEncValuesSupported,
    this.userinfoSigningAlgValuesSupported,
    this.userinfoEncryptionAlgValuesSupported,
    this.userinfoEncryptionEncValuesSupported,
  });

  ///
  factory OidcProviderMetadata.fromJson(Map<String, dynamic> json) =>
      _$OidcProviderMetadataFromJson(json);

  /// URL that the OP asserts as its OpenIdProviderMetadata Identifier.
  @JsonKey(name: 'issuer')
  final Uri? issuer;

  /// URL of the OP's OAuth 2.0 Authorization Endpoint.
  @JsonKey(name: 'authorization_endpoint')
  final Uri? authorizationEndpoint;

  /// URL of the OP's OAuth 2.0 Token Endpoint.
  @JsonKey(name: 'token_endpoint')
  final Uri? tokenEndpoint;

  /// URL of the OP's UserInfo Endpoint.
  @JsonKey(name: 'userinfo_endpoint')
  final Uri? userinfoEndpoint;

  /// URL of the OP's JSON Web Key Set document.
  ///
  /// This contains the signing key(s) the RP uses to validate signatures
  /// from the OP.
  @JsonKey(name: 'jwks_uri')
  final Uri? jwksUri;

  /// URL of the OP's Dynamic Client Registration Endpoint.
  @JsonKey(name: 'registration_endpoint')
  final Uri? registrationEndpoint;

  /// A list of the OAuth 2.0 scope values that this server supports.
  @JsonKey(name: 'scopes_supported')
  final List<String>? scopesSupported;

  /// A list of the OAuth 2.0 `response_type` values that this OP supports.
  @JsonKey(name: 'response_types_supported')
  final List<String>? responseTypesSupported;

  /// A list of the OAuth 2.0 `response_mode` values that this OP supports.
  @JsonKey(
    name: 'response_modes_supported',
  )
  final List<String>? responseModesSupported;

  /// A list of the OAuth 2.0 Grant Type values that this OP supports.
  @JsonKey(
    name: 'grant_types_supported',
  )
  final List<String>? grantTypesSupported;
  List<String> get grantTypesSupportedOrDefault =>
      grantTypesSupported ??
      [
        OidcConstants_GrantType.authorizationCode,
        OidcDiscoveryConstants_GrantTypes.implicit,
      ];

  /// A list of the Authentication Context Class References that this
  /// OP supports.
  @JsonKey(name: 'acr_values_supported')
  final List<String>? acrValuesSupported;

  /// A list of the Subject Identifier types that this OP supports.
  ///
  /// Valid types include `pairwise` and `public`.
  @JsonKey(name: 'subject_types_supported')
  final List<String>? subjectTypesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  ///
  /// The algorithm `RS256` MUST be included. The value `none` MAY be supported,
  /// but MUST NOT be used unless the Response Type used returns no ID Token
  /// from the Authorization Endpoint (such as when using the Authorization Code
  /// Flow).
  @JsonKey(name: 'id_token_signing_alg_values_supported')
  final List<String>? idTokenSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  @JsonKey(name: 'id_token_encryption_alg_values_supported')
  final List<String>? idTokenEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  @JsonKey(name: 'id_token_encryption_enc_values_supported')
  final List<String>? idTokenEncryptionEncValuesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the

  /// UserInfo Endpoint to encode the Claims in a JWT.
  @JsonKey(name: 'userinfo_signing_alg_values_supported')
  final List<String>? userinfoSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the
  /// UserInfo Endpoint to encode the Claims in a JWT.

  @JsonKey(name: 'userinfo_encryption_alg_values_supported')
  final List<String>? userinfoEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the
  /// UserInfo Endpoint to encode the Claims in a JWT.

  @JsonKey(name: 'userinfo_encryption_enc_values_supported')
  final List<String>? userinfoEncryptionEncValuesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// (using the request parameter) and when it is passed by reference (using
  /// the request_uri parameter).
  @JsonKey(name: 'request_object_signing_alg_values_supported')
  final List<String>? requestObjectSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// and when it is passed by reference.
  @JsonKey(name: 'request_object_encryption_alg_values_supported')
  final List<String>? requestObjectEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// and when it is passed by reference.
  @JsonKey(name: 'request_object_encryption_enc_values_supported')
  final List<String>? requestObjectEncryptionEncValuesSupported;

  /// A list of Client Authentication methods supported by this Token Endpoint.
  ///
  /// The options are `client_secret_post`, `client_secret_basic`,
  /// `client_secret_jwt`, and `private_key_jwt`. Other authentication methods
  /// MAY be defined by extensions.
  @JsonKey(name: 'token_endpoint_auth_methods_supported')
  final List<String>? tokenEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the Token
  /// Endpoint for the signature on the JWT used to authenticate the Client at
  /// the Token Endpoint for the `private_key_jwt` and `client_secret_jwt`
  /// authentication methods.
  @JsonKey(name: 'token_endpoint_auth_signing_alg_values_supported')
  final List<String>? tokenEndpointAuthSigningAlgValuesSupported;

  /// A list of the display parameter values that the OpenID Provider supports.
  @JsonKey(name: 'display_values_supported')
  final List<String>? displayValuesSupported;

  /// A list of the Claim Types that the OpenID Provider supports.
  ///
  /// Values defined by the specification are `normal`, `aggregated`, and
  /// `distributed`. If omitted, the implementation supports only `normal`
  /// Claims.
  @JsonKey(name: 'claim_types_supported')
  final List<String>? claimTypesSupported;

  /// A list of the Claim Names of the Claims that the OpenID Provider MAY be
  /// able to supply values for.
  ///
  /// Note that for privacy or other reasons, this might not be an exhaustive
  /// list.
  @JsonKey(name: 'claims_supported')
  final List<String>? claimsSupported;

  /// URL of a page containing human-readable information that developers might
  /// want or need to know when using the OpenID Provider.
  @JsonKey(name: 'service_documentation')
  final Uri? serviceDocumentation;

  /// Languages and scripts supported for values in Claims being returned.
  ///
  /// Not all languages and scripts are necessarily supported for all Claim
  /// values.
  @JsonKey(name: 'claims_locales_supported')
  final List<String>? claimsLocalesSupported;

  /// Languages and scripts supported for the user interface.
  @JsonKey(name: 'ui_locales_supported')
  final List<String>? uiLocalesSupported;

  /// `true` when the OP supports use of the `claims` parameter.
  @JsonKey(name: 'claims_parameter_supported')
  final bool? claimsParameterSupported;
  bool get claimsParameterSupportedOrDefault =>
      claimsParameterSupported ?? false;

  /// `true` when the OP supports use of the `request` parameter.
  @JsonKey(name: 'request_parameter_supported')
  final bool? requestParameterSupported;

  /// `true` when the OP supports use of the `request_uri` parameter.
  @JsonKey(name: 'request_uri_parameter_supported')
  final bool? requestUriParameterSupported;
  bool get requestUriParameterSupportedOrDefault =>
      requestUriParameterSupported ?? true;

  /// `true` when the OP requires any `request_uri` values used to be
  /// pre-registered using the request_uris registration parameter.
  @JsonKey(name: 'require_request_uri_registration')
  final bool? requireRequestUriRegistration;

  /// URL that the OpenID Provider provides to the person registering the Client
  /// to read about the OP's requirements on how the Relying Party can use the
  /// data provided by the OP.
  @JsonKey(name: 'op_policy_uri')
  final Uri? opPolicyUri;

  /// URL that the OpenID Provider provides to the person registering the Client
  /// to read about OpenID Provider's terms of service.
  @JsonKey(name: 'op_tos_uri')
  final Uri? opTosUri;

  /// URL of an OP iframe that supports cross-origin communications for session
  /// state information with the RP Client, using the HTML5 postMessage API.
  ///
  /// The page is loaded from an invisible iframe embedded in an RP page so that
  /// it can run in the OP's security context. It accepts postMessage requests
  /// from the relevant RP iframe and uses postMessage to post back the login
  /// status of the End-User at the OP.
  @JsonKey(name: 'check_session_iframe')
  final Uri? checkSessionIframe;

  /// URL at the OP to which an RP can perform a redirect to request that the
  /// End-User be logged out at the OP.
  @JsonKey(name: 'end_session_endpoint')
  final Uri? endSessionEndpoint;

  /// URL of the authorization server's OAuth 2.0 revocation endpoint.
  @JsonKey(name: 'revocation_endpoint')
  final Uri? revocationEndpoint;

  /// A list of client authentication methods supported by this revocation
  /// endpoint.
  @JsonKey(name: 'revocation_endpoint_auth_methods_supported')
  final List<String>? revocationEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the
  /// revocation endpoint for the signature on the JWT used to authenticate the
  /// client at the revocation endpoint for the `private_key_jwt` and
  /// `client_secret_jwt` authentication methods.
  @JsonKey(name: 'revocation_endpoint_auth_signing_alg_values_supported')
  final List<String>? revocationEndpointAuthSigningAlgValuesSupported;

  /// URL of the authorization server's OAuth 2.0 introspection endpoint.
  @JsonKey(name: 'introspection_endpoint')
  final Uri? introspectionEndpoint;

  /// A list of client authentication methods supported by this introspection
  /// endpoint.
  @JsonKey(name: 'introspection_endpoint_auth_methods_supported')
  final List<String>? introspectionEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the
  /// introspection endpoint for the signature on the JWT used to authenticate
  /// the client at the introspection endpoint for the `private_key_jwt` and
  /// `client_secret_jwt` authentication methods.
  @JsonKey(name: 'introspection_endpoint_auth_signing_alg_values_supported')
  final List<String>? introspectionEndpointAuthSigningAlgValuesSupported;

  /// A list of PKCE code challenge methods supported by this authorization
  /// server.
  @JsonKey(name: 'code_challenge_methods_supported')
  final List<String>? codeChallengeMethodsSupported;

  /// The URL of the pushed authorization request endpoint at which a client can
  /// post an authorization request to exchange for a request_uri value usable
  /// at the authorization server.
  @JsonKey(name: 'pushed_authorization_request_endpoint')
  final Uri? pushedAuthorizationRequestEndpoint;

  /// Boolean parameter indicating whether the authorization server accepts
  /// authorization request data only via PAR.
  ///
  /// If omitted, the default value is false.
  @JsonKey(name: 'require_pushed_authorization_requests')
  final bool? requirePushedAuthorizationRequests;
  bool get requirePushedAuthorizationRequestsOrDefault =>
      requirePushedAuthorizationRequests ?? false;
}
