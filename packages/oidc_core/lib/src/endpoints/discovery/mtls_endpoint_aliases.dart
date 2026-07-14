import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

/// RFC 8705 §5 `mtls_endpoint_aliases`: a JSON object of alternative
/// authorization-server endpoints that a client doing mutual TLS uses in
/// preference to the conventional (top-level) endpoints.
///
/// Only the endpoints the server chooses to alias are present; any absent
/// endpoint means the client should fall back to the corresponding top-level
/// endpoint. Each getter returns `null` when the alias is absent or malformed.
class OidcMtlsEndpointAliases extends JsonBasedResponse {
  ///
  const OidcMtlsEndpointAliases({required super.src});

  ///
  factory OidcMtlsEndpointAliases.fromJson(Map<String, dynamic> src) =>
      OidcMtlsEndpointAliases(src: src);

  /// The mTLS alias for the token endpoint, if present.
  Uri? get tokenEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.tokenEndpoint);

  /// The mTLS alias for the UserInfo endpoint, if present.
  Uri? get userinfoEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.userinfoEndpoint);

  /// The mTLS alias for the revocation endpoint, if present.
  Uri? get revocationEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.revocationEndpoint);

  /// The mTLS alias for the introspection endpoint, if present.
  Uri? get introspectionEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.introspectionEndpoint);

  /// The mTLS alias for the Dynamic Client Registration endpoint, if present.
  Uri? get registrationEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.registrationEndpoint);

  /// The mTLS alias for the device authorization endpoint, if present.
  Uri? get deviceAuthorizationEndpoint =>
      getEndpoint(OidcConstants_ProviderMetadata.deviceAuthorizationEndpoint);

  /// The mTLS alias for the pushed authorization request (PAR) endpoint, if
  /// present.
  Uri? get pushedAuthorizationRequestEndpoint => getEndpoint(
    OidcConstants_ProviderMetadata.pushedAuthorizationRequestEndpoint,
  );

  /// Returns the aliased endpoint stored under [endpointName] (one of the
  /// `OidcConstants_ProviderMetadata` endpoint keys), or `null` when the alias
  /// is absent or not a parseable URI.
  Uri? getEndpoint(String endpointName) =>
      OidcInternalUtilities.tryParseUri(src[endpointName]);
}
