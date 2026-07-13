import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'request.g.dart';

/// Client metadata for OAuth 2.0 Dynamic Client Registration (RFC 7591 §2),
/// also used as the body of an RFC 7592 client update.
///
/// The JSON keys are the standard RFC 7591 client-metadata names. Any field not
/// modelled here can be supplied via [extra].
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcClientRegistrationRequest extends JsonBasedRequest {
  ///
  OidcClientRegistrationRequest({
    this.redirectUris,
    this.responseTypes,
    this.grantTypes,
    this.applicationType,
    this.contacts,
    this.clientName,
    this.logoUri,
    this.clientUri,
    this.policyUri,
    this.tosUri,
    this.jwksUri,
    this.jwks,
    this.sectorIdentifierUri,
    this.subjectType,
    this.tokenEndpointAuthMethod,
    this.idTokenSignedResponseAlg,
    this.defaultMaxAge,
    this.requireAuthTime,
    this.defaultAcrValues,
    this.initiateLoginUri,
    this.requestUris,
    this.scope,
    this.softwareId,
    this.softwareVersion,
    this.softwareStatement,
    this.tlsClientAuthSubjectDn,
    this.tlsClientAuthSanDns,
    this.tlsClientAuthSanUri,
    this.tlsClientAuthSanIp,
    this.tlsClientAuthSanEmail,
    this.tlsClientCertificateBoundAccessTokens,
    super.extra,
  });

  /// Redirection URI values used by the client.
  @JsonKey(name: 'redirect_uris')
  List<Uri>? redirectUris;

  /// OAuth 2.0 response types the client may use.
  @JsonKey(name: 'response_types')
  List<String>? responseTypes;

  /// OAuth 2.0 grant types the client may use.
  @JsonKey(name: 'grant_types')
  List<String>? grantTypes;

  /// Kind of the application: `web` or `native`.
  @JsonKey(name: 'application_type')
  String? applicationType;

  /// E-mail addresses of people responsible for the client.
  @JsonKey(name: 'contacts')
  List<String>? contacts;

  /// Human-readable name of the client.
  @JsonKey(name: 'client_name')
  String? clientName;

  /// URL of the client's logo.
  @JsonKey(name: 'logo_uri')
  Uri? logoUri;

  /// URL of the client's home page.
  @JsonKey(name: 'client_uri')
  Uri? clientUri;

  /// URL of the client's privacy policy.
  @JsonKey(name: 'policy_uri')
  Uri? policyUri;

  /// URL of the client's terms of service.
  @JsonKey(name: 'tos_uri')
  Uri? tosUri;

  /// URL of the client's JWK Set document.
  @JsonKey(name: 'jwks_uri')
  Uri? jwksUri;

  /// The client's JWK Set by value (mutually exclusive with [jwksUri]).
  @JsonKey(name: 'jwks')
  Map<String, dynamic>? jwks;

  /// URL referencing the client's sector identifier.
  @JsonKey(name: 'sector_identifier_uri')
  Uri? sectorIdentifierUri;

  /// `subject_type` requested for responses to this client.
  @JsonKey(name: 'subject_type')
  String? subjectType;

  /// Requested client authentication method for the token endpoint.
  @JsonKey(name: 'token_endpoint_auth_method')
  String? tokenEndpointAuthMethod;

  /// JWS `alg` the client requires for its id_tokens.
  @JsonKey(name: 'id_token_signed_response_alg')
  String? idTokenSignedResponseAlg;

  /// Default Maximum Authentication Age (OpenID Connect Dynamic Client
  /// Registration 1.0 §2): if the End-User was authenticated longer ago than
  /// this, they MUST be actively re-authenticated. Serialized as a number of
  /// seconds.
  @JsonKey(name: 'default_max_age')
  Duration? defaultMaxAge;

  /// Whether the `auth_time` claim in the id_token is REQUIRED (OpenID Connect
  /// Dynamic Client Registration 1.0 §2).
  @JsonKey(name: 'require_auth_time')
  bool? requireAuthTime;

  /// Default `acr` values the OP is requested to use for this client (OpenID
  /// Connect Dynamic Client Registration 1.0 §2), as a JSON array of strings.
  @JsonKey(name: 'default_acr_values')
  List<String>? defaultAcrValues;

  /// URI (https) a third party can use to initiate a login for this client
  /// (OpenID Connect Dynamic Client Registration 1.0 §2).
  @JsonKey(name: 'initiate_login_uri')
  Uri? initiateLoginUri;

  /// `request_uri` values pre-registered by the client for use at the OP
  /// (OpenID Connect Dynamic Client Registration 1.0 §2). These URIs MUST use
  /// the https scheme.
  @JsonKey(name: 'request_uris')
  List<Uri>? requestUris;

  /// Space-separated list of scope values the client may request.
  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String>? scope;

  /// Unique identifier for the client software (constant across instances).
  @JsonKey(name: 'software_id')
  String? softwareId;

  /// Version of the client software.
  @JsonKey(name: 'software_version')
  String? softwareVersion;

  /// A signed software statement JWT asserting client metadata.
  @JsonKey(name: 'software_statement')
  String? softwareStatement;

  /// RFC 8705 §2.1.2: expected subject distinguished name (RFC 4514 string) of
  /// the client certificate, for the `tls_client_auth` PKI method.
  @JsonKey(name: 'tls_client_auth_subject_dn')
  String? tlsClientAuthSubjectDn;

  /// RFC 8705 §2.1.2: expected `dNSName` SAN entry of the client certificate,
  /// for the `tls_client_auth` PKI method.
  @JsonKey(name: 'tls_client_auth_san_dns')
  String? tlsClientAuthSanDns;

  /// RFC 8705 §2.1.2: expected `uniformResourceIdentifier` SAN entry of the
  /// client certificate, for the `tls_client_auth` PKI method.
  @JsonKey(name: 'tls_client_auth_san_uri')
  String? tlsClientAuthSanUri;

  /// RFC 8705 §2.1.2: expected `iPAddress` SAN entry (dotted-decimal IPv4 or
  /// colon-delimited hexadecimal IPv6) of the client certificate, for the
  /// `tls_client_auth` PKI method.
  @JsonKey(name: 'tls_client_auth_san_ip')
  String? tlsClientAuthSanIp;

  /// RFC 8705 §2.1.2: expected `rfc822Name` SAN entry of the client
  /// certificate, for the `tls_client_auth` PKI method.
  @JsonKey(name: 'tls_client_auth_san_email')
  String? tlsClientAuthSanEmail;

  /// RFC 8705 §3.4: the client's intention to use mutual-TLS client
  /// certificate-bound access tokens.
  @JsonKey(name: 'tls_client_certificate_bound_access_tokens')
  bool? tlsClientCertificateBoundAccessTokens;

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    ..._$OidcClientRegistrationRequestToJson(this),
  };
}
