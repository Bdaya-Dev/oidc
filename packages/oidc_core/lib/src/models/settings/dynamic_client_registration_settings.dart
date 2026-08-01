import 'package:oidc_core/oidc_core.dart';

/// Builds the RFC 7591 client metadata posted to the OP's
/// `registration_endpoint`. Called with the resolved discovery document so the
/// metadata can be adapted to what the OP advertises.
///
/// The manager fills six members when the returned request leaves them null:
/// `redirect_uris` (from [OidcUserManagerSettings.redirectUri]),
/// `post_logout_redirect_uris` (from
/// [OidcUserManagerSettings.postLogoutRedirectUri], and only when that is set),
/// `scope` (from [OidcUserManagerSettings.scope]),
/// `grant_types` and `response_types` (from
/// [OidcDynamicClientRegistrationSettings.grantTypes] /
/// [OidcDynamicClientRegistrationSettings.responseTypes]), and
/// `application_type`. All are mutated in place on the returned instance
/// ([OidcClientRegistrationRequest]'s fields are non-final by design), so
/// return a fresh instance per call.
///
/// `application_type` is DERIVED from the resolved `redirect_uris`, not from
/// the host platform: OpenID Connect Dynamic Client Registration 1.0 §2 makes
/// "custom URI scheme or loopback `http`" the rule for [OidcConstants_ApplicationType.native]
/// and https-without-localhost the rule for [OidcConstants_ApplicationType.web],
/// so a mobile app whose redirect is an https App Link / Universal Link is a
/// `web` application_type. Set it here to override.
///
/// Called once per `init()` even when a persisted registration is being
/// re-used: the resulting request is what the staleness fingerprint is computed
/// from, so a change made here (and not in the settings) is still detected.
/// Members that legitimately differ per call — a freshly signed
/// `software_statement`, a rotated `jwks` — are excluded from that fingerprint
/// and will not cause a re-registration.
typedef OidcClientRegistrationRequestBuilder =
    OidcClientRegistrationRequest Function(OidcProviderMetadata metadata);

/// Enables + configures RFC 7591 Dynamic Client Registration for an
/// `OidcUserManager`.
///
/// When [OidcUserManagerSettings.dynamicClientRegistration] is non-null, the
/// `clientCredentials` passed to the manager's constructor is only a
/// pre-registration seed: `init()` replaces it with credentials derived from
/// the registration response via
/// [OidcClientAuthentication.fromRegistrationResponse].
///
/// ## On web, the registered client is always PUBLIC
///
/// A browser app is a public client (OAuth 2.0 for Browser-Based Apps §6.1) and
/// has nowhere to keep a secret: the registration is persisted in
/// [OidcStoreNamespace.secureTokens], which on web is `localStorage` — plainly
/// so when no `FlutterSecureStorage` is supplied to `OidcDefaultStore`, and
/// still browser storage when one is — readable by any injected script. A
/// `client_secret` there is not a secret, and the RFC 7592
/// `registration_access_token` stored beside it would let that script
/// re-configure or delete the OP-side client.
///
/// So on web the manager asks for `token_endpoint_auth_method: "none"` when
/// [buildRequest] leaves it unset (RFC 7591 §2 would otherwise default the
/// client to the confidential `client_secret_basic`), and REFUSES — with a
/// typed `OidcException`, before anything is stored — a registration response
/// that carries a `client_secret` anyway. If your provider insists on issuing
/// one, the client belongs on a backend, not in the browser.
///
/// ## The manager registers once, and then leaves the client alone
///
/// One immutable record is persisted per issuer and restored on every later
/// launch with no network call. It is replaced only when the request this build
/// would send no longer matches the one it was issued for, or when the issued
/// `client_secret` has expired.
///
/// Nothing rotates the credential mid-session, re-registers when the provider
/// answers `invalid_client`, or tracks and reaps orphaned OP-side clients —
/// each of those is a documented non-goal on
/// `OidcUserManagerBase.ensureClientRegistration`, naming the clause that makes
/// it optional and the [OidcEndpoints] call an app makes instead.
/// `OidcUserManagerBase.forgetClientRegistration` is the escape hatch out of
/// all of them.
class OidcDynamicClientRegistrationSettings {
  ///
  const OidcDynamicClientRegistrationSettings({
    required this.buildRequest,
    this.initialAccessToken,
    this.preferredTokenEndpointAuthMethod,
    this.extraHeaders,
    this.grantTypes = defaultGrantTypes,
    this.responseTypes = defaultResponseTypes,
  });

  /// The grant types the manager itself drives with no further opt-in:
  /// `authorization_code` for the login flows, and `refresh_token` for the
  /// automatic token refresh.
  ///
  /// RFC 7591 §2 is the reason this cannot be left to the server: "If omitted,
  /// the default behavior is that the client will use only the
  /// `authorization_code` Grant Type" — which would leave the manager's own
  /// auto-refresh using a grant the client is not registered for.
  static const List<String> defaultGrantTypes = [
    OidcConstants_GrantType.authorizationCode,
    OidcConstants_GrantType.refreshToken,
  ];

  /// RFC 7591 §2: "If omitted, the default is that the client will use only
  /// the `code` response type" — stated explicitly so it is part of the
  /// registration the manager can later compare against.
  static const List<String> defaultResponseTypes = [
    OidcConstants_AuthorizationEndpoint_ResponseType.code,
  ];

  /// Builds the client metadata for the registration request.
  final OidcClientRegistrationRequestBuilder buildRequest;

  /// Sent as `Authorization: Bearer <token>` on the registration request, for
  /// OPs that gate `registration_endpoint` behind an initial access token
  /// (RFC 7591 §3.1). Null for open registration.
  final String? initialAccessToken;

  /// Overrides the `token_endpoint_auth_method` the OP echoed back, threaded
  /// into [OidcClientAuthentication.fromRegistrationResponse]'s
  /// `preferredMethod`. Null (the default) honours the server's value, falling
  /// back to `client_secret_basic`.
  final String? preferredTokenEndpointAuthMethod;

  /// Extra headers merged into the registration request.
  final Map<String, String>? extraHeaders;

  /// `grant_types` to register, filled in when [buildRequest] leaves them null.
  ///
  /// Defaults to [defaultGrantTypes]. Flows the app opts into must be added
  /// here or the OP will refuse them at the token endpoint: the device-code
  /// flow needs [OidcConstants_GrantType.deviceCode], and the implicit/hybrid
  /// flows need [OidcConstants_GrantType.implicit] (plus the matching
  /// [responseTypes]).
  final List<String> grantTypes;

  /// `response_types` to register, filled in when [buildRequest] leaves them
  /// null. Defaults to [defaultResponseTypes]. OpenID Connect Dynamic Client
  /// Registration 1.0 §2 requires these to be consistent with [grantTypes].
  final List<String> responseTypes;
}
