// NOTICE: This file was mostly copied and edited from:
// https://github.com/appsup-dart/openid_client/blob/92a9a055c62c3b302d70a401ef872b5b9dba6f21/lib/src/model/metadata.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:oidc_core/src/models/json_based_object.dart';

part 'resp.g.dart';

/// The "OpenID Provider Metadata" as standaraized by the spec https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata
/// This also includes some metadata that are defined by other extensions
///
/// see https://www.iana.org/assignments/oauth-parameters/oauth-parameters.xhtml
@JsonSerializable(
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
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
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.issuer)
  final Uri? issuer;

  /// URL of the OP's OAuth 2.0 Authorization Endpoint.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.authorizationEndpoint)
  final Uri? authorizationEndpoint;

  /// URL of the OP's OAuth 2.0 Token Endpoint.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.tokenEndpoint)
  final Uri? tokenEndpoint;

  /// URL of the OP's UserInfo Endpoint.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.userinfoEndpoint)
  final Uri? userinfoEndpoint;

  /// URL of the OP's JSON Web Key Set document.
  ///
  /// This contains the signing key(s) the RP uses to validate signatures
  /// from the OP.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.jwksUri)
  final Uri? jwksUri;

  /// URL of the OP's Dynamic Client Registration Endpoint.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.registrationEndpoint)
  final Uri? registrationEndpoint;

  /// A list of the OAuth 2.0 scope values that this server supports.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.scopesSupported)
  final List<String>? scopesSupported;

  /// A list of the OAuth 2.0 `responseType` values that this OP supports.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.responseTypesSupported)
  final List<String>? responseTypesSupported;

  /// A list of the OAuth 2.0 `responseMode` values that this OP supports.
  @JsonKey(
    name: OidcConstants_AuthorizationServerMetadata.responseModesSupported,
  )
  final List<String>? responseModesSupported;

  /// A list of the OAuth 2.0 Grant Type values that this OP supports.
  @JsonKey(
    name: OidcConstants_AuthorizationServerMetadata.grantTypesSupported,
  )
  final List<String>? grantTypesSupported;
  List<String> get grantTypesSupportedOrDefault =>
      grantTypesSupported ??
      [
        OidcConstants_GrantType.authorizationCode,
        OidcConstants_GrantType.implicit,
      ];

  /// A list of the Authentication Context Class References that this
  /// OP supports.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.acrValuesSupported)
  final List<String>? acrValuesSupported;

  /// A list of the Subject Identifier types that this OP supports.
  ///
  /// Valid types include `pairwise` and `public`.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.subjectTypesSupported)
  final List<String>? subjectTypesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  ///
  /// The algorithm `RS256` MUST be included. The value `none` MAY be supported,
  /// but MUST NOT be used unless the Response Type used returns no ID Token
  /// from the Authorization Endpoint (such as when using the Authorization Code
  /// Flow).
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .idTokenSigningAlgValuesSupported)
  final List<String>? idTokenSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .idTokenEncryptionAlgValuesSupported)
  final List<String>? idTokenEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the OP
  /// for the ID Token to encode the Claims in a JWT.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .idTokenEncryptionEncValuesSupported)
  final List<String>? idTokenEncryptionEncValuesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the

  /// UserInfo Endpoint to encode the Claims in a JWT.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .userinfoSigningAlgValuesSupported)
  final List<String>? userinfoSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the
  /// UserInfo Endpoint to encode the Claims in a JWT.

  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .userinfoEncryptionAlgValuesSupported)
  final List<String>? userinfoEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the
  /// UserInfo Endpoint to encode the Claims in a JWT.

  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .userinfoEncryptionEncValuesSupported)
  final List<String>? userinfoEncryptionEncValuesSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// (using the request parameter) and when it is passed by reference (using
  /// the requestUri parameter).
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requestObjectSigningAlgValuesSupported)
  final List<String>? requestObjectSigningAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`alg` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// and when it is passed by reference.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requestObjectEncryptionAlgValuesSupported)
  final List<String>? requestObjectEncryptionAlgValuesSupported;

  /// A list of the JWE encryption algorithms (`enc` values) supported by the OP
  /// for Request Objects.
  ///
  /// These algorithms are used both when the Request Object is passed by value
  /// and when it is passed by reference.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requestObjectEncryptionEncValuesSupported)
  final List<String>? requestObjectEncryptionEncValuesSupported;

  /// A list of Client Authentication methods supported by this Token Endpoint.
  ///
  /// The options are `clientSecretPost`, `clientSecretBasic`,
  /// `clientSecretJwt`, and `privateKeyJwt`. Other authentication methods
  /// MAY be defined by extensions.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .tokenEndpointAuthMethodsSupported)
  final List<String>? tokenEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the Token
  /// Endpoint for the signature on the JWT used to authenticate the Client at
  /// the Token Endpoint for the `privateKeyJwt` and `clientSecretJwt`
  /// authentication methods.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .tokenEndpointAuthSigningAlgValuesSupported)
  final List<String>? tokenEndpointAuthSigningAlgValuesSupported;

  /// A list of the display parameter values that the OpenID Provider supports.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.displayValuesSupported)
  final List<String>? displayValuesSupported;

  /// A list of the Claim Types that the OpenID Provider supports.
  ///
  /// Values defined by the specification are `normal`, `aggregated`, and
  /// `distributed`. If omitted, the implementation supports only `normal`
  /// Claims.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.claimTypesSupported)
  final List<String>? claimTypesSupported;

  /// A list of the Claim Names of the Claims that the OpenID Provider MAY be
  /// able to supply values for.
  ///
  /// Note that for privacy or other reasons, this might not be an exhaustive
  /// list.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.claimsSupported)
  final List<String>? claimsSupported;

  /// URL of a page containing human-readable information that developers might
  /// want or need to know when using the OpenID Provider.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.serviceDocumentation)
  final Uri? serviceDocumentation;

  /// Languages and scripts supported for values in Claims being returned.
  ///
  /// Not all languages and scripts are necessarily supported for all Claim
  /// values.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.claimsLocalesSupported)
  final List<String>? claimsLocalesSupported;

  /// Languages and scripts supported for the user interface.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.uiLocalesSupported)
  final List<String>? uiLocalesSupported;

  /// `true` when the OP supports use of the `claims` parameter.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.claimsParameterSupported)
  final bool? claimsParameterSupported;
  bool get claimsParameterSupportedOrDefault =>
      claimsParameterSupported ?? false;

  /// `true` when the OP supports use of the `request` parameter.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.requestParameterSupported)
  final bool? requestParameterSupported;

  /// `true` when the OP supports use of the `requestUri` parameter.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requestUriParameterSupported)
  final bool? requestUriParameterSupported;
  bool get requestUriParameterSupportedOrDefault =>
      requestUriParameterSupported ?? true;

  /// `true` when the OP requires any `requestUri` values used to be
  /// pre-registered using the requestUris registration parameter.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requireRequestUriRegistration)
  final bool? requireRequestUriRegistration;

  /// URL that the OpenID Provider provides to the person registering the Client
  /// to read about the OP's requirements on how the Relying Party can use the
  /// data provided by the OP.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.opPolicyUri)
  final Uri? opPolicyUri;

  /// URL that the OpenID Provider provides to the person registering the Client
  /// to read about OpenID Provider's terms of service.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.opTosUri)
  final Uri? opTosUri;

  /// URL of an OP iframe that supports cross-origin communications for session
  /// state information with the RP Client, using the HTML5 postMessage API.
  ///
  /// The page is loaded from an invisible iframe embedded in an RP page so that
  /// it can run in the OP's security context. It accepts postMessage requests
  /// from the relevant RP iframe and uses postMessage to post back the login
  /// status of the End-User at the OP.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.checkSessionIframe)
  final Uri? checkSessionIframe;

  /// URL at the OP to which an RP can perform a redirect to request that the
  /// End-User be logged out at the OP.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.endSessionEndpoint)
  final Uri? endSessionEndpoint;

  /// URL of the authorization server's OAuth 2.0 revocation endpoint.
  @JsonKey(name: OidcConstants_AuthorizationServerMetadata.revocationEndpoint)
  final Uri? revocationEndpoint;

  /// A list of client authentication methods supported by this revocation
  /// endpoint.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .revocationEndpointAuthMethodsSupported)
  final List<String>? revocationEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the
  /// revocation endpoint for the signature on the JWT used to authenticate the
  /// client at the revocation endpoint for the `privateKeyJwt` and
  /// `clientSecretJwt` authentication methods.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .revocationEndpointAuthSigningAlgValuesSupported)
  final List<String>? revocationEndpointAuthSigningAlgValuesSupported;

  /// URL of the authorization server's OAuth 2.0 introspection endpoint.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata.introspectionEndpoint)
  final Uri? introspectionEndpoint;

  /// A list of client authentication methods supported by this introspection
  /// endpoint.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .introspectionEndpointAuthMethodsSupported)
  final List<String>? introspectionEndpointAuthMethodsSupported;

  /// A list of the JWS signing algorithms (`alg` values) supported by the
  /// introspection endpoint for the signature on the JWT used to authenticate
  /// the client at the introspection endpoint for the `privateKeyJwt` and
  /// `clientSecretJwt` authentication methods.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .introspectionEndpointAuthSigningAlgValuesSupported)
  final List<String>? introspectionEndpointAuthSigningAlgValuesSupported;

  /// A list of PKCE code challenge methods supported by this authorization
  /// server.
  @JsonKey(
    name:
        OidcConstants_AuthorizationServerMetadata.codeChallengeMethodsSupported,
  )
  final List<String>? codeChallengeMethodsSupported;

  /// The URL of the pushed authorization request endpoint at which a client can
  /// post an authorization request to exchange for a requestUri value usable
  /// at the authorization server.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .pushedAuthorizationRequestEndpoint)
  final Uri? pushedAuthorizationRequestEndpoint;

  /// Boolean parameter indicating whether the authorization server accepts
  /// authorization request data only via PAR.
  ///
  /// If omitted, the default value is false.
  @JsonKey(
      name: OidcConstants_AuthorizationServerMetadata
          .requirePushedAuthorizationRequests)
  final bool? requirePushedAuthorizationRequests;
  bool get requirePushedAuthorizationRequestsOrDefault =>
      requirePushedAuthorizationRequests ?? false;
}
