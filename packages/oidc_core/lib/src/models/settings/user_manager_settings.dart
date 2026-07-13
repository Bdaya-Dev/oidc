import 'package:oidc_core/oidc_core.dart';

/// The callback used to determine the `expiring` duration.
typedef OidcRefreshBeforeCallback = Duration? Function(OidcToken token);

/// The default refreshBefore function, which refreshes 1 minute before the token expires.
Duration? defaultRefreshBefore(OidcToken token) {
  return const Duration(minutes: 1);
}

/// The callback used by [OidcUserManagerSettings.isLoadedTokenAcceptable] to
/// decide, when tokens are restored from the [OidcStore] during `init()`,
/// whether the loaded token should be treated as acceptable despite (or in the
/// absence of) validation errors.
///
/// [validationErrors] is the exact list produced by the manager's internal
/// `validateUser` for the loaded id_token (empty when the token validated
/// cleanly).
///
/// Return:
/// - `true`  → accept the loaded token as-is and surface the user immediately,
///   skipping the refresh / userinfo round-trips.
/// - `false` → reject the loaded token (proceed to the discard branch, see
///   [OidcShouldRemoveInvalidTokenCallback]).
/// - `null`  → apply the default policy (the current, unchanged behavior:
///   refresh when expired, then re-validate).
typedef OidcIsLoadedTokenAcceptableCallback =
    bool? Function(OidcUser user, List<Exception> validationErrors);

/// The callback used by [OidcUserManagerSettings.shouldRemoveInvalidToken] to
/// decide whether a loaded-but-invalid token is removed from the [OidcStore].
///
/// Invoked in the discard branch of cached-token loading with the loaded
/// [user] and its [validationErrors].
///
/// Return:
/// - `true`  → remove the cached tokens from the store.
/// - `false` → keep the cached tokens (e.g. for a bespoke offline policy).
/// - `null`  → apply the default policy, which removes the tokens unless
///   [OidcUserManagerSettings.supportOfflineAuth] is enabled.
typedef OidcShouldRemoveInvalidTokenCallback =
    bool? Function(OidcUser user, List<Exception> validationErrors);

/// Controls how [OidcUserManagerBase.init] restores a previously-cached user.
///
/// **This changes the DEFAULT `init()` semantics** (see [OidcInitMode.cacheFirst]
/// vs [OidcInitMode.blockingValidate]).
enum OidcInitMode {
  /// **The new default.** `init()` restores the cached user by a PURE local
  /// deserialize (no network) and completes immediately, then revalidates in
  /// the background — refreshing the discovery document if it is stale
  /// (see [OidcUserManagerSettings.discoveryDocumentMaxAge]), refreshing the
  /// token if it is expired, and calling the userinfo endpoint when enabled.
  ///
  /// Background outcomes are surfaced through the existing channels:
  /// [OidcUserManagerBase.userChanges] emits when the user object changes and
  /// [OidcUserManagerBase.events] emits on failures. When there is no cached
  /// user (or no locally-cached discovery document), `init()` transparently
  /// falls back to the [blockingValidate] network path.
  ///
  /// This makes cold-start `init()` fast and offline-friendly at the cost of a
  /// brief window where the surfaced user has not yet been re-verified against
  /// the network.
  ///
  /// **Note — [OidcUserManagerBase.userChanges] emits TWICE on a cold start:**
  /// once for the locally-restored (unverified) user, then again for the
  /// background-rebuilt user once revalidation completes. The second object is
  /// distinct even when its claims are unchanged — its id_token is now VERIFIED
  /// (`parsedIdToken.isVerified == true`) and/or its token was refreshed — so
  /// this second emission is intentional and must not be deduplicated: it is how
  /// the verified/refreshed state is surfaced. Listeners that need a single
  /// settled value should key off `parsedIdToken.isVerified` (or use
  /// [blockingValidate]).
  cacheFirst,

  /// The pre-existing semantics (opt-in escape hatch): `init()` blocks until
  /// the discovery document is fetched/validated and the cached token is fully
  /// re-verified (and refreshed/userinfo-fetched) before completing. Choose
  /// this when callers must not observe an unverified user after `init()`.
  ///
  /// **Not a byte-for-byte replica of the pre-1.0 `init()` network behavior.**
  /// The discovery document is now served from the shared TTL cache
  /// (see [OidcUserManagerSettings.discoveryDocumentMaxAge], default 1 day), so
  /// a cached `.well-known` document within that window is NOT re-fetched — the
  /// old code fetched it on every `init()`. To reproduce the exact previous
  /// network behavior (a discovery fetch on every `init()`), also set
  /// `discoveryDocumentMaxAge: Duration.zero`.
  blockingValidate,
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
    this.jwksCacheMaxAge = const Duration(days: 1),
    this.discoveryDocumentMaxAge = const Duration(days: 1),
    this.initMode = OidcInitMode.cacheFirst,
    this.metadataSeed,
    this.isLoadedTokenAcceptable,
    this.shouldRemoveInvalidToken,
    this.extraTokenParameters,
    this.postLogoutRedirectUri,
    this.options,
    this.frontChannelLogoutUri,
    this.userInfoSettings = const OidcUserInfoSettings(),
    this.frontChannelRequestListeningOptions =
        const OidcFrontChannelRequestListeningOptions(),
    this.refreshBefore = defaultRefreshBefore,
    this.allowedIdTokenAlgorithms,
    this.strictIssuerValidation = false,
    this.verifySignedMetadata = false,
    this.allowedSignedMetadataAlgorithms,
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
    this.useMtlsEndpointAliases = false,
  });

  /// The default scopes
  static const defaultScopes = ['openid'];

  /// Settings to control using the user_info endpoint.
  final OidcUserInfoSettings userInfoSettings;

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

  /// Master gate for RFC 8414 §2.1 signed authorization-server metadata
  /// verification.
  ///
  /// When `true` AND the discovery document carries a `signed_metadata` member
  /// (RFC 8414 §2.1), the JWT is signature-verified against keys bootstrapped
  /// from the (TLS-fetched) plain `jwks_uri`, and its verified claims override
  /// the corresponding plain JSON values (RFC 8414 §3.2) before the document is
  /// issuer-validated and persisted.
  ///
  /// When `false` (the **default**), `signed_metadata` is ignored entirely and
  /// the plain JSON is used as-is — preserving out-of-the-box Microsoft Entra /
  /// Azure AD B2C compatibility (those IdPs do not emit `signed_metadata`).
  ///
  /// On a verification failure, the document is refused and NOT persisted
  /// (fail-closed — there is no fall back to the unverified plain document).
  /// Recommend `true` (with [allowedSignedMetadataAlgorithms] pinned) for
  /// FAPI / high-assurance deployments.
  final bool verifySignedMetadata;

  /// Optional explicit allowlist of JWS algorithms permitted for the
  /// `signed_metadata` JWT (canonical JWA names, e.g. `['RS256','ES256']`),
  /// mirroring [allowedIdTokenAlgorithms].
  ///
  /// `none` is ALWAYS stripped regardless of this list. When null (the
  /// default), any non-`none` algorithm the AS used is accepted; set this to
  /// pin a safe set (recommended). Names must use `jose_plus` canonical casing
  /// (uppercase, e.g. `'RS256'`).
  ///
  /// Only consulted when [verifySignedMetadata] is `true`.
  final List<String>? allowedSignedMetadataAlgorithms;

  /// Optional explicit issuer to compare the discovery document's `issuer`
  /// against (authoritative when set).
  ///
  /// When set it is ALSO the issuer an id_token's `iss` claim is validated
  /// against (OpenID Connect Core §3.1.3.7 step 2), overriding the advertised
  /// discovery `issuer`. This is the pin Microsoft Entra ID multi-tenant
  /// (`common`/`organizations`) RPs need: the OP advertises a non-substituted
  /// template issuer (`https://login.microsoftonline.com/{tenantid}/v2.0`) that
  /// never equals the concrete per-tenant `iss` a real id_token carries, so
  /// pinning the concrete tenant issuer here lets `validateUser` pass. When null
  /// (the default) the advertised `metadata.issuer` is used unchanged.
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

  /// How long a persisted (offline) JWKS may be served as a fallback when the
  /// OP's `jwks_uri` is unreachable, before it is treated as stale and
  /// id_token/logout_token verification fails-closed instead of trusting a
  /// possibly-rotated key.
  ///
  /// Threaded into [OidcJwksStoreLoader.staleCacheMaxAge] for every id_token
  /// and front-channel/logout-token verification. Lower it for
  /// high-assurance/FAPI deployments; raise it for longer offline tolerance.
  ///
  /// Defaults to `const Duration(days: 1)`. Per OpenID Connect Core 1.0 §10.1.1
  /// (Rotation of Asymmetric Signing Keys), an RP must obtain rotated keys and
  /// must not pin a stale/retired key set indefinitely.
  final Duration jwksCacheMaxAge;

  /// How long a persisted discovery document may be served from the
  /// [OidcStore] before it is treated as stale and re-fetched from the network.
  ///
  /// The document is persisted alongside a sidecar epoch-millis fetched-at
  /// timestamp (mirroring [OidcJwksStoreLoader]'s `::oidc_jwks_fetched_at`
  /// pattern, under the `::oidc_discovery_fetched_at` key). Within this window
  /// the manager skips the network `.well-known` fetch and uses the cached
  /// document; beyond it the document is refreshed (in the background under
  /// [OidcInitMode.cacheFirst], blocking under [OidcInitMode.blockingValidate]).
  /// If the refresh fails (e.g. offline), the stale cached document is still
  /// served (mirroring the JWKS loader's offline-fallback behavior).
  ///
  /// [Duration.zero]/negative disables the TTL cache — every `init()` re-fetches
  /// the document (the cached copy remains only as an offline fallback).
  ///
  /// Defaults to `const Duration(days: 1)`, matching [jwksCacheMaxAge] and the
  /// ~24h OP-metadata TTL used by MSAL. (oidc-client-ts caches OP metadata
  /// only in-memory for the session; this persists it across restarts.)
  final Duration discoveryDocumentMaxAge;

  /// Controls how [OidcUserManagerBase.init] restores a cached user.
  ///
  /// Defaults to [OidcInitMode.cacheFirst] — **this changes the default
  /// `init()` semantics** to restore the cached user locally (no network) and
  /// revalidate in the background. Set to [OidcInitMode.blockingValidate] to
  /// keep the previous behavior (block on the network until the cached token is
  /// fully re-verified before `init()` completes).
  ///
  /// [OidcInitMode.blockingValidate] is close to but NOT a byte-for-byte replica
  /// of the pre-1.0 `init()`: the discovery document is now served from the
  /// [discoveryDocumentMaxAge] TTL cache, so a `.well-known` fetch within that
  /// window is skipped. Combine it with `discoveryDocumentMaxAge: Duration.zero`
  /// to also restore the previous fetch-on-every-`init()` network behavior.
  final OidcInitMode initMode;

  /// An optional base discovery document whose members are merged UNDER the
  /// fetched (or cached) document — the fetched/cached values override the seed
  /// (matching oidc-client-ts `metadataSeed` semantics).
  ///
  /// Use this to supply endpoints an OP omits from its `.well-known` document,
  /// or to prime the manager before the first network fetch. The seed does not
  /// affect the eagerly-supplied [OidcUserManagerBase] (non-`.lazy`) constructor
  /// path, which is a full override and stays untouched. The seed is applied
  /// in-memory on every load and is never persisted.
  final OidcProviderMetadata? metadataSeed;

  /// Optional developer control over whether a token restored from the store
  /// during `init()` is accepted despite (or in the absence of) validation
  /// errors. See [OidcIsLoadedTokenAcceptableCallback].
  ///
  /// Defaults to `null` — the current behavior is preserved exactly.
  final OidcIsLoadedTokenAcceptableCallback? isLoadedTokenAcceptable;

  /// Optional developer control over whether a loaded-but-invalid token is
  /// removed from the store. See [OidcShouldRemoveInvalidTokenCallback].
  ///
  /// Defaults to `null` — the current behavior is preserved exactly (removed
  /// unless [supportOfflineAuth] is enabled).
  final OidcShouldRemoveInvalidTokenCallback? shouldRemoveInvalidToken;

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

  /// RFC 8705 §5: when `true`, backend requests resolve their endpoint through
  /// the authorization server's `mtls_endpoint_aliases` (falling back to the
  /// conventional endpoint when a given alias is absent) via
  /// [OidcProviderMetadata.resolveEndpoint].
  ///
  /// Defaults to `false`. This is NOT auto-inferred from the selected client
  /// authentication method: an mTLS-authenticating client only needs the alias
  /// endpoints when the server publishes them, and enabling it must be an
  /// explicit deployment decision (RFC 8705 §5).
  ///
  /// Note: establishing the certificate-bearing TLS transport itself is handled
  /// by the platform HTTP layer and is out of scope for this setting, which
  /// only governs endpoint selection.
  final bool useMtlsEndpointAliases;
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
