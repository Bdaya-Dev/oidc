import 'package:oidc_core/oidc_core.dart';

/// The callback used to determine the `expiring` duration.
typedef OidcRefreshBeforeCallback = Duration? Function(OidcToken token);

/// The default refreshBefore function, which refreshes 1 minute before the token expires.
Duration? defaultRefreshBefore(OidcToken token) {
  return const Duration(minutes: 1);
}

/// The callback used to determine the retry delay for offline mode refresh attempts.
typedef OidcOfflineRefreshRetryDelayCallback =
    Duration Function(
      int consecutiveFailures,
    );

/// Default threshold for emitting repeat refresh failure warnings.

/// The default retry delay function with exponential backoff.
/// Returns delays of: 30s, 1m, 2m, 4m, 5m (capped at 5 minutes).
Duration defaultOfflineRefreshRetryDelay(int consecutiveFailures) {
  // Exponential backoff: 30s, 1m, 2m, 4m, 5m (capped)
  const baseDelay = Duration(seconds: 30);
  final exponentialDelay = baseDelay * (1 << (consecutiveFailures - 1));
  const maxDelay = Duration(minutes: 5);

  return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
}

/// Controls whether the authorization-code login flow uses RFC 9126 Pushed
/// Authorization Requests (PAR).
///
/// Note: under PAR the authorization parameters are frozen when the PAR request
/// is posted (the front channel then carries only `client_id` + `request_uri`),
/// so parameters added by the `authorization` hook do NOT reach the server.
/// Supply such parameters via `extraAuthenticationParameters` instead — those
/// are part of the pushed request body.
enum OidcPushedAuthorizationRequestsMode {
  /// Use PAR only when the authorization server requires it via discovery
  /// metadata (`require_pushed_authorization_requests` == true). Servers that
  /// don't require PAR behave exactly as without this setting (the default).
  auto,

  /// Always use PAR when the server advertises a
  /// `pushed_authorization_request_endpoint`.
  always,

  /// Never use PAR, even if the server requires it (the server will then reject
  /// the direct authorization request).
  never,
}

///
class OidcUserManagerSettings {
  ///
  const OidcUserManagerSettings({
    required this.redirectUri,
    this.uiLocales,
    this.extraTokenHeaders,
    this.scope = defaultScopes,
    this.prompt = const [],
    this.display,
    this.acrValues,
    this.maxAge,
    this.extraAuthenticationParameters,
    this.expiryTolerance = const Duration(minutes: 1),
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.frontChannelLogoutUri,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
    this.refreshBefore = defaultRefreshBefore,
    this.strictJwtVerification = true,
    this.allowedIdTokenAlgorithms,
    this.strictIssuerValidation = false,
    this.expectedIssuer,
    this.pushedAuthorizationRequestsMode =
        OidcPushedAuthorizationRequestsMode.auto,
    this.dpop,
    this.allowedAudiences,
    this.resource,
    this.requestObject,
    this.revokeTokensOnLogout = true,
    this.getExpiresIn,
    this.sessionManagementSettings = const OidcSessionManagementSettings(),
    this.getIdToken,
    this.supportOfflineAuth = false,
    this.offlineRefreshRetryDelay = defaultOfflineRefreshRetryDelay,
    this.offlineRepeatFailureWarningThreshold = 3,
    this.hooks,
    this.extraRevocationParameters,
    this.extraRevocationHeaders,
  });

  /// The default scopes
  static const defaultScopes = ['openid'];

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

  /// Whether id_token signatures are strictly verified (fail-closed).
  ///
  /// When `true` (the default), an id_token whose signature cannot be verified
  /// against the OP's JWKS is **rejected** (an exception is thrown). When
  /// `false`, a verification failure is logged and the token is accepted
  /// *unverified* — which means a forged or tampered id_token would be trusted.
  ///
  /// Defaults to `true` per OpenID Connect Core §3.1.3.7 and the OAuth 2.0
  /// Security BCP (RFC 9700). Only set this to `false` if you fully understand
  /// the risk (e.g. a controlled test environment).
  final bool strictJwtVerification;

  /// Optional explicit allowlist of JWS signing algorithms (canonical JWA
  /// names, e.g. `['RS256','ES256']`) that an id_token's `alg` header is
  /// permitted to use.
  ///
  /// When non-null, this list **replaces** the OP-advertised
  /// `id_token_signing_alg_values_supported` as the source of the verification
  /// allowlist (defense-in-depth: the RP stops trusting the OP's self-declared
  /// list). When null (the default), behavior is unchanged — the OP-advertised
  /// `id_token_signing_alg_values_supported` is used.
  ///
  /// `none` is always stripped regardless of this setting (existing behavior in
  /// [OidcUser]), so it can never be re-enabled via this list.
  ///
  /// Names must match `jose_plus`/JWA canonical casing (uppercase, e.g.
  /// `'RS256'`); a wrong-case or empty effective list will reject every
  /// id_token (fail-closed).
  ///
  /// Per OpenID Connect Core §3.1.3.7 (step 7) and RFC 8725 (JWT BCP) §3.1
  /// "Perform Algorithm Verification", which require the verifier to constrain
  /// accepted algorithms to an explicit caller-controlled set.
  final List<String>? allowedIdTokenAlgorithms;

  /// When `true`, after the discovery document is loaded the manager asserts
  /// that its `issuer` is identical to the expected issuer (the issuer used to
  /// compose the well-known URL, or [expectedIssuer] if set) per OIDC Discovery
  /// 1.0 §4.3 / RFC 8414 §3.3, throwing on mismatch and refusing to persist the
  /// document.
  ///
  /// When `false` (the **default**), a mismatch is only logged as a warning and
  /// the document is still used — this preserves out-of-the-box Microsoft Entra
  /// ID multi-tenant (`common`/`organizations`) and Azure AD B2C compatibility,
  /// whose discovery `issuer` legitimately differs from the authority used to
  /// fetch it (e.g. `https://login.microsoftonline.com/{tenantid}/v2.0`).
  ///
  /// Recommended `true` for single-tenant / non-Entra deployments and required
  /// for FAPI / high-assurance profiles; when enabling against a trailing-slash
  /// issuer or a custom discovery URL, also set [expectedIssuer].
  final bool strictIssuerValidation;

  /// Optional explicit issuer to compare the discovery document's `issuer`
  /// against (authoritative when set).
  ///
  /// When null (default) and a `discoveryDocumentUri` is present, the expected
  /// issuer is derived by stripping the trailing
  /// `.well-known/openid-configuration` segments from `discoveryDocumentUri`
  /// (the inverse of [OidcUtils.getOpenIdConfigWellKnownUri], which every
  /// in-repo call site uses to build the URL).
  ///
  /// Set this for issuers that contain a trailing slash, for custom/non-standard
  /// discovery URLs (e.g. Entra `?appid=` query, RFC 8414 insert-layout), or
  /// when constructing the manager with an eagerly-supplied `discoveryDocument`
  /// (no `discoveryDocumentUri` to derive from).
  ///
  /// Comparison is the spec-mandated simple-string match via
  /// [OidcUtils.issuersAreIdentical] (case-folds scheme+host only; path and
  /// trailing slash stay significant).
  final Uri? expectedIssuer;

  /// Whether/when the authorization-code login flow uses RFC 9126 Pushed
  /// Authorization Requests (PAR). Defaults to
  /// [OidcPushedAuthorizationRequestsMode.auto] — follow the server's
  /// `require_pushed_authorization_requests` metadata, which is non-breaking
  /// for servers that don't require PAR.
  final OidcPushedAuthorizationRequestsMode pushedAuthorizationRequestsMode;

  /// Enables + configures DPoP (Demonstrating Proof of Possession, RFC 9449).
  ///
  /// When non-null, the manager generates a per-session DPoP proof key and
  /// attaches a DPoP proof to token requests, sender-constraining the issued
  /// tokens to that key. Null (the default) disables DPoP.
  final OidcDPoPSettings? dpop;

  /// Additional audiences (beyond the `client_id`, which is always trusted)
  /// that an id_token's `aud` claim is allowed to contain.
  ///
  /// OpenID Connect Core §3.1.3.7 requires rejecting an id_token whose `aud`
  /// contains audiences not trusted by the client; this is the trust list.
  final List<String>? allowedAudiences;

  /// RFC 8707 Resource Indicators: the protected resource(s) the issued tokens
  /// are intended for. When set, it is sent on the authorization request and on
  /// refresh/token requests (as one repeated `resource` parameter per value).
  final List<Uri>? resource;

  /// JWT-Secured Authorization Request (JAR, RFC 9101) settings. When set, the
  /// authorization request parameters are signed into a `request` object and
  /// the front-channel request collapses to `client_id` + `response_type` +
  /// `scope` + `request`.
  final OidcRequestObjectSettings? requestObject;

  /// Whether [OidcUserManagerBase.logout] also revokes the refresh and access
  /// tokens at the provider's `revocation_endpoint` (RFC 7009) before ending
  /// the session. Defaults to `true`.
  ///
  /// Revocation is best-effort: it is a no-op when the provider advertises no
  /// `revocation_endpoint`, and a revocation failure never blocks logout (it is
  /// logged and swallowed). Set to `false` to keep logout purely front-channel.
  final bool revokeTokensOnLogout;

  /// Whether to support offline authentication or not.
  ///
  /// When this option is enabled, expired tokens will NOT be removed if the
  /// server can't be contacted
  ///
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// The retry delay calculation for offline mode refresh attempts.
  ///
  /// This callback receives the number of consecutive refresh failures and
  /// returns the duration to wait before the next retry attempt.
  ///
  /// The default implementation uses exponential backoff:
  /// - 1st failure: 30 seconds
  /// - 2nd failure: 1 minute
  /// - 3rd failure: 2 minutes
  /// - 4th failure: 4 minutes
  /// - 5th+ failure: 5 minutes (capped)
  ///
  /// This helps reduce battery usage and server load during extended outages.
  final OidcOfflineRefreshRetryDelayCallback offlineRefreshRetryDelay;

  /// The number of consecutive refresh failures before emitting a warning.
  ///
  /// Set to `0` or a negative value to disable repeat failure warnings.
  final int offlineRepeatFailureWarningThreshold;

  /// see [OidcAuthorizeRequest.redirectUri].
  final Uri redirectUri;

  /// see [OidcEndSessionRequest.postLogoutRedirectUri].
  final Uri? postLogoutRedirectUri;

  /// the uri of the front channel logout flow.
  /// this Uri MUST be registered with the OP first.
  /// the OP will call this Uri when it wants to logout the user.
  final Uri? frontChannelLogoutUri;

  /// The options to use when listening to platform channels.
  ///
  /// [frontChannelLogoutUri] must be set for this to work.
  final OidcFrontChannelRequestListeningOptions
  frontChannelRequestListeningOptions;

  /// see [OidcAuthorizeRequest.scope].
  final List<String> scope;

  /// see [OidcAuthorizeRequest.prompt].
  final List<String> prompt;

  /// see [OidcAuthorizeRequest.display].
  final String? display;

  /// see [OidcAuthorizeRequest.uiLocales].
  final List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.acrValues].
  final List<String>? acrValues;

  /// see [OidcAuthorizeRequest.maxAge]
  final Duration? maxAge;

  /// see [OidcAuthorizeRequest.extra]
  final Map<String, dynamic>? extraAuthenticationParameters;

  /// see [OidcTokenRequest.extra]
  final Map<String, String>? extraTokenHeaders;

  /// see [OidcTokenRequest.extra]
  final Map<String, dynamic>? extraTokenParameters;

  /// see [OidcRevocationRequest.extra]
  final Map<String, dynamic>? extraRevocationParameters;

  /// Extra headers to send with the revocation request.
  final Map<String, String>? extraRevocationHeaders;

  /// see [OidcIdTokenVerificationOptions.expiryTolerance].
  final Duration expiryTolerance;

  /// Settings related to the session management spec.
  final OidcSessionManagementSettings sessionManagementSettings;

  /// How early the token gets refreshed.
  ///
  /// for example:
  ///
  /// - if `Duration.zero` is returned, the token gets refreshed once it's expired.
  /// - (default) if `Duration(minutes: 1)` is returned, it will refresh the token 1 minute before it expires.
  /// - if `null` is returned, automatic refresh is disabled.
  final OidcRefreshBeforeCallback? refreshBefore;

  /// overrides a token's expires_in value.
  final Duration? Function(OidcTokenResponse tokenResponse)? getExpiresIn;

  /// pass this function to control how an `id_token` is fetched from a
  /// token response.
  ///
  /// This can be used to trick the user manager into using a JWT `access_token`
  /// as an `id_token` for example.
  final Future<String?> Function(OidcToken token)? getIdToken;

  /// platform-specific options.
  final OidcPlatformSpecificOptions? options;

  /// Customized hooks to modify the user manager behavior.
  final OidcUserManagerHooks? hooks;
}

///
class OidcUserInfoSettings {
  ///
  const OidcUserInfoSettings({
    this.accessTokenLocation =
        OidcUserInfoAccessTokenLocations.authorizationHeader,
    this.requestMethod = OidcConstants_RequestMethod.get,
    this.sendUserInfoRequest = true,
    this.followDistributedClaims = true,
    this.getAccessTokenForDistributedSource,
    this.validateSignedResponseClaims = true,
    this.requireSignedResponseIssAud = false,
  });

  /// Where to put the access token.
  final OidcUserInfoAccessTokenLocations accessTokenLocation;

  /// Request method to use (POST/GET).
  final String requestMethod;

  /// Whether to send the user info request.
  ///
  /// true by default.
  final bool sendUserInfoRequest;

  /// Whether to try to follow and resolve Distributed Claims or not.
  final bool followDistributedClaims;

  /// this function gets called whenever there is an endpoint with no access token,
  /// to try and get the access token.
  final Future<String?> Function(String, Uri)?
  getAccessTokenForDistributedSource;

  /// When the UserInfo endpoint returns a signed JWT
  /// (`Content-Type: application/jwt`) that was verified against the keyStore,
  /// validate its `iss`/`aud`/`exp` claims per OIDC Core 5.3.2/5.3.4.
  ///
  /// `iss` (when present) MUST exactly match the OP issuer; `aud` (when present)
  /// MUST contain the RP `client_id`; `exp` (when present) MUST NOT be past
  /// (within `expiryTolerance`).
  ///
  /// Set `false` to opt out (e.g. a non-conformant OP). Has no effect on plain
  /// `application/json` responses.
  ///
  /// Defaults to `true`.
  final bool validateSignedResponseClaims;

  /// Upgrades the OIDC Core 5.3.2 SHOULD for `iss`/`aud` presence on a signed
  /// UserInfo JWT to a MUST.
  ///
  /// When `true`, a signed (verified) UserInfo JWT that omits `iss` OR `aud` is
  /// rejected. Default `false` stays lenient (validate only when the claim is
  /// present), matching common OP behaviour and the spec's SHOULD. Enable for
  /// FAPI/strict deployments.
  ///
  /// Ignored when [validateSignedResponseClaims] is `false`.
  final bool requireSignedResponseIssAud;
}

///
class OidcSessionManagementSettings {
  ///
  const OidcSessionManagementSettings({
    this.enabled = false,
    this.interval = const Duration(seconds: 5),
    this.stopIfErrorReceived = true,
  });

  /// pass `true` if you want to enable the session checking.
  ///
  /// default is false.
  final bool enabled;

  /// how often do you want to ask the server for user status.
  ///
  /// default is 5 seconds.
  final Duration interval;

  /// if the OP sends us an "error" responses when checking for status, it's pointless to ask for status after it.
  ///
  /// by default this is true.
  final bool stopIfErrorReceived;
}
