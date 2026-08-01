import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';

final _logger = Logger('OidcUserManagerBase');

/// The outcome of ONE refresh-token exchange driven through the shared
/// in-flight latch inside [OidcUserManagerBase].
///
/// Exactly one of `user` / `failureKind` is non-null, except for the neutral
/// all-null outcome returned when the manager was disposed mid-flight (which
/// every consumer treats as "do nothing"). `error` / `stackTrace` carry the
/// original failure so a caller that must THROW (rather than swallow, as the
/// automatic paths do) can preserve the diagnostics.
typedef _OidcRefreshOutcome = ({
  OidcUser? user,
  OidcTokenRefreshFailureKind? failureKind,
  Object? error,
  StackTrace? stackTrace,
});

/// Why a persisted client registration cannot simply be re-used as it is.
enum _OidcClientRegistrationStaleness {
  /// Usable as-is: it still matches what this build registers for and its
  /// `client_secret` (if any) is live.
  current,

  /// The staleness fingerprint no longer matches what this build would
  /// register for. A replacement must be issued, but the entry itself is still
  /// a working credential — it is the fallback when that replacement cannot be
  /// obtained.
  superseded,

  /// RFC 7591 §3.2.1 `client_secret_expires_at` is in the past. The OP has
  /// retired the credential, so this can never authenticate again and is never
  /// used as a fallback — a replacement must be registered.
  ///
  /// The entry is still left on disk: it is the only copy of the RFC 7592 §3
  /// `registration_access_token`, which is what an app needs to retire the
  /// OP-side client with [OidcEndpoints.deleteClientConfiguration], and a
  /// replacement overwrites it in place anyway.
  secretExpired,
}

/// A persisted client registration that could be parsed and converted, paired
/// with the credentials it converts to and why (if at all) it is stale.
///
/// Carrying the credentials keeps the conversion inside the read path's discard
/// logic, so a cached entry that cannot become credentials is dropped rather
/// than thrown on.
typedef _OidcCachedClientRegistration = ({
  OidcClientRegistrationResponse response,
  OidcClientAuthentication credentials,
  _OidcClientRegistrationStaleness staleness,
});

/// A [JsonWebKeyStore] that always offers the `oct` verification key of the
/// CURRENT `client_secret`, on top of everything registered in [inner].
///
/// RFC 7518 §3.2 (with OpenID Connect Core §16.19) makes the `client_secret`
/// octets the verification key of an HS*-signed id_token. Under RFC 7591
/// dynamic registration that secret is not known until `init()` has resolved
/// the registration, and [JsonWebKeyStore] offers no way to remove a key once
/// added — so a store built eagerly from the constructor-supplied seed would
/// leave a secret that was never registered able to verify id_tokens forever.
/// Deriving it at lookup time makes "only the credentials the manager is
/// actually running as can verify" hold BY CONSTRUCTION, instead of depending
/// on every site that replaces the credentials remembering to rebuild the
/// store.
class _OidcClientSecretKeyStore extends JsonWebKeyStore {
  _OidcClientSecretKeyStore({
    required this.inner,
    required this.currentClientSecret,
  });

  /// The store the app supplied (or the manager's own). Every mutation is
  /// forwarded here, so keys an app registers after construction keep working.
  final JsonWebKeyStore inner;

  final String? Function() currentClientSecret;

  String? _derivedFrom;
  JsonWebKeyStore? _derived;

  @override
  void addKey(JsonWebKey? key) => inner.addKey(key);

  @override
  void addKeySet(JsonWebKeySet keys) => inner.addKeySet(keys);

  @override
  void addKeySetUrl(Uri url) => inner.addKeySetUrl(url);

  @override
  Stream<JsonWebKey?> findJsonWebKeys(
    JoseHeader header,
    String operation,
  ) async* {
    final secret = currentClientSecret();
    // `alg: none` resolves to a single `null` candidate; letting both stores
    // answer it would merely duplicate that candidate.
    if (secret != null && header.algorithm != 'none') {
      yield* _keyStoreFor(secret).findJsonWebKeys(header, operation);
    }
    yield* inner.findJsonWebKeys(header, operation);
  }

  JsonWebKeyStore _keyStoreFor(String secret) {
    final cached = _derived;
    if (cached != null && secret == _derivedFrom) {
      return cached;
    }
    _derivedFrom = secret;
    return _derived = JsonWebKeyStore()
      ..addKey(
        JsonWebKey.fromJson({
          'kty': 'oct',
          'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
          'use': 'sig',
        }),
      );
  }
}

/// This class manages a single user's authentication status.
///
/// It's preferred to maintain only a single instance of this class.
abstract class OidcUserManagerBase {
  /// Create a new UserManager from [OidcProviderMetadata].
  ///
  /// if [discoveryDocument] is not available,
  /// consider using the [OidcUserManagerBase.lazy] constructor.
  OidcUserManagerBase({
    required OidcProviderMetadata discoveryDocument,
    required OidcClientAuthentication clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
    this.id,
  }) : discoveryDocumentUri = null,
       currentDiscoveryDocument = discoveryDocument,
       _clientCredentials = clientCredentials,
       _keyStore = keyStore;

  /// Create a new UserManager that delays getting the discovery document until
  /// [init] is called.
  OidcUserManagerBase.lazy({
    required Uri this.discoveryDocumentUri,
    required OidcClientAuthentication clientCredentials,
    required this.store,
    required this.settings,
    this.httpClient,
    JsonWebKeyStore? keyStore,
    this.id,
  }) : _clientCredentials = clientCredentials,
       _keyStore = keyStore;

  bool get isWeb;

  final String? id;

  OidcClientAuthentication _clientCredentials;

  /// The client authentication information.
  ///
  /// When [OidcUserManagerSettings.dynamicClientRegistration] is enabled, this
  /// is REPLACED during [init] by the credentials derived from the registration
  /// response; the constructor-supplied value is only the pre-registration seed.
  OidcClientAuthentication get clientCredentials => _clientCredentials;

  @protected
  set clientCredentials(OidcClientAuthentication value) =>
      _clientCredentials = value;

  /// The http client to use when sending requests
  final http.Client? httpClient;

  /// The store responsible for setting/getting cached values.
  final OidcStore store;

  /// The id_token verification options.
  JsonWebKeyStore? _keyStore;

  /// The key store id_token signatures are verified against.
  ///
  /// This wraps the store handed to the constructor (or a fresh one): the
  /// symmetric HS* key is derived from [clientCredentials] on every lookup, so
  /// the RFC 7591 registration applied during [init] retires the seed's key
  /// immediately, with no ordering dependency between [setupKeyStore] and
  /// [ensureClientRegistration]. See [_OidcClientSecretKeyStore].
  late final JsonWebKeyStore keyStore = _OidcClientSecretKeyStore(
    inner: _keyStore ??= JsonWebKeyStore(),
    currentClientSecret: () => clientCredentials.clientSecret,
  );

  OidcDPoPManager? _dpopManager;

  /// The DPoP (RFC 9449) proof manager when DPoP is enabled
  /// (`settings.dpop != null`); otherwise null.
  ///
  /// Lazily created and reused for the manager's lifetime so that refresh
  /// proofs are signed with the SAME key as the original token request (the
  /// refresh token is sender-constrained to it).
  @protected
  OidcDPoPManager? get dpopManager {
    final dpopSettings = settings.dpop;
    if (dpopSettings == null) {
      return null;
    }
    return _dpopManager ??= OidcDPoPManager.generate(dpopSettings);
  }

  /// Mints an RFC 9449 DPoP proof JWT for a protected-resource request, or
  /// `null` when DPoP is not enabled (`settings.dpop == null`) or there is no
  /// access token to bind the `ath` claim to.
  ///
  /// Without this, enabling [OidcUserManagerSettings.dpop] sender-constrains the
  /// token but leaves the application unable to prove possession on its own API
  /// calls — it would have to fall back to a plain `Bearer` header and silently
  /// discard the guarantee. Send the pair instead:
  ///
  /// ```dart
  /// final accessToken = await manager.getAccessToken();
  /// final proof = await manager.createDPoPProof(uri: uri, method: 'GET');
  /// final headers = {
  ///   'Authorization': proof == null
  ///       ? 'Bearer $accessToken'
  ///       : 'DPoP $accessToken',
  ///   if (proof != null) 'DPoP': proof,
  /// };
  /// ```
  ///
  /// If the resource server answers `401` with `error="use_dpop_nonce"` and a
  /// `DPoP-Nonce` header, feed that nonce back with [cacheDPoPNonce] and mint a
  /// fresh proof for a single retry.
  ///
  /// [uri] is the full request URI (RFC 9449 §4.2 `htu`; query and fragment are
  /// stripped for you), [method] the HTTP method (`htm`). [accessToken]
  /// overrides the token bound by the `ath` claim; it defaults to the current
  /// user's access token, so pass whatever [getAccessToken] returned to be sure
  /// the proof and the header agree after a refresh.
  Future<String?> createDPoPProof({
    required Uri uri,
    String method = 'GET',
    String? accessToken,
  }) async {
    final manager = dpopManager;
    if (manager == null) {
      return null;
    }
    final boundAccessToken = accessToken ?? currentUser?.token.accessToken;
    if (boundAccessToken == null) {
      return null;
    }
    return manager.createResourceProof(
      method: method,
      uri: uri,
      accessToken: boundAccessToken,
    );
  }

  /// Caches a `DPoP-Nonce` supplied by a resource server so the next proof
  /// minted by [createDPoPProof] for [uri] carries it (RFC 9449 §8).
  ///
  /// No-op when DPoP is not enabled. Nonces are cached per endpoint, because the
  /// authorization server and each resource server issue independent ones.
  void cacheDPoPNonce(Uri uri, String nonce) {
    dpopManager?.setNonceFor(uri, nonce);
  }

  /// The RFC 7638 thumbprint of this session's DPoP proof key — the value the
  /// authorization server binds the token to as `cnf.jkt` — or `null` when DPoP
  /// is not enabled.
  ///
  /// Useful for asserting that an issued access token is actually bound to this
  /// manager's key.
  String? get dpopThumbprint => dpopManager?.thumbprint;

  /// The settings used in this manager.
  final OidcUserManagerSettings settings;

  @protected
  final userSubject = OidcValueStream<OidcUser?>(null);

  @protected
  final eventsController = StreamController<OidcEvent>.broadcast();

  /// Whether [dispose] has been called on this manager.
  ///
  /// Async work started before disposal — most notably an in-flight automatic
  /// refresh whose (possibly delayed) token response only lands after
  /// [dispose] — checks this so its completion becomes a COMPLETE no-op: no
  /// event, no user mutation, no `forgetUser`. Without it a refresh that
  /// outlives the manager threw `Bad state: Cannot add new events after
  /// calling close` from [eventsController] and mutated a torn-down manager.
  bool _isDisposed = false;

  /// Whether [dispose] has been called on this manager.
  bool get isDisposed => _isDisposed;

  /// Emits [event] on [eventsController], tolerating a closed controller.
  ///
  /// Mirrors [OidcValueStream.add]'s documented close-tolerance: an emit that
  /// races [dispose] (e.g. from an async refresh that outlived the manager) is
  /// ignored rather than throwing `Bad state: Cannot add new events after
  /// calling close`. All event emissions on this class route through here.
  @protected
  void emitEvent(OidcEvent event) {
    if (eventsController.isClosed) {
      logger.finest(
        'Ignoring ${event.runtimeType} emitted after the manager was disposed.',
      );
      return;
    }
    eventsController.add(event);
  }

  /// Tracks when offline mode was entered, null if not in offline mode
  DateTime? offlineModeStartedAt;

  /// Gets the last time the manager successfully communicated with the server.
  /// This can be useful for displaying "Last synced" information in the UI.
  /// Returns null if no successful server contact has been made yet.
  DateTime? lastSuccessfulServerContact;

  /// Counter for consecutive refresh failures
  int consecutiveRefreshFailures = 0;

  /// #154: the in-flight refresh, shared between [handleTokenExpiring],
  /// [handleTokenExpired] and (#421) [getAccessToken] / [signInSilent]. On
  /// resume both the `expiring` and `expired` timers can be overdue and fire
  /// together; latching every handler onto this single future guarantees the
  /// refresh token is exchanged exactly once (no double refresh) and lets the
  /// expired handler defer its forget decision to the refresh outcome instead
  /// of racing it.
  ///
  /// #421: the silent-acquisition entry points join the SAME latch, so N
  /// parallel API calls that all discover a stale access token perform ONE
  /// token exchange between them. That matters against an OP that rotates
  /// refresh tokens — required for public clients by RFC 9700 §2.2.2 ("Refresh
  /// tokens for public clients MUST be sender-constrained or use refresh token
  /// rotation") — because rotation invalidates the previous refresh token on
  /// every exchange, so a second concurrent exchange presents an invalidated
  /// token and the AS "will revoke the active refresh token" (§4.14.2),
  /// forcing a fresh authorization grant.
  ///
  /// `null` when no refresh is currently running.
  Future<_OidcRefreshOutcome>? _autoRefreshInFlight;

  /// #201: while a cache-first background revalidation owns the refresh of the
  /// just-restored (possibly already-expired) cached token, the expiry-driven
  /// auto-refresh ([handleTokenExpiring] / [handleTokenExpired]) is suppressed.
  ///
  /// On a cache-first cold start the restored expired user is surfaced through
  /// [userChanges], which arms the token-events timers; those fire immediately
  /// for an expired token and would kick off `_autoRefresh` — a SECOND
  /// `/token` exchange racing the background revalidation's own
  /// `startupLoad` refresh. Two concurrent refresh-token exchanges can trip an
  /// OP's RFC 9700 refresh-rotation reuse detection and revoke the whole token
  /// family (a real logout on an ordinary reopen). This flag lets the single
  /// background pass own that first refresh; it is cleared once the pass
  /// settles, after which normal on-expiry auto-refresh resumes.
  bool _cacheFirstRevalidationInFlight = false;

  /// The [_scheduleBackgroundRevalidation] future currently running, non-null
  /// for exactly the same window as [_cacheFirstRevalidationInFlight] (both are
  /// set together in [_tryCacheFirstInit] and cleared together in
  /// [_scheduleBackgroundRevalidation]'s `finally`).
  ///
  /// #421/#422/#423: [handleTokenExpiring] / [handleTokenExpired] are gated on
  /// the bool above, but [getAccessToken] and [signInSilent] are NOT — they
  /// join the SAME shared [_autoRefreshInFlight] latch used by the expiry
  /// timers and the plain manual refresh, which the background revalidation's
  /// refresh (driven through [loadCachedTokens] -> the raw, un-coalesced
  /// [_refreshToken]) never populates. So while a background revalidation is
  /// running, [getAccessToken] / [signInSilent] would see no in-flight
  /// [_autoRefreshInFlight] and start a SECOND, competing `/token` exchange
  /// that presents the SAME refresh token the revalidation is already
  /// exchanging — exactly the RFC 9700 §4.14.2 rotation-reuse hazard
  /// [_cacheFirstRevalidationInFlight] exists to prevent for the timer paths.
  /// [_joinCacheFirstRevalidationIfInFlight] closes that gap: those two entry
  /// points await this future (joining the single in-flight revalidation and
  /// reusing whatever it concludes — refreshed, retained, or forgotten user)
  /// instead of starting their own exchange.
  Future<void>? _cacheFirstRevalidationFuture;

  /// Awaits an in-flight cache-first background revalidation
  /// ([_tryCacheFirstInit] / [_scheduleBackgroundRevalidation]), if one is
  /// currently running, so the caller joins its outcome instead of starting a
  /// second, competing refresh-token exchange.
  ///
  /// A no-op when no revalidation is in flight — including when one has
  /// already settled by the time this is called (the captured future is
  /// simply already-completed) — and safe to call after [dispose] (the
  /// revalidation future never throws; see [_scheduleBackgroundRevalidation]'s
  /// own all-swallowing `try`/`catch`, mirrored by [loadCachedTokens] and
  /// [_refreshToken]). That guarantee depends on the `try` wrapping the
  /// `await initFuture` at the very top of
  /// [_scheduleBackgroundRevalidation] too, not just the revalidation logic
  /// after it — `init()` itself can fail (e.g. a subclass's
  /// [attachLifecycleListeners] override throwing synchronously), and a
  /// failed `initFuture` must still hit that `catch`/`finally` like any other
  /// error, or this future would stay permanently errored and every future
  /// join would rethrow it forever.
  ///
  /// Reads [_cacheFirstRevalidationFuture] into a local variable synchronously
  /// (no `await` before the read) so a concurrent settle-and-clear by
  /// [_scheduleBackgroundRevalidation]'s `finally` block can never race this
  /// check: either this call observes the field before it is nulled (and
  /// awaits the real future) or after (and no-ops), never a torn read.
  ///
  /// Returns `true` when an actual in-flight revalidation was joined (as
  /// opposed to a no-op because none was running), so a caller can tell "a
  /// renewal attempt equivalent to mine just happened" apart from "nothing
  /// was in flight, proceed as usual".
  ///
  /// Private (not `@protected`): this is plumbing internal to
  /// [getAccessToken] / [signInSilent], not something a platform subclass
  /// needs to override or call — kept off the extendable surface deliberately
  /// (see the source-breaking-for-subclassers advisory on #421-424).
  Future<bool> _joinCacheFirstRevalidationIfInFlight() async {
    final revalidation = _cacheFirstRevalidationFuture;
    if (revalidation == null) {
      return false;
    }
    await revalidation;
    return true;
  }

  /// Returns true if the manager is currently in offline mode.
  bool get isInOfflineMode => offlineModeStartedAt != null;

  @protected
  Logger get logger => _logger;

  /// Gets a stream that reflects the current data of the user.
  Stream<OidcUser?> userChanges() => userSubject.stream;

  /// Gets a stream of events related to the current manager.
  Stream<OidcEvent> events() => eventsController.stream;

  /// Native browser-layer events (`OidcNativeBrowserEvent` subtypes) to forward
  /// into [events]. The platform manager overrides this to surface Custom Tabs
  /// / `ASWebAuthenticationSession` observability; empty by default (e.g. on
  /// web/desktop).
  @protected
  Stream<OidcEvent> listenToNativeBrowserEvents() => const Stream.empty();

  /// The current authenticated user.
  OidcUser? get currentUser => userSubject.value;

  @protected
  Never logAndThrow(
    String message, {
    Map<String, dynamic> extra = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final ex = OidcException(
      message,
      extra: extra,
      internalException: error,
      internalStackTrace: stackTrace,
    );
    logger.severe(message, error ?? ex, stackTrace ?? StackTrace.current);
    throw ex;
  }

  @protected
  void ensureInit() {
    if (!didInit) {
      logAndThrow(
        "discoveryDocument hasn't been fetched yet, "
        'please call init() first.',
      );
    }
  }

  @protected
  Map<String, dynamic> getSerializableOptions(
    OidcPlatformSpecificOptions options,
  ) => {
    if (isWeb) 'webLaunchMode': options.web.navigationMode.name,
  };

  /// Returns the authorization response.
  /// may throw an [OidcException].
  @protected
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  );

  /// Returns the end session response for an RP initiated logout request.
  /// may throw an [OidcException].
  @protected
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  );

  @protected
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  );

  /// Listens to incoming front channel logout requests.
  /// returns an empty stream on non-supported platforms.
  @protected
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  );

  /// starts monitoring the session status.
  @protected
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  });

  @protected
  OidcPlatformSpecificOptions getPlatformOptions([
    OidcPlatformSpecificOptions? optionsOverride,
  ]) {
    return optionsOverride ??
        settings.options ??
        const OidcPlatformSpecificOptions();
  }

  /// Attempts to login the user via the AuthorizationCodeFlow.
  ///
  /// [originalUri] is the uri you want to be redirected to after authentication is done,
  /// if null, it defaults to `redirectUri`.
  Future<OidcUser?> loginAuthorizationCodeFlow({
    OidcProviderMetadata? discoveryDocumentOverride,
    Uri? redirectUriOverride,
    Uri? originalUri,
    List<String>? scopeOverride,
    List<String>? promptOverride,
    List<String>? uiLocalesOverride,
    String? displayOverride,
    List<String>? acrValuesOverride,
    dynamic extraStateData,
    bool includeIdTokenHintFromCurrentUser = true,
    String? idTokenHintOverride,
    String? loginHint,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
    Map<String, dynamic>? extraTokenParameters,
    Map<String, String>? extraTokenHeaders,
    OidcPlatformSpecificOptions? options,
    List<String>? responseTypeOverride,
  }) async {
    ensureInit();
    // Taken once, up front: the authorization request below is built from —
    // and persisted against — this `client_id`, and the code it returns is
    // exchanged with these same credentials in [tryGetAuthResponse]. Under
    // dynamic client registration this is the identity [init] resolved and it
    // does not move for the manager's lifetime.
    final credentials = clientCredentials;
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);
    // RFC 9126 Pushed Authorization Requests: decide up front whether this flow
    // pushes, because that selects where the DPoP authorization-code binding
    // (`dpop_jkt`, RFC 9449 §10) is emitted — on the direct authorization
    // request (below, via `prepareAuthorizationCodeFlowRequest`) or on the
    // back-channel PAR request body. The two are mutually exclusive so the code
    // is never double-bound.
    final shouldPushAuthorizationRequest =
        switch (settings.pushedAuthorizationRequestsMode) {
          OidcPushedAuthorizationRequestsMode.never => false,
          OidcPushedAuthorizationRequestsMode.always => true,
          OidcPushedAuthorizationRequestsMode.auto =>
            discoveryDocument.requirePushedAuthorizationRequestsOrDefault,
        };
    final dpop = dpopManager;
    final simpleReq = OidcSimpleAuthorizationCodeFlowRequest(
      clientId: credentials.clientId,
      originalUri: originalUri,
      redirectUri: redirectUriOverride ?? effectiveRedirectUri,
      scope: scopeOverride ?? effectiveScope,
      prompt: promptOverride ?? settings.prompt,
      display: displayOverride ?? settings.display,
      extraStateData: extraStateData,
      uiLocales: uiLocalesOverride ?? settings.uiLocales,
      acrValues: acrValuesOverride ?? settings.acrValues,
      idTokenHint:
          idTokenHintOverride ??
          (includeIdTokenHintFromCurrentUser ? currentUser?.idToken : null),
      loginHint: loginHint,
      extraTokenHeaders: {
        ...?settings.extraTokenHeaders,
        ...?extraTokenHeaders,
      },
      extraTokenParameters: {
        ...?settings.extraTokenParameters,
        ...?extraTokenParameters,
      },
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
      resource: settings.resource,
      requestObjectSettings: settings.requestObject,
      options: getSerializableOptions(options),
      managerId: id,
    );
    // this function adds state, state data, nonce to the store
    // the state/state data is only until we get a response (success or fail).
    // the nonce is until the user logs out.
    final requestContainer =
        await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
          input: simpleReq,
          metadata: discoveryDocument,
          store: store,
          // RFC 9449 §10: when DPoP is enabled and this flow does NOT use PAR,
          // bind the authorization code to the DPoP key by carrying its
          // thumbprint as `dpop_jkt` on the (direct) authorization request. The
          // PAR path binds via the pushed request body below instead, so exactly
          // one of the two branches emits it.
          dpopJkt:
              !shouldPushAuthorizationRequest &&
                  dpop != null &&
                  dpop.settings.bindAuthorizationCode
              ? dpop.thumbprint
              : null,
        );
    // Hybrid flow (OIDC Core §3.3): the request differs from a plain code flow
    // only in `response_type`. Everything the exchange needs -- PKCE verifier,
    // nonce, state, and the DPoP binding above -- was just prepared and stored
    // identically, so overriding the response type here (rather than building a
    // parallel request path) keeps hybrid on exactly the same machinery.
    //
    // Applied BEFORE the PAR push below, so a pushed hybrid request carries the
    // real response type instead of `code`.
    if (responseTypeOverride != null) {
      requestContainer.request.responseType = responseTypeOverride;
    }
    // RFC 9126 Pushed Authorization Requests: when enabled, POST the prepared
    // request to the PAR endpoint (back channel, authenticated) and continue
    // the front channel by reference (`request_uri`). state/nonce/PKCE were
    // already persisted by prepareAuthorizationCodeFlowRequest above, so local
    // validation is unchanged (RFC 9126 §6).
    if (shouldPushAuthorizationRequest) {
      final parEndpoint = discoveryDocument.pushedAuthorizationRequestEndpoint;
      if (parEndpoint == null) {
        logAndThrow(
          'Pushed Authorization Requests are required/enabled but the '
          'authorization server did not advertise a '
          '`pushed_authorization_request_endpoint`.',
        );
      }
      final parResponse = await OidcEndpoints.pushAuthorizationRequest(
        pushedAuthorizationRequestEndpoint: parEndpoint,
        request: requestContainer.request,
        credentials: credentials,
        client: httpClient,
        // RFC 9449 §10: bind the authorization code to the DPoP key by sending
        // its thumbprint as `dpop_jkt` on the (back-channel) PAR request.
        extraBodyFields: dpop != null && dpop.settings.bindAuthorizationCode
            ? {OidcConstants_AuthParameters.dpopJkt: dpop.thumbprint}
            : null,
      );
      // Continue the authorization request by reference; generateUri now emits
      // only `client_id` + `request_uri` (RFC 9126 §4).
      requestContainer.request.requestUri = parResponse.requestUri;
    }
    return tryGetAuthResponse(
      grantType: OidcConstants_GrantType.authorizationCode,
      request: requestContainer.request,
      options: options,
      metadata: discoveryDocument,
      prep: prep,
    );
  }

  /// Attempts to login the user via resource owner's credentials.
  Future<OidcUser?> loginPassword({
    required String username,
    required String password,
    List<String>? scopeOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
    Map<String, String>? extraTokenHeaders,
  }) async {
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final credentials = clientCredentials;
    final tokenResp = await (settings.hooks?.token).execute(
      request: OidcTokenHookRequest(
        metadata: discoveryDocument,
        tokenEndpoint: discoveryDocument.tokenEndpoint!,
        request: OidcTokenRequest.password(
          username: username,
          password: password,
          scope: scopeOverride ?? effectiveScope,
          clientId: credentials.clientId,
          extra: {...?settings.extraTokenParameters, ...?extraBodyFields},
        ),
        credentials: credentials,
        headers: {
          ...?settings.extraTokenHeaders,
          ...?extraTokenHeaders,
        },
        client: httpClient,
        options: settings.options,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.token(
          tokenEndpoint: hookRequest.tokenEndpoint,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
          dpopManager: dpopManager,
          request: hookRequest.request,
          client: hookRequest.client,
        );
      },
    );

    return createUserFromToken(
      token: OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
        sessionState: null,
      ),
      attributes: null,
      userInfo: null,
      nonce: null,
      metadata: discoveryDocument,
    );
  }

  /// Attempts to login the user via the OAuth2 Device Authorization Grant.
  ///
  /// This adapts RFC 8628.
  ///
  /// The [onVerification] callback can be used by UIs/CLIs to display the
  /// verification URI/user code to the end-user.
  Future<OidcUser?> loginDeviceCodeFlow({
    List<String>? scopeOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraTokenParameters,
    Map<String, String>? extraTokenHeaders,
    FutureOr<void> Function(OidcDeviceAuthorizationResponse response)?
    onVerification,
  }) async {
    ensureInit();

    final metadata = discoveryDocumentOverride ?? discoveryDocument;
    final tokenEndpoint = metadata.tokenEndpoint;
    if (tokenEndpoint == null) {
      logAndThrow("This provider doesn't provide a token endpoint");
    }

    final deviceAuthEndpointValue = metadata
        .src[OidcConstants_ProviderMetadata.deviceAuthorizationEndpoint];
    if (deviceAuthEndpointValue == null) {
      logAndThrow(
        "This provider doesn't provide the device_authorization_endpoint",
      );
    }
    final deviceAuthorizationEndpoint = Uri.parse(
      deviceAuthEndpointValue.toString(),
    );

    final credentials = clientCredentials;
    final deviceResp = await OidcEndpoints.deviceAuthorization(
      deviceAuthorizationEndpoint: deviceAuthorizationEndpoint,
      credentials: credentials,
      request: OidcDeviceAuthorizationRequest(
        scope: scopeOverride ?? effectiveScope,
      ),
      client: httpClient,
    );

    await onVerification?.call(deviceResp);

    final deadline = clock.now().add(deviceResp.expiresIn);
    var pollInterval =
        deviceResp.interval ??
        OidcConstants_DeviceAuthorizationPolling.defaultInterval;

    while (clock.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      try {
        final pollCredentials = clientCredentials;
        final tokenResp = await (settings.hooks?.token).execute(
          request: OidcTokenHookRequest(
            metadata: metadata,
            tokenEndpoint: tokenEndpoint,
            request: OidcTokenRequest.deviceCode(
              deviceCode: deviceResp.deviceCode,
              clientId: pollCredentials.clientId,
              scope: scopeOverride ?? effectiveScope,
              extra: {
                ...?settings.extraTokenParameters,
                ...?extraTokenParameters,
              },
            ),
            credentials: pollCredentials,
            headers: {
              ...?settings.extraTokenHeaders,
              ...?extraTokenHeaders,
            },
            client: httpClient,
            options: settings.options,
          ),
          defaultExecution: (hookRequest) {
            return OidcEndpoints.token(
              tokenEndpoint: hookRequest.tokenEndpoint,
              credentials: hookRequest.credentials,
              headers: hookRequest.headers,
              dpopManager: dpopManager,
              request: hookRequest.request,
              client: hookRequest.client,
            );
          },
        );

        final token = OidcToken.fromResponse(
          tokenResp,
          overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
          sessionState: tokenResp.sessionState,
        );

        // If an id_token is not returned, we cannot construct an OIDC user.
        if (!token.isOidc) {
          throw const OidcException(
            "Server didn't return the id_token. Ensure `openid` scope is included.",
          );
        }

        return createUserFromToken(
          token: token,
          nonce: null,
          attributes: null,
          userInfo: null,
          metadata: metadata,
        );
      } on OidcException catch (e) {
        final code = e.errorResponse?.error;
        switch (code) {
          case OidcConstants_DeviceAuthorizationErrors.authorizationPending:
            continue;
          case OidcConstants_DeviceAuthorizationErrors.slowDown:
            pollInterval +=
                OidcConstants_DeviceAuthorizationPolling.slowDownIncrement;
            continue;
          case OidcConstants_DeviceAuthorizationErrors.accessDenied:
          case OidcConstants_DeviceAuthorizationErrors.expiredToken:
            return null;
          default:
            rethrow;
        }
      }
    }

    return null;
  }

  @protected
  Future<OidcUser?> tryGetAuthResponse({
    required OidcAuthorizeRequest request,
    required String grantType,
    required OidcPlatformSpecificOptions options,
    required OidcProviderMetadata metadata,
    required Map<String, dynamic> prep,
  }) async {
    try {
      final response = await (settings.hooks?.authorization).execute(
        defaultExecution: (request) {
          return getAuthorizationResponse(
            request.metadata,
            request.request,
            request.options,
            request.preparationResult,
          );
        },
        request: OidcAuthorizationHookRequest(
          metadata: metadata,
          request: request,
          options: options,
          preparationResult: prep,
        ),
      );
      if (response == null) {
        return null;
      }
      final state = response.state;

      //since we already have a response, remove it from the store.
      if (state != null) {
        await store.setStateResponseData(state: state, stateData: null);
      }
      return await handleSuccessfulAuthResponse(
        response: response,
        grantType: grantType,
        metadata: metadata,
      );
    } on OidcException catch (e) {
      //failed to authorize.
      final response = e.errorResponse;
      if (response == null) {
        rethrow;
      }
      //if we have a response, remove it from the store.
      final state = response.state;
      if (state != null) {
        await store.setStateResponseData(state: state, stateData: null);
      }
      // RFC 9207 mix-up attack defense, mirroring handleSuccessfulAuthResponse:
      // an authorization ERROR response is just as capable of originating
      // from the wrong AS as a successful one, so it gets the same `iss`
      // check before the original server-error is allowed to propagate.
      final responseIss = response.iss;
      final expectedIssuer = metadata.issuer;
      // §2.4: a client MUST reject a response that omits `iss` when the AS
      // advertises support via `authorization_response_iss_parameter_supported`.
      if (metadata.authorizationResponseIssParameterSupportedOrDefault &&
          responseIss == null) {
        logAndThrow(
          'The authorization server advertises '
          '`authorization_response_iss_parameter_supported` but the '
          'authorization error response is missing the `iss` parameter '
          '(RFC 9207 §2.4); refusing as a possible mix-up attack.',
        );
      }
      // When `iss` is present it MUST match the provider issuer (string compare,
      // not Uri normalization — RFC 9207 §2.4). A no-op for OPs that omit it and
      // do not advertise support.
      if (responseIss != null &&
          expectedIssuer != null &&
          responseIss.toString() != expectedIssuer.toString()) {
        logAndThrow(
          'Authorization error response `iss` ($responseIss) does not '
          'match the provider issuer ($expectedIssuer); possible mix-up '
          'attack (RFC 9207).',
        );
      }
      rethrow;
    }
  }

  /// Logs the user in with the Hybrid flow (OpenID Connect Core §3.3).
  ///
  /// The authorization endpoint returns an id_token in the front channel
  /// ALONGSIDE the code. That id_token is validated before the exchange --
  /// `nonce` must match, `c_hash` must bind the returned code, and `at_hash`
  /// (when present) must bind the front-channel access_token -- and only then
  /// is the code redeemed. The user is built from the TOKEN ENDPOINT response;
  /// the front-channel tokens are a binding check, never the final credentials.
  ///
  /// This is not the implicit flow and is not deprecated: the code exchange
  /// still happens over the back channel with PKCE, and the credentials this
  /// method RETURNS always come from the token endpoint.
  ///
  /// That is not the same as "no token crosses the front channel". `code
  /// token` and `code id_token token` put an access token in the redirect by
  /// definition (§3.3.2.1), where it can reach browser history, `Referer`
  /// headers and proxy logs. `at_hash` binding is enforced when it is present,
  /// but if you want nothing but the code in the front channel, use
  /// `code id_token` -- the default here. [loginImplicitFlow] by contrast keeps
  /// the front-channel tokens and never calls the token endpoint.
  ///
  /// [responseType] must contain `code`; that is what makes a response hybrid
  /// rather than implicit. Valid values are `code id_token`, `code token`, and
  /// `code id_token token` (§3.3.2.1). Passing one without `code` is rejected,
  /// because it would silently degrade to implicit -- the exact confusion this
  /// method exists to remove.
  Future<OidcUser?> loginHybridFlow({
    List<String> responseType = const [
      OidcConstants_AuthorizationEndpoint_ResponseType.code,
      OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
    ],
    OidcProviderMetadata? discoveryDocumentOverride,
    Uri? redirectUriOverride,
    Uri? originalUri,
    List<String>? scopeOverride,
    List<String>? promptOverride,
    List<String>? uiLocalesOverride,
    String? displayOverride,
    List<String>? acrValuesOverride,
    dynamic extraStateData,
    bool includeIdTokenHintFromCurrentUser = true,
    String? idTokenHintOverride,
    String? loginHint,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
    Map<String, dynamic>? extraTokenParameters,
    Map<String, String>? extraTokenHeaders,
    OidcPlatformSpecificOptions? options,
  }) {
    const idToken = OidcConstants_AuthorizationEndpoint_ResponseType.idToken;
    const token = OidcConstants_AuthorizationEndpoint_ResponseType.token;
    if (!responseType.contains(
      OidcConstants_AuthorizationEndpoint_ResponseType.code,
    )) {
      logAndThrow(
        'Hybrid flow requires `code` in response_type (OIDC Core §3.3.2.1); '
        'got "${responseType.join(' ')}". Without it no code is returned, '
        'there is nothing to exchange, and the flow is implicit -- use '
        'loginImplicitFlow if that is what you meant.',
      );
    }
    // `code` alone is a plain authorization-code flow, not hybrid: nothing
    // comes back in the front channel, so validateFrontChannelIdToken has
    // nothing to check and this method silently becomes
    // loginAuthorizationCodeFlow. Rejecting it closes the degradation the
    // branch above guards in the other direction.
    if (!responseType.contains(idToken) && !responseType.contains(token)) {
      logAndThrow(
        'Hybrid flow requires `id_token` and/or `token` alongside `code` '
        '(OIDC Core §3.3.2.1); got "${responseType.join(' ')}". With `code` '
        'alone nothing is returned in the front channel and this is a plain '
        'authorization-code flow -- call loginAuthorizationCodeFlow instead.',
      );
    }
    return loginAuthorizationCodeFlow(
      discoveryDocumentOverride: discoveryDocumentOverride,
      redirectUriOverride: redirectUriOverride,
      originalUri: originalUri,
      scopeOverride: scopeOverride,
      promptOverride: promptOverride,
      uiLocalesOverride: uiLocalesOverride,
      displayOverride: displayOverride,
      acrValuesOverride: acrValuesOverride,
      extraStateData: extraStateData,
      includeIdTokenHintFromCurrentUser: includeIdTokenHintFromCurrentUser,
      idTokenHintOverride: idTokenHintOverride,
      loginHint: loginHint,
      maxAgeOverride: maxAgeOverride,
      extraParameters: extraParameters,
      extraTokenParameters: extraTokenParameters,
      extraTokenHeaders: extraTokenHeaders,
      options: options,
      responseTypeOverride: responseType,
    );
  }

  ///
  @Deprecated('Implicit flow is deprecated due to security reasons.')
  Future<OidcUser?> loginImplicitFlow({
    required List<String> responseType,
    OidcProviderMetadata? discoveryDocumentOverride,
    Uri? redirectUriOverride,
    Uri? originalUri,
    List<String>? scopeOverride,
    List<String>? promptOverride,
    List<String>? uiLocalesOverride,
    String? displayOverride,
    List<String>? acrValuesOverride,
    dynamic extraStateData,
    bool includeIdTokenHintFromCurrentUser = true,
    String? idTokenHintOverride,
    String? loginHint,
    Duration? maxAgeOverride,
    Map<String, dynamic>? extraParameters,
    OidcPlatformSpecificOptions? options,
  }) async {
    ensureInit();
    final doc = discoveryDocumentOverride ?? discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);

    final simpleReq = OidcSimpleImplicitFlowRequest(
      responseType: responseType,
      clientId: clientCredentials.clientId,
      originalUri: originalUri,
      redirectUri: redirectUriOverride ?? effectiveRedirectUri,
      scope: scopeOverride ?? effectiveScope,
      prompt: promptOverride ?? settings.prompt,
      display: displayOverride ?? settings.display,
      extraStateData: extraStateData,
      uiLocales: uiLocalesOverride ?? settings.uiLocales,
      acrValues: acrValuesOverride ?? settings.acrValues,
      idTokenHint:
          idTokenHintOverride ??
          (includeIdTokenHintFromCurrentUser ? currentUser?.idToken : null),
      loginHint: loginHint,
      extraParameters: {
        ...?settings.extraAuthenticationParameters,
        ...?extraParameters,
      },
      maxAge: maxAgeOverride ?? settings.maxAge,
      options: getSerializableOptions(options),
    );
    final request = await OidcEndpoints.prepareImplicitFlowRequest(
      input: simpleReq,
      metadata: doc,
      store: store,
    );
    return tryGetAuthResponse(
      request: request,
      grantType: OidcConstants_GrantType.implicit,
      options: options,
      metadata: doc,
      prep: prep,
    );
  }

  /// This simply forgets the current user.
  ///
  /// this adds a new event to [userChanges] with value `null`, and also clears
  /// the store namespaces: state, session, secureTokens.
  ///
  /// NOTE: this is different than [logout], since this method doesn't initiate
  /// any logout flows.
  Future<void> forgetUser() async {
    await cleanUpStore(
      toDelete: {
        OidcStoreNamespace.secureTokens,
      },
      // The dynamic client registration is app-instance identity, not user
      // identity: forgetting the user (including on a terminal refresh failure)
      // must not orphan the client at the OP and mint a fresh one on the next
      // launch.
      preserveKeyPrefixes: const {clientRegistrationKeyPrefix},
    );
    final currentUser = this.currentUser;
    if (currentUser != null) {
      emitEvent(
        OidcPreLogoutEvent.now(currentUser: currentUser),
      );
      userSubject.add(null);
    }
  }

  /// Revokes the current user's access token.
  ///
  /// This method sends a revocation request to the authorization server's
  /// revocation endpoint to invalidate the access token. The token will no
  /// longer be valid for accessing protected resources.
  ///
  /// **Parameters:**
  /// - [discoveryDocumentOverride]: Optional discovery document to use instead
  ///   of the default one
  /// - [options]: Platform-specific options for the revocation request
  /// - [forgetUser]: Whether to forget the current user after successful
  ///   revocation (defaults to `true`)
  /// - [overrideAccessToken]: Specific access token to revoke instead of the
  ///   current user's token
  /// - [revocationEndpointOverride]: Custom revocation endpoint URL to use
  /// - [extraBodyFields]: Additional fields to include in the revocation request body
  /// - [headers]: Additional HTTP headers to include in the request
  ///
  /// **Behavior:**
  /// - Returns early if no current user exists
  /// - Returns early if no access token is available to revoke
  /// - Returns early if the authorization server doesn't provide a revocation endpoint
  /// - Calls [forgetUser] automatically after successful revocation when [forgetUser] is `true`
  /// - Uses hooks system to allow customization of the revocation process
  ///
  /// **Example:**
  /// ```dart
  /// // Revoke current user's access token
  /// await userManager.revokeAccessToken();
  ///
  /// // Revoke specific token without forgetting user
  /// await userManager.revokeAccessToken(
  ///   overrideAccessToken: 'specific_token',
  ///   forgetUser: false,
  /// );
  /// ```
  Future<void> revokeAccessToken({
    OidcProviderMetadata? discoveryDocumentOverride,
    OidcPlatformSpecificOptions? options,
    bool forgetUser = true,
    String? overrideAccessToken,
    Uri? revocationEndpointOverride,
    Map<String, dynamic>? extraBodyFields,
    Map<String, String>? headers,
  }) async {
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final token = overrideAccessToken ?? currentUser.token.accessToken;
    if (token == null) {
      return; // no access token to revoke.
    }
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final revocationEndpoint =
        revocationEndpointOverride ?? discoveryDocument.revocationEndpoint;
    if (revocationEndpoint == null) {
      return; // no revocation endpoint, nothing to do.
    }

    final credentials = clientCredentials;
    final resp = await (settings.hooks?.revocation).execute(
      request: OidcRevocationHookRequest(
        metadata: discoveryDocument,
        revocationEndpoint: revocationEndpoint,
        credentials: credentials,
        headers: {
          ...?settings.extraRevocationHeaders,
          ...?headers,
        },
        request: OidcRevocationRequest(
          token: token,
          tokenTypeHint:
              OidcConstants_RevocationParameters_TokenType.accessToken,
          extra: {
            ...?extraBodyFields,
            ...?settings.extraRevocationParameters,
          },
        ),
        options: getPlatformOptions(options),
        client: httpClient,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.revokeToken(
          revocationEndpoint: hookRequest.revocationEndpoint,
          request: hookRequest.request,
          client: hookRequest.client,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
        );
      },
    );
    if (resp != null) {
      if (forgetUser) {
        await this.forgetUser();
      }
      return;
    }
    // revocation failed.
    return;
  }

  /// Revokes the current user's refresh token.
  ///
  /// This method sends a revocation request to the authorization server's
  /// revocation endpoint to invalidate the refresh token. The token will no
  /// longer be valid for obtaining new access tokens.
  ///
  /// **Parameters:**
  /// - [discoveryDocumentOverride]: Optional discovery document to use instead
  ///   of the default one
  /// - [options]: Platform-specific options for the revocation request
  /// - [forgetUser]: Whether to forget the current user after successful
  ///   revocation (defaults to `true`)
  /// - [overrideRefreshToken]: Specific refresh token to revoke instead of the
  ///   current user's token
  /// - [revocationEndpointOverride]: Custom revocation endpoint URL to use
  /// - [extraBodyFields]: Additional fields to include in the revocation request body
  /// - [headers]: Additional HTTP headers to include in the request
  ///
  /// **Behavior:**
  /// - Returns early if no current user exists
  /// - Returns early if no refresh token is available to revoke
  /// - Returns early if the authorization server doesn't provide a revocation endpoint
  /// - Calls [forgetUser] automatically after successful revocation when [forgetUser] is `true`
  /// - Uses hooks system to allow customization of the revocation process
  ///
  /// **Example:**
  /// ```dart
  /// // Revoke current user's refresh token
  /// await userManager.revokeRefreshToken();
  ///
  /// // Revoke specific token with custom headers
  /// await userManager.revokeRefreshToken(
  ///   overrideRefreshToken: 'specific_refresh_token',
  ///   headers: {'Custom-Header': 'value'},
  /// );
  /// ```
  Future<void> revokeRefreshToken({
    OidcProviderMetadata? discoveryDocumentOverride,
    OidcPlatformSpecificOptions? options,
    bool forgetUser = true,
    String? overrideRefreshToken,
    Uri? revocationEndpointOverride,
    Map<String, dynamic>? extraBodyFields,
    Map<String, String>? headers,
  }) async {
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    final token = overrideRefreshToken ?? currentUser.token.refreshToken;
    if (token == null) {
      return; // no refresh token to revoke.
    }
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;

    final revocationEndpoint =
        revocationEndpointOverride ?? discoveryDocument.revocationEndpoint;
    if (revocationEndpoint == null) {
      return; // no revocation endpoint, nothing to do.
    }

    final credentials = clientCredentials;
    final resp = await (settings.hooks?.revocation).execute(
      request: OidcRevocationHookRequest(
        metadata: discoveryDocument,
        revocationEndpoint: revocationEndpoint,
        credentials: credentials,
        headers: {
          ...?settings.extraRevocationHeaders,
          ...?headers,
        },
        request: OidcRevocationRequest(
          token: token,
          tokenTypeHint:
              OidcConstants_RevocationParameters_TokenType.refreshToken,
          extra: {
            ...?extraBodyFields,
            ...?settings.extraRevocationParameters,
          },
        ),
        options: getPlatformOptions(options),
        client: httpClient,
      ),
      defaultExecution: (hookRequest) {
        return OidcEndpoints.revokeToken(
          revocationEndpoint: hookRequest.revocationEndpoint,
          request: hookRequest.request,
          client: hookRequest.client,
          credentials: hookRequest.credentials,
          headers: hookRequest.headers,
        );
      },
    );
    if (resp != null) {
      if (forgetUser) {
        await this.forgetUser();
      }
      return;
    }
    // revocation failed.
    return;
  }

  /// Logs out the current user and calls [forgetUser] if successful.
  Future<void> logout({
    String? logoutHint,
    Map<String, dynamic>? extraParameters,
    OidcPlatformSpecificOptions? options,
    Uri? postLogoutRedirectUriOverride,
    Uri? originalUri,
    dynamic extraStateData,
    List<String>? uiLocalesOverride,
    OidcProviderMetadata? discoveryDocumentOverride,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    options = getPlatformOptions(options);
    final prep = prepareForRedirectFlow(options);
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }
    // Best-effort token revocation (RFC 7009) before ending the session, so the
    // refresh and access tokens are invalidated server-side on logout. This is
    // a no-op when the OP advertises no `revocation_endpoint`, and it MUST NEVER
    // block logout: any failure is logged and swallowed. `forgetUser: false`
    // keeps the session intact so the end-session flow below can run.
    if (settings.revokeTokensOnLogout) {
      try {
        await revokeRefreshToken(forgetUser: false);
      } on Object catch (e, st) {
        logger.warning(
          'Best-effort refresh-token revocation on logout failed; '
          'continuing with logout.',
          e,
          st,
        );
      }
      try {
        await revokeAccessToken(forgetUser: false);
      } on Object catch (e, st) {
        logger.warning(
          'Best-effort access-token revocation on logout failed; '
          'continuing with logout.',
          e,
          st,
        );
      }
    }
    final postLogoutRedirectUri =
        postLogoutRedirectUriOverride ?? effectivePostLogoutRedirectUri;

    final stateData = postLogoutRedirectUri == null
        ? null
        : OidcEndSessionState(
            postLogoutRedirectUri: postLogoutRedirectUri,
            originalUri: originalUri,
            options: getSerializableOptions(options),
            data: extraStateData,
            managerId: id,
          );
    if (stateData != null) {
      await store.setStateData(
        state: stateData.id,
        stateData: stateData.toStorageString(),
      );
    }
    final resultFuture = getEndSessionResponse(
      discoveryDocument,
      OidcEndSessionRequest(
        clientId: clientCredentials.clientId,
        postLogoutRedirectUri: postLogoutRedirectUri,
        uiLocales: uiLocalesOverride ?? settings.uiLocales,
        // Always send id_token_hint: it's the RP-initiated-logout mechanism
        // OPs use to identify/authenticate the logout request, independent
        // of whether a post_logout_redirect_uri was also requested.
        idTokenHint: currentUser.idToken,
        extra: extraParameters,
        logoutHint: logoutHint,
        state: stateData?.id,
      ),
      options,
      prep,
    );
    if (stateData == null) {
      // they won't come back with a result!
      await forgetUser();

      return;
    }
    final result = await resultFuture;
    if (result == null) {
      if (isWeb &&
          options.web.navigationMode ==
              OidcPlatformSpecificOptions_Web_NavigationMode.samePage) {
        //wait for a result after redirect.
        return;
      }
      await forgetUser();
      return;
    }
    await handleEndSessionResponse(result: result);
  }

  @protected
  Future<void> handleEndSessionResponse({
    required OidcEndSessionResponse result,
  }) async {
    //found result!
    final resState = result.state;
    if (resState == null) {
      await forgetUser();
      return;
    }
    final resStateData = await store.getStateData(resState);
    if (resStateData == null) {
      logAndThrow("Didn't receive correct state value.");
    }
    final parsedState = OidcState.fromStorageString(resStateData);
    if (parsedState.managerId != id) {
      return; // this state is not for this manager.
    }
    await store.setStateData(state: resState, stateData: null);
    if (parsedState is! OidcEndSessionState) {
      logAndThrow('received wrong state type (${parsedState.runtimeType}).');
    }
    //if all state checks are successful, do logout.
    await forgetUser();
  }

  /// You enter this function with an /authorize response.
  ///
  /// this function expects the [store] to still have
  /// - current state
  /// - state data
  /// - nonce
  ///
  /// this function calls [createUserFromToken] after validating the response,
  /// and parsing the state.
  ///
  /// it also clears the store after it's done.
  @protected
  Future<OidcUser?> handleSuccessfulAuthResponse({
    required OidcAuthorizeResponse response,
    required String grantType,
    required OidcProviderMetadata metadata,
  }) async {
    final receivedStateKey = response.state;
    if (receivedStateKey == null) {
      logAndThrow(
        "Server didn't return state parameter, even though it was sent.",
      );
    }

    try {
      final stateDataStr = await store.getStateData(receivedStateKey);
      if (stateDataStr == null) {
        logger.severe(
          "Internal error, the session state wasn't cleared after the state was deleted.",
        );
        //don't throw here, since it's a bug.
        return null;
      }
      final stateData = OidcState.fromStorageString(stateDataStr);
      if (stateData is! OidcAuthorizeState) {
        //impossible case.
        logAndThrow('received wrong state type (${stateData.runtimeType}).');
      }
      if (stateData.managerId != id) {
        return null; // this state is not for this manager.
      }
      // RFC 9207 mix-up attack defense.
      final responseIss = response.iss;
      final expectedIssuer = metadata.issuer;
      // §2.4: a client MUST reject a response that omits `iss` when the AS
      // advertises support via `authorization_response_iss_parameter_supported`.
      if (metadata.authorizationResponseIssParameterSupportedOrDefault &&
          responseIss == null) {
        logAndThrow(
          'The authorization server advertises '
          '`authorization_response_iss_parameter_supported` but the '
          'authorization response is missing the `iss` parameter '
          '(RFC 9207 §2.4); refusing as a possible mix-up attack.',
        );
      }
      // When `iss` is present it MUST match the provider issuer (string compare,
      // not Uri normalization — RFC 9207 §2.4). A no-op for OPs that omit it and
      // do not advertise support.
      if (responseIss != null &&
          expectedIssuer != null &&
          responseIss.toString() != expectedIssuer.toString()) {
        logAndThrow(
          'Authorization response `iss` ($responseIss) does not match the '
          'provider issuer ($expectedIssuer); possible mix-up attack (RFC 9207).',
        );
      }
      if (grantType == OidcConstants_GrantType.implicit) {
        //implicit grant gets the token directly from the response.
        final implicitTokenResponse = OidcTokenResponse.fromJson(response.src);
        if (implicitTokenResponse.accessToken != null ||
            implicitTokenResponse.idToken != null) {
          final token = OidcToken.fromResponse(
            implicitTokenResponse,
            overrideExpiresIn: settings.getExpiresIn?.call(
              implicitTokenResponse,
            ),
            sessionState: response.sessionState,
          );
          return await createUserFromToken(
            token: token,
            userInfo: null,
            attributes: null,
            nonce: stateData.nonce,
            metadata: metadata,
            // Hybrid responses may carry a front-channel `code` to bind via
            // `c_hash`; null for a pure implicit response.
            authorizationCode: response.code,
            maxAge: stateData.maxAge,
          );
        }
      }

      final tokenEndpoint = metadata.tokenEndpoint;
      if (tokenEndpoint == null) {
        logAndThrow(
          "This provider doesn't provide a token endpoint",
        );
      }
      // an authorization code flow MUST have a code as a response,
      // otherwise an OidcException should have been thrown before entering
      // this function.
      final code = response.code;
      if (code == null) {
        logAndThrow(
          "Server didn't send code even though the authorization code flow was used.",
        );
      }

      // OpenID Connect Core §3.3.2 (Hybrid flow): when the authorization
      // endpoint ALSO returned an id_token in the front channel, validate it
      // before exchanging the code — `nonce` must match, `c_hash` must bind the
      // returned `code`, and `at_hash` (when present) must bind the
      // front-channel access_token.
      final frontChannelIdToken = response.idToken;
      if (frontChannelIdToken != null) {
        await validateFrontChannelIdToken(
          idToken: frontChannelIdToken,
          accessToken: response.accessToken,
          code: code,
          nonce: stateData.nonce,
          metadata: metadata,
          maxAge: stateData.maxAge,
        );
      }

      // #324 item 20: the PKCE `code_verifier` lives in the `secureTokens`
      // namespace (encrypted / secure-storage-backed) keyed by the state id.
      // #404: the plaintext `state` payload is no longer a source for it —
      // reading the secret back out of the namespace it was moved off of would
      // undo the fix. Absent (a flow started before 2.0.0 and still inside the
      // stale-state window) means no `code_verifier` is sent and the OP answers
      // `invalid_grant`, which surfaces as a clean re-login.
      final storedCodeVerifier = await store.getStateCodeVerifier(
        receivedStateKey,
      );

      //request the token.
      final credentials = clientCredentials;
      final tokenResp = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: metadata,
          tokenEndpoint: tokenEndpoint,
          credentials: credentials,
          headers: stateData.extraTokenHeaders,
          request: OidcTokenRequest.authorizationCode(
            redirectUri: response.redirectUri ?? stateData.redirectUri,
            codeVerifier: response.codeVerifier ?? storedCodeVerifier,
            extra: stateData.extraTokenParams,
            clientId: credentials.clientId,
            code: code,
          ),
          client: httpClient,
          options: settings.options,
        ),
        defaultExecution: (hookRequest) {
          return OidcEndpoints.token(
            tokenEndpoint: hookRequest.tokenEndpoint,
            credentials: hookRequest.credentials,
            headers: hookRequest.headers,
            dpopManager: dpopManager,
            request: hookRequest.request,
            client: hookRequest.client,
          );
        },
      );

      final token = OidcToken.fromResponse(
        tokenResp,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResp),
        sessionState: response.sessionState,
      );
      return await createUserFromToken(
        token: token,
        nonce: stateData.nonce,
        attributes: null,
        userInfo: null,
        metadata: metadata,
        authorizationCode: code,
        maxAge: stateData.maxAge,
      );
    } finally {
      //remove the state + state response since we already handled it.
      await store.setStateResponseData(
        state: receivedStateKey,
        stateData: null,
      );
      await store.setStateData(state: receivedStateKey, stateData: null);
      // #324 item 20: drop the secureTokens `code_verifier` for this state too,
      // so the secret does not outlive the flow that consumed it.
      await store.setStateCodeVerifier(
        state: receivedStateKey,
        codeVerifier: null,
      );
    }
  }

  /// Handles a token; either from cache, in which case the [nonce] will be null
  /// , or from an auth response, in which case [nonce] will not be null.
  ///
  /// This function creates an [OidcUser] by validating the token, and then
  /// passing the result to [validateAndSaveUser].
  ///
  /// if the manager already has a [currentUser], this function replaces
  /// its internal token (after validation).
  /// Resolves the allowlist of JWS algorithms an id_token's `alg` header may
  /// use during signature verification.
  ///
  /// When [OidcUserManagerSettings.allowedIdTokenAlgorithms] is set, it
  /// **overrides** (replaces) the OP-advertised
  /// `id_token_signing_alg_values_supported` (defense-in-depth: the RP stops
  /// trusting the OP's self-declared list). When null (the default), the
  /// OP-advertised list is used unchanged. This is the single point where the
  /// pin overrides the OP-advertised list.
  @protected
  List<String>? resolveAllowedIdTokenAlgorithms(
    OidcProviderMetadata metadata,
  ) =>
      settings.allowedIdTokenAlgorithms ??
      metadata.idTokenSigningAlgValuesSupported;

  @protected
  Future<OidcUser?> createUserFromToken({
    required OidcToken token,
    required String? nonce,
    required Map<String, dynamic>? attributes,
    required Map<String, dynamic>? userInfo,
    required OidcProviderMetadata metadata,
    OidcUser? currentUserOverride,
    bool validateAndSave = true,
    String? authorizationCode,
    Duration? maxAge,
    // When true, the user is (re)built from scratch via [OidcUser.fromIdToken]
    // (verifying the id_token signature) instead of replacing the token on the
    // existing [currentUser]. Used by cache-first background revalidation, whose
    // locally-restored user was deserialized WITHOUT verification.
    bool ignoreCurrentUser = false,
  }) async {
    final currentUser = ignoreCurrentUser
        ? null
        : (currentUserOverride ?? this.currentUser);
    OidcUser? newUser;
    final idTokenOverride = await settings.getIdToken?.call(token);
    if (currentUser == null) {
      newUser = await OidcUser.fromIdToken(
        token: token,
        // Constrain id_token signature verification to the algorithms the OP
        // advertises for ID Tokens (id_token_signing_alg_values_supported),
        // not the token-endpoint client-authentication algorithms. An explicit
        // `allowedIdTokenAlgorithms` pin overrides the OP-advertised list.
        allowedAlgorithms: resolveAllowedIdTokenAlgorithms(metadata),
        keystore: keyStore,
        attributes: attributes,
        userInfo: userInfo,
        idTokenOverride: idTokenOverride,
        cacheStore: store,
        jwksCacheMaxAge: settings.jwksCacheMaxAge,
        httpClient: httpClient,
      );
    } else {
      final reusesExistingIdToken =
          idTokenOverride == null && token.idToken == null;
      newUser = await currentUser.replaceToken(
        token,
        idTokenOverride: idTokenOverride,
        cacheStore: store,
        allowExpiredIdToken: reusesExistingIdToken,
        jwksCacheMaxAge: settings.jwksCacheMaxAge,
        httpClient: httpClient,
      );
      // OpenID Connect Core §12.2: a freshly-issued id_token MUST keep the same
      // `sub` (and `iss`) as the prior one — refuse a possible account swap on
      // refresh. Skipped when the existing id_token is reused (no new token).
      if (!reusesExistingIdToken) {
        final oldClaims = currentUser.parsedIdToken.claims;
        final newClaims = newUser.parsedIdToken.claims;
        if (oldClaims.subject != null &&
            newClaims.subject != oldClaims.subject) {
          logAndThrow(
            'Refreshed id_token `sub` (${newClaims.subject}) does not match '
            'the existing user (${oldClaims.subject}); refusing a possible '
            'account swap.',
          );
        }
        if (oldClaims.issuer != null && newClaims.issuer != oldClaims.issuer) {
          logAndThrow(
            'Refreshed id_token `iss` (${newClaims.issuer}) does not match '
            'the existing user (${oldClaims.issuer}).',
          );
        }
      }
      if (attributes != null) {
        newUser = newUser.setAttributes(attributes);
      }
      if (userInfo != null) {
        newUser = newUser.withUserInfo(userInfo);
      }
    }

    final idTokenNonce =
        newUser.parsedIdToken.claims[OidcConstants_AuthParameters.nonce]
            as String?;
    if (nonce != null && idTokenNonce != nonce) {
      logAndThrow(
        'Server returned a wrong id_token nonce, might be a replay attack.',
      );
    }
    if (validateAndSave) {
      return validateAndSaveUser(
        user: newUser,
        metadata: metadata,
        authorizationCode: authorizationCode,
        maxAge: maxAge,
      );
    } else {
      return newUser;
    }
  }

  @protected
  Future<void> saveUser(OidcUser user) async {
    await store.setMany(
      OidcStoreNamespace.secureTokens,
      values: {
        OidcConstants_Store.currentToken: jsonEncode(user.token.toJson()),
        OidcConstants_Store.currentUserInfo: jsonEncode(user.userInfo),
        OidcConstants_Store.currentUserAttributes: jsonEncode(user.attributes),
      },
      managerId: id,
    );
  }

  @protected
  StreamSubscription<OidcMonitorSessionResult>? sessionSub;

  @protected
  void listenToUserSessionIfSupported(OidcUser? user) {
    unawaited(sessionSub?.cancel());
    sessionSub = null;
    if (user == null) {
      return;
    }
    final checkSessionIframe = discoveryDocument.checkSessionIframe;
    final sessionState = user.token.sessionState;
    if (!settings.sessionManagementSettings.enabled) {
      return;
    }
    if (checkSessionIframe == null || sessionState == null) {
      logger.info(
        "can't "
        'monitor user session due to lack of sessionState ($sessionState) or checkSessionIframe ($checkSessionIframe)',
      );
      return;
    }
    logger.info('started monitoring user session');

    sessionSub ??=
        monitorSessionStatus(
          checkSessionIframe: checkSessionIframe,
          request: OidcMonitorSessionStatusRequest(
            clientId: clientCredentials.clientId,
            sessionState: sessionState,
            interval: settings.sessionManagementSettings.interval,
          ),
        ).listen((event) {
          switch (event) {
            case OidcValidMonitorSessionResult(changed: final changed):
              if (changed) {
                unawaited(sessionSub?.cancel());
                unawaited(reAuthorizeUser());
              }
            case OidcErrorMonitorSessionResult():
              if (settings.sessionManagementSettings.stopIfErrorReceived) {
                unawaited(sessionSub?.cancel());
              }
            case OidcUnknownMonitorSessionResult():
          }
        });
  }

  @protected
  late final tokenEvents = OidcTokenEventsManager(
    getExpiringNotificationTime: settings.refreshBefore,
  );

  /// Records a successful contact with the authorization server and optionally
  /// exits offline mode when connectivity is restored.
  @protected
  void recordSuccessfulServerContact({
    OidcToken? newToken,
    bool exitOffline = true,
  }) {
    lastSuccessfulServerContact = clock.now();
    consecutiveRefreshFailures = 0;
    if (exitOffline && isInOfflineMode) {
      exitOfflineMode(
        networkRestored: true,
        newToken: newToken,
      );
    }
  }

  /// Centralized handler for transitioning into offline mode when recoverable
  /// network issues occur during token operations.
  @protected
  bool handleOfflineEligibleFailure({
    required Object error,
    required OidcToken? fallbackToken,
    bool scheduleRetry = false,
    void Function(Duration retryDelay)? onRetryScheduled,
    bool emitRepeatFailureWarning = false,
  }) {
    if (!settings.supportOfflineAuth) {
      return false;
    }

    final canContinue = OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
      error: error,
      supportOfflineAuth: settings.supportOfflineAuth,
    );
    if (!canContinue) {
      return false;
    }

    consecutiveRefreshFailures++;

    // #120/#154: every caller of this method is a failed refresh path
    // (auto-expiry, manual, or startup-load), so offline mode is being entered
    // *because* a token refresh failed. Report that specific reason instead of
    // the generic network/server reason.
    enterOfflineMode(
      reason: OfflineModeReason.tokenRefreshFailed,
      currentToken: fallbackToken,
      error: error,
    );

    if (emitRepeatFailureWarning) {
      final threshold = settings.offlineRepeatFailureWarningThreshold;
      if (threshold > 0 && consecutiveRefreshFailures >= threshold) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.repeatRefreshFailure,
          message:
              'Token refresh has failed $consecutiveRefreshFailures consecutive times',
        );
      }
    }

    if (scheduleRetry && onRetryScheduled != null) {
      final retryDelay = calculateRetryDelay();
      logger.info(
        'Automatic token refresh failed (offline mode), will retry in $retryDelay',
      );
      onRetryScheduled(retryDelay);
    }

    return true;
  }

  /// Refreshes the token manually.
  ///
  /// If token can't be refreshed `null` will be returned.
  ///
  /// Token can be refreshed in the following cases:
  /// 1. grant_types_supported MUST include refresh_token
  /// 2. the [currentUser] MUST NOT be null
  /// 3. the `currentUser.token` MUST include refreshToken
  ///
  /// If any of these conditions are not met, null is returned.
  ///
  /// An [OidcException] will be thrown if the server returns an error.
  Future<OidcUser?> refreshToken({
    String? overrideRefreshToken,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
  }) {
    return _refreshToken(
      overrideRefreshToken: overrideRefreshToken,
      discoveryDocumentOverride: discoveryDocumentOverride,
      extraBodyFields: extraBodyFields,
    );
  }

  /// Returns an access token that is guaranteed to stay valid for at least
  /// [minValidity], refreshing it first only when it would not.
  ///
  /// This is the "give me a usable access token right now" entry point, meant to
  /// be called on EVERY outgoing request to a protected resource instead of
  /// reading `currentUser?.token.accessToken` (which is freshness-unaware):
  ///
  /// ```dart
  /// final accessToken = await userManager.getAccessToken();
  /// ```
  ///
  /// ## Concurrency
  ///
  /// Concurrent callers share a SINGLE refresh-token exchange (the same
  /// in-flight latch the automatic on-expiry refresh uses), so N parallel API
  /// calls that all find a stale token do not each exchange the refresh token.
  /// This matters against an OP with refresh-token rotation, where N concurrent
  /// exchanges of the same refresh token look like token reuse and can revoke
  /// the entire grant family. Note that the older [refreshToken] deliberately
  /// keeps its unconditional, un-coalesced behaviour for callers that need a
  /// raw exchange (e.g. with an `overrideRefreshToken`).
  ///
  /// This call also joins (rather than races) an in-flight
  /// [OidcInitMode.cacheFirst] background revalidation — see
  /// [_cacheFirstRevalidationFuture] — so calling this immediately after
  /// `await manager.init()` returns (cacheFirst is the DEFAULT) never presents
  /// the same refresh token a second time while the background pass is still
  /// exchanging it.
  ///
  /// ## Return value and errors
  ///
  /// * Returns `null` when there is no signed-in user — this is a state, not an
  ///   error, so it does not throw.
  /// * Returns the current access token unchanged when the token carries no
  ///   `expires_in` (the library cannot know how much time is left; the same
  ///   assumption that disables the expiry timers) and [forceRefresh] is false.
  /// * Throws [OidcInteractionRequiredException] when the token is stale and
  ///   cannot be renewed silently — no refresh token, or a terminal refresh
  ///   failure such as `invalid_grant`. Handle it by starting an interactive
  ///   login.
  /// * Throws an [OidcException] whose [OidcException.kind] is
  ///   [OidcTokenRefreshFailureKind.transient] when the refresh failed for a
  ///   recoverable reason (network / timeout / 5xx) **and offline mode did NOT
  ///   absorb it** — i.e. [OidcUserManagerSettings.supportOfflineAuth] is
  ///   `false`, or the specific error isn't offline-eligible. Retrying later
  ///   can succeed; the cached session is retained.
  /// * Returns the cached (now possibly stale) access token, WITHOUT throwing,
  ///   when a recoverable failure occurs and offline mode DOES absorb it
  ///   ([OidcUserManagerSettings.supportOfflineAuth] is `true` for an
  ///   offline-eligible error): this mirrors the legacy [refreshToken]'s
  ///   "keep the cached session" behavior, so a call made while offline gets a
  ///   usable (if stale) token instead of an exception — otherwise every
  ///   `getAccessToken`/[signInSilent] call while offline would throw, which
  ///   would defeat the point of enabling offline auth support.
  ///
  /// [minValidity] is the freshness margin: a token expiring sooner than this is
  /// refreshed first. [forceRefresh] refreshes unconditionally, ignoring
  /// [minValidity].
  Future<String?> getAccessToken({
    Duration minValidity = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    ensureInit();
    // Join (rather than race) an in-flight cache-first background
    // revalidation — see [_cacheFirstRevalidationFuture] for why this call
    // would otherwise start a SECOND `/token` exchange presenting the same
    // refresh token the revalidation is already exchanging. After this
    // completes, [currentUser] already reflects whatever the revalidation
    // concluded (refreshed / retained / forgotten), so the freshness check
    // below sees the post-revalidation state.
    await _joinCacheFirstRevalidationIfInFlight();
    final user = currentUser;
    if (user == null) {
      // No session at all — a state the caller handles (e.g. show a login
      // button), not a failure to throw about.
      return null;
    }
    final token = user.token;
    if (!forceRefresh) {
      // `isAccessTokenAboutToExpire` reports `true` when `expiresIn` is null
      // (unknown expiry). Treat unknown as "usable" instead, mirroring
      // [listenToTokenRefreshIfSupported], which likewise declines to arm the
      // expiry timers for such a token — otherwise EVERY call would refresh.
      final stillFresh =
          token.expiresIn == null ||
          !token.isAccessTokenAboutToExpire(tolerance: minValidity);
      if (stillFresh) {
        return token.accessToken;
      }
    }

    if (token.refreshToken == null) {
      throw OidcInteractionRequiredException(
        message: forceRefresh
            ? 'A refresh was forced but the current session has no '
                  'refresh_token; interactive re-authentication is required.'
            : 'The access token is expired (or expires within $minValidity) '
                  'and the current session has no refresh_token; interactive '
                  're-authentication is required.',
      );
    }

    final outcome = await _autoRefresh(
      token,
      source: OidcTokenRefreshSource.manual,
    );
    return _userFromRefreshOutcome(outcome)?.token.accessToken;
  }

  /// Maps a shared-latch refresh outcome onto the silent-acquisition contract
  /// shared by [getAccessToken] and [signInSilent]: return the renewed user,
  /// throw [OidcInteractionRequiredException] on a terminal failure, and throw a
  /// `kind`-stamped [OidcException] on a transient one.
  OidcUser? _userFromRefreshOutcome(_OidcRefreshOutcome outcome) {
    final refreshedUser = outcome.user;
    if (refreshedUser != null) {
      return refreshedUser;
    }
    final failureKind = outcome.failureKind;
    if (failureKind == null) {
      // The manager was disposed while the refresh was in flight; the refresh
      // deliberately became a complete no-op, so there is nothing to hand back.
      return null;
    }
    final error = outcome.error;
    if (failureKind == OidcTokenRefreshFailureKind.terminal) {
      throw OidcInteractionRequiredException.from(
        error ?? const OidcException('The refresh token grant was rejected.'),
        message:
            'The refresh token was rejected by the authorization server '
            '(revoked, expired, or already rotated); interactive '
            're-authentication is required.',
        stackTrace: outcome.stackTrace,
      );
    }
    if (error is OidcException) {
      // Preserve the original diagnostics but re-stamp the classification the
      // caller needs (the raw throw carried no `kind`).
      throw OidcException.raw(
        message: error.message,
        extra: error.extra,
        errorResponse: error.errorResponse,
        internalException: error.internalException ?? error,
        internalStackTrace: error.internalStackTrace ?? outcome.stackTrace,
        rawRequest: error.rawRequest,
        rawResponse: error.rawResponse,
        kind: failureKind,
      );
    }
    throw OidcException(
      'Refreshing the access token failed for a recoverable reason; '
      'retrying later may succeed.',
      internalException: error,
      internalStackTrace: outcome.stackTrace,
      kind: failureKind,
    );
  }

  Future<OidcUser?> _refreshToken({
    String? overrideRefreshToken,
    OidcProviderMetadata? discoveryDocumentOverride,
    Map<String, dynamic>? extraBodyFields,
    OidcUser? currentUserOverride,
    OidcTokenRefreshSource source = OidcTokenRefreshSource.manual,
  }) async {
    ensureInit();
    final discoveryDocument =
        discoveryDocumentOverride ?? this.discoveryDocument;
    final existingUser = currentUserOverride ?? currentUser;
    // Availability of the refresh_token grant is determined by HAVING a
    // refresh_token, NOT by the OP advertising `refresh_token` in
    // `grant_types_supported`: that field is OPTIONAL discovery metadata
    // (RFC 8414 §2) which compliant IdPs (e.g. Facebook) omit, and RFC 6749 §6
    // ties refresh to possession of the token. Gating on the metadata silently
    // disabled refresh for those IdPs; if the OP genuinely rejects the grant,
    // the token-endpoint call below fails loudly instead.
    final refreshToken =
        overrideRefreshToken ?? existingUser?.token.refreshToken;
    if (refreshToken == null) {
      // Can't refresh the access token anyway.
      return null;
    }
    try {
      final credentials = clientCredentials;
      final tokenResponse = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: discoveryDocument,
          tokenEndpoint: discoveryDocument.tokenEndpoint!,
          // clientSecret is intentionally NOT passed here: `credentials`
          // below is the single source of client authentication (RFC 6749
          // §2.3). Also setting it on the request would duplicate it into
          // the body even when `credentials` already authenticates via the
          // Basic header (see OidcEndpoints.token).
          request: OidcTokenRequest.refreshToken(
            refreshToken: refreshToken,
            clientId: credentials.clientId,
            extra: {...?settings.extraTokenParameters, ...?extraBodyFields},
            scope: effectiveScope,
            resource: settings.resource,
          ),
          credentials: credentials,
          headers: settings.extraTokenHeaders,
          client: httpClient,
          options: settings.options,
        ),
        defaultExecution: (tokenHookRequest) async {
          return OidcEndpoints.token(
            tokenEndpoint: tokenHookRequest.tokenEndpoint,
            credentials: tokenHookRequest.credentials,
            client: tokenHookRequest.client,
            headers: tokenHookRequest.headers,
            dpopManager: dpopManager,
            request: tokenHookRequest.request,
          );
        },
      );
      final token = OidcToken.fromResponse(
        tokenResponse,
        overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
        sessionState: existingUser?.token.sessionState,
      );

      // Successful refresh - update last server contact and exit offline mode
      recordSuccessfulServerContact(newToken: token);
      return await createUserFromToken(
        token: token,
        nonce: null,
        userInfo: null,
        attributes: null,
        metadata: discoveryDocument,
        currentUserOverride: existingUser,
      );
    } on Object catch (e, st) {
      // #120: signal the failure to background observers of events() before any
      // offline handling or rethrow. Neither caller-initiated path that reaches
      // here schedules a retry — a manual refreshToken() call nor the startup
      // cached-load refresh — so willRetry is always false. [source] identifies
      // which one it was (manual by default, startupLoad when loadCachedTokens
      // drives it). For the manual path this is the intentional double-signal:
      // observers get the event while the awaiting caller still gets the throw
      // below (MSAL pattern).
      emitEvent(
        OidcTokenRefreshFailedEvent.fromError(
          error: e,
          stackTrace: st,
          source: source,
          willRetry: false,
        ),
      );

      // Handle errors based on offline auth settings
      final handledOffline = handleOfflineEligibleFailure(
        error: e,
        fallbackToken: existingUser?.token,
        emitRepeatFailureWarning: true,
      );

      if (handledOffline) {
        // Return the same user - callers will continue with cached state
        return existingUser;
      }

      // Non-network error or offline auth not supported - rethrow
      rethrow;
    }
  }

  @protected
  Future<void> listenToTokenRefreshIfSupported(
    OidcTokenEventsManager tokenEventsManager,
    OidcUser? user,
  ) async {
    if (user == null) {
      tokenEventsManager.unload();
    } else {
      if (user.token.expiresIn == null) {
        // Can't know how much time is left.
        return;
      }
      tokenEventsManager.load(user.token);
    }
  }

  @protected
  Future<void> handleTokenExpiring(OidcToken event) async {
    emitEvent(
      OidcTokenExpiringEvent.now(currentToken: event),
    );
    // Automatic refresh-on-expiry is gated on POSSESSION of a refresh_token, not
    // on the OP advertising `refresh_token` in grant_types_supported (OPTIONAL
    // metadata, RFC 8414 §2; refresh is tied to the token per RFC 6749 §6).
    // Gating on the metadata silently disabled auto-refresh for OPs that omit it
    // (e.g. Facebook) — this mirrors the same ungating already applied to the
    // manual _refreshToken path. A genuinely unsupported grant fails loudly at
    // the token endpoint below.
    final refreshToken = event.refreshToken;
    if (refreshToken == null) {
      return;
    }
    // #201: during a cache-first cold start the background revalidation owns the
    // first refresh of the just-restored expired token (source `startupLoad`).
    // Skipping here keeps that refresh a SINGLE `/token` exchange instead of
    // racing a second one (see [_cacheFirstRevalidationInFlight]).
    if (_cacheFirstRevalidationInFlight) {
      return;
    }
    // #154: share the refresh with [handleTokenExpired] through the in-flight
    // latch so a resume that fires both timers exchanges the refresh token
    // exactly once. All success bookkeeping, failure signalling, and offline
    // handling happen inside [_performAutoRefresh].
    await _autoRefresh(event);
  }

  /// Returns the in-flight refresh for [event], starting one if none is
  /// running. Concurrent callers ([handleTokenExpiring] and
  /// [handleTokenExpired] on resume, plus every [getAccessToken] /
  /// [signInSilent] caller) share the SAME future, so the refresh token is
  /// exchanged only once. The latch clears itself on completion so a later
  /// expiry can refresh again.
  ///
  /// [source] labels the emitted [OidcTokenRefreshFailedEvent] and only applies
  /// to the caller that actually STARTS the exchange — a caller that joins an
  /// already-running refresh inherits that refresh's source, because there is
  /// only one exchange (and therefore only one failure event) to label.
  Future<_OidcRefreshOutcome> _autoRefresh(
    OidcToken event, {
    OidcTokenRefreshSource source = OidcTokenRefreshSource.autoExpiry,
  }) {
    return _autoRefreshInFlight ??= _performAutoRefresh(event, source: source)
        .whenComplete(() {
          _autoRefreshInFlight = null;
        });
  }

  /// Performs one refresh of [event]'s refresh token and classifies the
  /// outcome.
  ///
  /// On success the replaced user is saved (which re-arms the token timers via
  /// [userChanges]) and returned with a `null` `failureKind`.
  ///
  /// On failure the single `OidcTokenRefreshFailedEvent` (labelled with
  /// [source]) is emitted, then offline handling runs:
  /// * When [handleOfflineEligibleFailure] ABSORBS the failure (a recoverable
  ///   / offline-eligible error with [OidcUserManagerSettings.supportOfflineAuth]
  ///   enabled), this returns the RETAINED [currentUser] with a `null`
  ///   `failureKind` — the same "keep the cached session, don't throw"
  ///   contract [_refreshToken] already gives `refreshToken()`. Without this,
  ///   [getAccessToken] / [signInSilent] would throw a `kind: transient`
  ///   [OidcException] the moment offline mode kicks in, defeating the entire
  ///   point of `supportOfflineAuth` for those two entry points (a `getAccessToken`
  ///   call while offline should hand back the cached token, not throw).
  /// * Otherwise (terminal failure, or offline auth not eligible/enabled) the
  ///   failure `OidcTokenRefreshFailureKind` is returned with a `null` user so
  ///   [handleTokenExpired] can decide whether to forget the session and
  ///   [getAccessToken] / [signInSilent] can decide what to throw.
  ///
  /// This method never throws the refresh failure — it is shared with the
  /// automatic (timer-driven) paths, which must not surface an unhandled async
  /// error. Callers that need a throw re-raise from the returned `error`.
  Future<_OidcRefreshOutcome> _performAutoRefresh(
    OidcToken event, {
    OidcTokenRefreshSource source = OidcTokenRefreshSource.autoExpiry,
  }) async {
    OidcUser? newUser;
    //try getting a new token.
    try {
      final credentials = clientCredentials;
      final tokenResponse = await (settings.hooks?.token).execute(
        request: OidcTokenHookRequest(
          metadata: discoveryDocument,
          tokenEndpoint: discoveryDocument.tokenEndpoint!,
          credentials: credentials,
          client: httpClient,
          headers: settings.extraTokenHeaders,
          // clientSecret is intentionally NOT passed here: `credentials`
          // above is the single source of client authentication (RFC 6749
          // §2.3). Also setting it on the request would duplicate it into
          // the body even when `credentials` already authenticates via the
          // Basic header (see OidcEndpoints.token).
          request: OidcTokenRequest.refreshToken(
            refreshToken: event.refreshToken!,
            clientId: credentials.clientId,
            extra: settings.extraTokenParameters,
            scope: effectiveScope,
            resource: settings.resource,
          ),
          options: settings.options,
        ),
        defaultExecution: (hookRequest) {
          return OidcEndpoints.token(
            tokenEndpoint: hookRequest.tokenEndpoint,
            credentials: hookRequest.credentials,
            client: hookRequest.client,
            headers: hookRequest.headers,
            dpopManager: dpopManager,
            request: hookRequest.request,
          );
        },
      );
      // Post-dispose safety: if the manager was torn down while this
      // (possibly delayed) refresh was in flight, the outcome must be a
      // COMPLETE no-op — no user save/mutation via [createUserFromToken], no
      // `recordSuccessfulServerContact`, no event. Returning the neutral
      // all-null outcome also leaves [handleTokenExpired]'s forget decision a
      // no-op (it only forgets on a `terminal` failureKind).
      if (_isDisposed) {
        logger.finest(
          'Auto-refresh succeeded after the manager was disposed; '
          'ignoring the new token.',
        );
        return (
          user: null,
          failureKind: null,
          error: null,
          stackTrace: null,
        );
      }
      newUser = await createUserFromToken(
        token: OidcToken.fromResponse(
          tokenResponse,
          overrideExpiresIn: settings.getExpiresIn?.call(tokenResponse),
          sessionState: event.sessionState,
        ),
        nonce: null,
        attributes: null,
        userInfo: null,
        metadata: discoveryDocument,
      );

      // Successful refresh - update last server contact and exit offline mode
      recordSuccessfulServerContact(newToken: newUser?.token);
      logger.fine('Refreshed a token and got a new user: ${newUser?.uid}');
      return (
        user: newUser,
        failureKind: null,
        error: null,
        stackTrace: null,
      );
    } on Object catch (e, st) {
      // Post-dispose safety: a refresh that FAILS after the manager was torn
      // down must also be a COMPLETE no-op — no failure event, no offline
      // handling, no retry timer. Swallow it with a trace log.
      if (_isDisposed) {
        logger.finest(
          'Auto-refresh failed after the manager was disposed; '
          'ignoring the failure.',
          e,
          st,
        );
        return (
          user: null,
          failureKind: null,
          error: null,
          stackTrace: null,
        );
      }
      // #120: a transient failure that offline handling will absorb schedules a
      // retry; a terminal failure (e.g. invalid_grant) or a disabled offline
      // path does not. Compute this up front so the failure event carries an
      // accurate `willRetry`, and emit it BEFORE entering offline mode or
      // tearing down the timers (#154 ordering).
      final willRetry =
          settings.supportOfflineAuth &&
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: e,
            supportOfflineAuth: settings.supportOfflineAuth,
          );
      final failedEvent = OidcTokenRefreshFailedEvent.fromError(
        error: e,
        stackTrace: st,
        source: source,
        willRetry: willRetry,
      );
      emitEvent(failedEvent);

      final handledOffline = handleOfflineEligibleFailure(
        error: e,
        fallbackToken: event,
        scheduleRetry: true,
        onRetryScheduled: (retryDelay) {
          Timer(retryDelay, () {
            if (currentUser?.token == event) {
              tokenEvents.load(event);
            }
          });
        },
      );

      if (!handledOffline) {
        // Non-network error or offline auth not supported - unload event
        // manager. The user is RETAINED here (this is the non-offline / terminal
        // auto-expiry retention that [handleTokenExpired] mirrors for transient
        // failures): the expiring path never forgets on its own.
        logger.warning(
          'Token refresh failed, unloading token events manager',
          e,
        );
        tokenEvents.unload();
        return (
          user: null,
          failureKind: failedEvent.kind,
          error: e,
          stackTrace: st,
        );
      }
      // Offline mode absorbed the failure: report a SUCCESS-shaped outcome
      // (the retained user, `failureKind: null`) rather than the raw failure.
      // [handleTokenExpired] only forgets on `failureKind == terminal`, so
      // this is a no-op change for the timer-driven callers (unaffected —
      // they already never saw `terminal` here); it is what makes
      // [getAccessToken] / [signInSilent] hand back the cached access token
      // instead of throwing while offline (see the dartdoc above).
      return (
        user: currentUser,
        failureKind: null,
        error: null,
        stackTrace: null,
      );
    }
  }

  /// Calculates retry delay using the configured callback
  @protected
  Duration calculateRetryDelay() {
    return settings.offlineRefreshRetryDelay(consecutiveRefreshFailures);
  }

  /// Enters offline mode and emits appropriate events
  @protected
  void enterOfflineMode({
    required OfflineModeReason reason,
    OidcToken? currentToken,
    Object? error,
  }) {
    if (offlineModeStartedAt == null) {
      offlineModeStartedAt = clock.now();
      emitEvent(
        OidcOfflineModeEnteredEvent.now(
          reason: reason,
          currentToken: currentToken,
          lastSuccessfulServerContact: lastSuccessfulServerContact,
          error: error,
        ),
      );
      logger.info('Entered offline mode: $reason');
    }
  }

  /// Exits offline mode and emits appropriate events
  @protected
  void exitOfflineMode({
    required bool networkRestored,
    required OidcToken? newToken,
  }) {
    if (offlineModeStartedAt != null) {
      offlineModeStartedAt = null;
      consecutiveRefreshFailures = 0;
      emitEvent(
        OidcOfflineModeExitedEvent.now(
          networkRestored: networkRestored,
          newToken: newToken,
          lastSuccessfulServerContact: lastSuccessfulServerContact,
        ),
      );
      logger.info('Exited offline mode');
    }
  }

  /// Emits a warning event for offline auth security concerns
  @protected
  void emitOfflineAuthWarning({
    required OfflineAuthWarningType warningType,
    required String message,
    Duration? tokenExpiredSince,
  }) {
    emitEvent(
      OidcOfflineAuthWarningEvent.now(
        warningType: warningType,
        message: message,
        tokenExpiredSince: tokenExpiredSince,
      ),
    );
  }

  /// Checks if the offline duration exceeds safe limits
  @protected
  bool isOfflineDurationExcessive() {
    if (offlineModeStartedAt == null) return false;

    final offlineDuration = clock.now().difference(offlineModeStartedAt!);
    // Default to 7 days as maximum offline duration
    const maxOfflineDuration = Duration(days: 7);

    return offlineDuration > maxOfflineDuration;
  }

  @protected
  void handleTokenExpired(OidcToken event) {
    emitEvent(
      OidcTokenExpiredEvent.now(currentToken: event),
    );

    if (!settings.supportOfflineAuth) {
      // #154: do NOT forget a still-refreshable session on expiry. On resume
      // both the `expiring` and `expired` timers can be overdue; the old code
      // called `forgetUser()` here unconditionally, which raced — and usually
      // beat — the async refresh kicked off by [handleTokenExpiring], clearing a
      // user whose refresh token was still valid (the real #154 bug, present at
      // the DEFAULT supportOfflineAuth=false). Instead, when the expired token
      // still carries a refresh token, defer the forget decision to the refresh
      // outcome — latching onto the in-flight refresh, or starting one here when
      // the expired timer fired first:
      //   * refresh SUCCESS  -> keep the replaced user (no forget).
      //   * TERMINAL failure -> forget (a genuinely dead session, e.g.
      //                         invalid_grant); [_performAutoRefresh] emits the
      //                         failure event BEFORE this null userChange, so
      //                         observers see the failure before the logout.
      //   * TRANSIENT failure -> RETAIN the user. This mirrors the non-offline
      //                         auto-expiry retention (the expiring path keeps
      //                         the user and only unloads the timers on a
      //                         transient / offline-disabled failure); a dead
      //                         network must not nuke a possibly-valid session.
      // A token with NO refresh token is unrecoverable, so forget immediately as
      // before.
      //
      // #201: on a cache-first cold start the background revalidation owns the
      // keep/discard decision for the just-restored expired token — it runs the
      // full [loadCachedTokens] pass (refresh-if-possible, then the
      // shouldRemoveInvalidToken / offline policy) and reconciles the surfaced
      // user afterwards. Defer to it here so this handler neither races a second
      // refresh nor forgets a user the background pass may still keep.
      if (_cacheFirstRevalidationInFlight) {
        return;
      }
      final refreshToken = event.refreshToken;
      if (refreshToken == null) {
        unawaited(forgetUser());
        return;
      }
      unawaited(
        _autoRefresh(event).then((result) async {
          // Post-dispose safety: never forget (a user mutation + store write)
          // once the manager is torn down. [_performAutoRefresh] already
          // returns the neutral all-null outcome when disposed, so `failureKind`
          // is never `terminal` here; this is a defensive second gate against
          // a dispose that races the completion.
          if (_isDisposed) {
            return;
          }
          if (result.user == null &&
              result.failureKind == OidcTokenRefreshFailureKind.terminal) {
            await forgetUser();
          }
        }),
      );
    } else {
      // Only emit warning if we're actually in offline mode
      // (not just because offline auth is enabled)
      if (offlineModeStartedAt != null) {
        final user = currentUser;
        Duration? tokenExpiredSince;
        if (user != null) {
          final expiry = user.parsedIdToken.claims.expiry;
          if (expiry != null) {
            tokenExpiredSince = clock.now().difference(expiry);
          }
        }

        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.usingExpiredToken,
          message: 'Using expired ID token in offline mode',
          tokenExpiredSince: tokenExpiredSince,
        );
      }
      // If not in offline mode, the token will be automatically refreshed
      // by handleTokenExpiring, so no warning is needed
    }
  }

  @protected
  /// Performs an RFC 8693 Token Exchange at the token endpoint and returns the
  /// raw [OidcTokenResponse].
  ///
  /// This does NOT change the currently logged-in user; it is intended for
  /// obtaining a (possibly delegated/impersonated or downscoped) token for a
  /// downstream resource. When [subjectToken] is omitted it defaults to the
  /// current user's access token. [resource] defaults to
  /// [OidcUserManagerSettings.resource].
  Future<OidcTokenResponse> exchangeToken({
    String? subjectToken,
    String subjectTokenType = OidcConstants_TokenExchange_TokenType.accessToken,
    String? actorToken,
    String? actorTokenType,
    String? requestedTokenType,
    String? audience,
    List<Uri>? resource,
    List<String>? scope,
    Map<String, String>? headers,
    Map<String, dynamic>? extra,
  }) async {
    final tokenEndpoint = discoveryDocument.tokenEndpoint;
    if (tokenEndpoint == null) {
      logAndThrow("This provider doesn't provide a token endpoint.");
    }
    final actualSubjectToken = subjectToken ?? currentUser?.token.accessToken;
    if (actualSubjectToken == null) {
      throw const OidcException(
        'Token exchange requires a subject_token; none was provided and there '
        'is no current access token.',
      );
    }
    final credentials = clientCredentials;
    return (settings.hooks?.token).execute(
      request: OidcTokenHookRequest(
        metadata: discoveryDocument,
        tokenEndpoint: tokenEndpoint,
        credentials: credentials,
        headers: {...?settings.extraTokenHeaders, ...?headers},
        client: httpClient,
        options: settings.options,
        // clientSecret is intentionally NOT passed here: `credentials`
        // above is the single source of client authentication (RFC 6749
        // §2.3). Also setting it on the request would duplicate it into
        // the body even when `credentials` already authenticates via the
        // Basic header (see OidcEndpoints.token).
        request: OidcTokenRequest.tokenExchange(
          subjectToken: actualSubjectToken,
          subjectTokenType: subjectTokenType,
          actorToken: actorToken,
          actorTokenType: actorTokenType,
          requestedTokenType: requestedTokenType,
          audience: audience,
          resource: resource ?? settings.resource,
          scope: scope,
          clientId: credentials.clientId,
          extra: extra,
        ),
      ),
      defaultExecution: (hookRequest) => OidcEndpoints.token(
        tokenEndpoint: hookRequest.tokenEndpoint,
        credentials: hookRequest.credentials,
        headers: hookRequest.headers,
        dpopManager: dpopManager,
        request: hookRequest.request,
        client: hookRequest.client,
      ),
    );
  }

  /// Introspects a token (RFC 7662) using the provider's introspection
  /// endpoint, returning its metadata (notably whether it is `active`).
  ///
  /// Defaults to introspecting the current user's access token when [token] is
  /// omitted. The request is authenticated with the manager's client
  /// credentials.
  Future<OidcIntrospectionResponse> introspectToken({
    String? token,
    String? tokenTypeHint,
    Map<String, String>? headers,
    Map<String, dynamic>? extra,
  }) async {
    final introspectionEndpoint = discoveryDocument.introspectionEndpoint;
    if (introspectionEndpoint == null) {
      logAndThrow("This provider doesn't provide an introspection endpoint.");
    }
    final actualToken = token ?? currentUser?.token.accessToken;
    if (actualToken == null) {
      throw const OidcException(
        'Introspection requires a token; none was provided and there is no '
        'current access token.',
      );
    }
    final credentials = clientCredentials;
    return OidcEndpoints.introspect(
      introspectionEndpoint: introspectionEndpoint,
      credentials: credentials,
      client: httpClient,
      headers: {...?settings.extraTokenHeaders, ...?headers},
      // clientSecret is intentionally NOT passed here: `credentials`
      // above is the single source of client authentication (RFC 6749
      // §2.3). Also setting it on the request would duplicate it into
      // the body even when `credentials` already authenticates via the
      // Basic header (see OidcEndpoints.token).
      request: OidcIntrospectionRequest(
        token: actualToken,
        tokenTypeHint: tokenTypeHint,
        clientId: credentials.clientId,
        extra: extra,
      ),
    );
  }

  /// Validates the front-channel id_token returned by the authorization
  /// endpoint in the OpenID Connect Hybrid flow (OpenID Connect Core §3.3.2):
  /// signature, `nonce`, `c_hash` (binding [code]) and `at_hash` (binding the
  /// front-channel [accessToken], when present). Throws on any failure.
  ///
  /// This is an additional security gate run BEFORE the code is exchanged; the
  /// logged-in user is still built from the token-endpoint response.
  ///
  /// Per OpenID Connect Core §3.1.2.1 / §3.1.3.7 step 12, when [maxAge] was
  /// requested the front-channel id_token MUST carry `auth_time` and is
  /// rejected when `(now - auth_time) > maxAge + expiryTolerance`.
  @protected
  Future<void> validateFrontChannelIdToken({
    required String idToken,
    required String? accessToken,
    required String code,
    required String nonce,
    required OidcProviderMetadata metadata,
    Duration? maxAge,
  }) async {
    final frontChannelUser = await OidcUser.fromIdToken(
      token: OidcToken(
        creationTime: clock.now(),
        idToken: idToken,
        accessToken: accessToken,
        tokenType: accessToken == null ? null : 'Bearer',
      ),
      // The hybrid/implicit front-channel id_token gate, where the signature is
      // the sole protection — honour an explicit `allowedIdTokenAlgorithms` pin.
      allowedAlgorithms: resolveAllowedIdTokenAlgorithms(metadata),
      keystore: keyStore,
      cacheStore: store,
      jwksCacheMaxAge: settings.jwksCacheMaxAge,
      httpClient: httpClient,
    );
    final idTokenNonce =
        frontChannelUser.parsedIdToken.claims[OidcConstants_AuthParameters
                .nonce]
            as String?;
    if (idTokenNonce != nonce) {
      logAndThrow(
        'Hybrid front-channel id_token returned a wrong nonce, possible '
        'replay attack.',
      );
    }
    final errors = validateUser(
      user: frontChannelUser,
      metadata: metadata,
      authorizationCode: code,
      maxAge: maxAge,
    );
    if (errors.isNotEmpty) {
      for (final error in errors) {
        logger.warning(
          'Hybrid front-channel id_token validation problem: $error',
          error,
        );
      }
      logAndThrow(
        'Hybrid front-channel id_token failed validation: ${errors.first}',
      );
    }
  }

  /// Resolves the issuer an id_token's `iss` claim is validated against
  /// (OpenID Connect Core §3.1.3.7 step 2: the `iss` claim MUST exactly match
  /// the OP's Issuer Identifier).
  ///
  /// When [OidcUserManagerSettings.expectedIssuer] is set it is authoritative
  /// and **overrides** the discovery document's [OidcProviderMetadata.issuer];
  /// when null (the default) the advertised `metadata.issuer` is used unchanged,
  /// so the out-of-the-box behavior is identical.
  ///
  /// This lets Microsoft Entra ID multi-tenant (`common`/`organizations`) RPs —
  /// whose discovery `issuer` is a non-substituted template
  /// (`https://login.microsoftonline.com/{tenantid}/v2.0`) that can never equal
  /// the concrete per-tenant `iss` a real id_token carries — pin the concrete
  /// tenant issuer instead of failing the exact-match check.
  @protected
  Uri? resolveExpectedIssuer(OidcProviderMetadata metadata) =>
      settings.expectedIssuer ?? metadata.issuer;

  List<Exception> validateUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
    String? authorizationCode,
    Duration? maxAge,
  }) {
    final claims = user.parsedIdToken.claims;
    // `exp` is REQUIRED (OIDC Core §2). jose's `validate()` force-unwraps the
    // expiry, so guard before calling it: a missing `exp` is a hard validation
    // failure (otherwise a malformed token throws an uncaught TypeError instead
    // of a collected exception, breaking the validation contract).
    final errors = <Exception>[];
    if (claims.expiry == null) {
      errors.add(
        JoseException('id token is missing the required `exp` claim.'),
      );
    } else {
      errors.addAll(
        claims.validate(
          clientId: clientCredentials.clientId,
          issuer: resolveExpectedIssuer(metadata),
          expiryTolerance: settings.expiryTolerance,
        ),
      );
    }
    if (user.token.allowExpiredIdToken) {
      errors.removeWhere(_isJwtExpiredError);
    }
    if (claims.subject == null) {
      errors.add(
        JoseException('id token is missing a `sub` claim.'),
      );
    }
    if (claims.issuedAt == null) {
      errors.add(
        JoseException('id token is missing an `iat` claim.'),
      );
    }

    // Additional OpenID Connect Core §3.1.3.7 id_token checks not covered by
    // the generic JWT validation above.

    // `azp` (authorized party): when present it MUST be the client_id, and when
    // the id_token carries more than one audience, `azp` is REQUIRED.
    final azp = claims['azp'];
    final audiences = claims.audience ?? const <String>[];
    if (azp != null && azp != clientCredentials.clientId) {
      errors.add(
        JoseException(
          'id token `azp` (`$azp`) does not match the client_id '
          '(`${clientCredentials.clientId}`).',
        ),
      );
    }
    if (audiences.length > 1 && azp == null) {
      errors.add(
        JoseException(
          'id token has multiple audiences but is missing the required '
          '`azp` (authorized party) claim.',
        ),
      );
    }

    // `nbf` (not-before): reject a token that is not yet valid, applying the
    // same clock-skew tolerance used for expiry.
    final notBefore = claims.notBefore;
    if (notBefore != null &&
        clock.now().isBefore(notBefore.subtract(settings.expiryTolerance))) {
      errors.add(
        JoseException(
          'id token is not yet valid; `nbf` ($notBefore) is more than the '
          'allowed tolerance (${settings.expiryTolerance}) after now.',
        ),
      );
    }

    // aud strictness (§3.1.3.7): the client_id is always trusted, and
    // `settings.allowedAudiences` extends the trust list. Any OTHER audience
    // means the token was minted for someone else and MUST be rejected.
    final trustedAudiences = <String>{
      clientCredentials.clientId,
      ...?settings.allowedAudiences,
    };
    final untrustedAudiences = audiences
        .where((a) => !trustedAudiences.contains(a))
        .toList();
    if (untrustedAudiences.isNotEmpty) {
      errors.add(
        JoseException(
          'id token contains untrusted audience(s) $untrustedAudiences, not '
          'in the client_id or settings.allowedAudiences.',
        ),
      );
    }

    // `at_hash` (§3.2.2.9): when present alongside an access_token, it MUST be
    // the base64url left-half hash of the access_token using the id_token's
    // signing-alg hash.
    final atHash = claims['at_hash'];
    final accessToken = user.token.accessToken;
    if (atHash is String && accessToken != null) {
      final alg = oidcReadJwtAlg(user.idToken);
      final expected = alg == null
          ? null
          : oidcComputeTokenHash(alg, accessToken);
      // Compare padding-insensitively: the spec mandates unpadded base64url,
      // but tolerate a non-conformant OP that pads rather than false-rejecting.
      if (expected != null && expected != atHash.replaceAll('=', '')) {
        errors.add(
          JoseException('id token `at_hash` does not match the access_token.'),
        );
      }
    }

    // `c_hash` (§3.3.2.11): when an id_token returned from the authorization
    // endpoint alongside an authorization `code` (hybrid flow) carries `c_hash`,
    // it MUST be the base64url left-half hash of the code, using the id_token's
    // signing-alg hash.
    final cHash = claims['c_hash'];
    if (cHash is String && authorizationCode != null) {
      final alg = oidcReadJwtAlg(user.idToken);
      final expected = alg == null
          ? null
          : oidcComputeTokenHash(alg, authorizationCode);
      if (expected != null && expected != cHash.replaceAll('=', '')) {
        errors.add(
          JoseException(
            'id token `c_hash` does not match the authorization code.',
          ),
        );
      }
    }

    // `auth_time` vs `max_age` (§3.1.2.1): when `max_age` was requested, the
    // id_token MUST contain `auth_time`, and the end-user's last authentication
    // MUST NOT be older than `max_age` (within the configured tolerance).
    if (maxAge != null) {
      final authTimeRaw = claims['auth_time'];
      final authTime = authTimeRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (authTimeRaw * 1000).round(),
              isUtc: true,
            )
          : null;
      if (authTime == null) {
        errors.add(
          JoseException(
            '`max_age` was requested but the id token is missing the required '
            '`auth_time` claim.',
          ),
        );
      } else if (clock.now().isAfter(
        authTime.add(maxAge).add(settings.expiryTolerance),
      )) {
        errors.add(
          JoseException(
            'id token `auth_time` ($authTime) is older than the requested '
            'max_age ($maxAge).',
          ),
        );
      }
    }

    return errors;
  }

  bool _isJwtExpiredError(Exception error) =>
      error is JoseException && error.message.startsWith('JWT expired');

  /// This function validates that a user claims
  ///
  /// When [reactToUserInfoUnauthorized] is `true`, a UserInfo `401` (RFC 6750
  /// §3) triggers the #302 recovery reaction: one refresh-token grant + a single
  /// UserInfo retry when a refresh token is available, and — failing that — an
  /// [OidcUserInfoFailedEvent] on [events]. It is enabled only when validating
  /// an already-established session (e.g. resuming a cached user), never during
  /// initial login or immediately after a refresh (where the access token is
  /// freshly issued and a re-refresh would be pointless / could loop).
  @protected
  Future<OidcUser?> validateAndSaveUser({
    required OidcUser user,
    required OidcProviderMetadata metadata,
    String? authorizationCode,
    Duration? maxAge,
    bool reactToUserInfoUnauthorized = false,
  }) async {
    var actualUser = user;
    final errors = validateUser(
      user: actualUser,
      metadata: metadata,
      authorizationCode: authorizationCode,
      maxAge: maxAge,
    );
    OidcUserInfoResponse? userInfoResp;
    var userInfoFailed = false;

    if (errors.isEmpty) {
      final userInfoEP = metadata.userinfoEndpoint;

      if (settings.userInfoSettings.sendUserInfoRequest && userInfoEP != null) {
        try {
          userInfoResp = await OidcEndpoints.userInfo(
            userInfoEndpoint: userInfoEP,
            accessToken: actualUser.token.accessToken!,
            requestMethod: settings.userInfoSettings.requestMethod,
            tokenLocation: settings.userInfoSettings.accessTokenLocation,
            client: httpClient,
            allowedAlgorithms: metadata.userinfoSigningAlgValuesSupported,
            followDistributedClaims:
                settings.userInfoSettings.followDistributedClaims,
            getAccessTokenForDistributedSource:
                settings.userInfoSettings.getAccessTokenForDistributedSource,
            keyStore: keyStore,
            // OIDC Core 5.3.2/5.3.4: validate iss/aud/exp on a signed
            // (verified) UserInfo JWT. The UserInfo `iss` MUST match the
            // id_token `iss`, which for a multi-tenant OP is the concrete
            // per-tenant issuer — so resolve it through the same
            // `resolveExpectedIssuer` pin used for the id_token `iss` check
            // (§3.1.3.7), NOT the advertised (possibly template) metadata
            // issuer.
            expectedIssuer: resolveExpectedIssuer(metadata),
            clientId: clientCredentials.clientId,
            validateSignedResponseClaims:
                settings.userInfoSettings.validateSignedResponseClaims,
            requireSignedResponseIssAud:
                settings.userInfoSettings.requireSignedResponseIssAud,
            claimsExpiryTolerance: settings.expiryTolerance,
            // Present a DPoP-bound access token with the DPoP scheme + an
            // `ath`-bound proof (RFC 9449 §7.1).
            dpopManager: actualUser.token.tokenType?.toUpperCase() == 'DPOP'
                ? dpopManager
                : null,
          );

          logger.info('UserInfo response: ${userInfoResp.src}');
          // OIDC Core §5.3.2: `sub` is REQUIRED in the UserInfo response; a
          // response omitting it MUST be rejected, not silently accepted.
          if (userInfoResp.sub != actualUser.claims.subject) {
            errors.add(
              const OidcException("UserInfo didn't return the same subject."),
            );
          }

          // Successfully contacted server - update last contact time
          recordSuccessfulServerContact(
            newToken: actualUser.token,
            exitOffline: false,
          );
        } on Object catch (e, st) {
          logger.severe('UserInfo endpoint threw an exception!', e, st);
          userInfoFailed = true;

          // Check if this is a network/server error that should enter offline mode
          if (settings.supportOfflineAuth) {
            final errorType = OidcOfflineAuthErrorHandler.categorizeError(e);
            if (errorType == OfflineAuthErrorType.networkUnavailable ||
                errorType == OfflineAuthErrorType.networkTimeout) {
              enterOfflineMode(
                reason: OfflineModeReason.userInfoUnavailable,
                currentToken: actualUser.token,
                error: e,
              );
              emitOfflineAuthWarning(
                warningType: OfflineAuthWarningType.staleUserInfo,
                message: 'Using cached user information due to network error',
              );
            } else if (errorType == OfflineAuthErrorType.serverError) {
              enterOfflineMode(
                reason: OfflineModeReason.serverUnavailable,
                currentToken: actualUser.token,
                error: e,
              );
            }
          }

          // #302: a UserInfo `401` while re-validating an established session
          // means the resource server rejected the access token (revoked or
          // expired) per RFC 6750 §3. The OAuth error rides the
          // `WWW-Authenticate` header, not a JSON body, so it slips past the
          // offline categorization above (which classifies it `unknown`). React
          // only when the caller opted in — a session resume, not an initial
          // login or a just-refreshed token.
          final isUnauthorized =
              e is OidcException && e.rawResponse?.statusCode == 401;
          if (reactToUserInfoUnauthorized && isUnauthorized) {
            // A revoked access token paired with a still-valid refresh token is
            // recoverable without re-authentication: attempt exactly ONE
            // refresh (reusing the #120 machinery, which also emits
            // OidcTokenRefreshFailedEvent on failure). That refresh's own
            // validate-and-save performs the single UserInfo retry with the
            // fresh access token (this method is re-entered with
            // reactToUserInfoUnauthorized defaulting to false, so it cannot
            // loop).
            if (actualUser.token.refreshToken != null) {
              OidcUser? recovered;
              try {
                recovered = await _refreshToken(
                  currentUserOverride: actualUser,
                );
              } on Object {
                // The refresh failed; #120 already surfaced the terminal
                // OidcTokenRefreshFailedEvent. Fall through to emit the
                // UserInfo failure and retain the cached user.
                recovered = null;
              }
              if (recovered != null) {
                // The refresh succeeded and its validate-and-save already
                // retried UserInfo, persisted and published the refreshed user.
                // Nothing failed to surface, so emit no failure event.
                return recovered;
              }
            }

            // No refresh token, or the refresh did not recover the session:
            // surface the rejection (with any RFC 9470 step-up hints from the
            // `WWW-Authenticate` header) so the app can decide to sign out or
            // step up. Consistent with the #120 terminal-retention default, the
            // cached user is NOT forgotten here.
            emitEvent(
              OidcUserInfoFailedEvent.fromError(error: e, stackTrace: st),
            );
          }
        }
      }
    }

    // Check if we're using expired tokens in offline mode
    final hasExpiredTokenError = errors.any(_isJwtExpiredError);

    if (errors.isEmpty ||
        //keep going if the only error is that the token expired,
        //and it's allowed in settings.
        (settings.supportOfflineAuth && errors.every(_isJwtExpiredError))) {
      // Check if offline duration is excessive
      if (settings.supportOfflineAuth && isOfflineDurationExcessive()) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.extendedOfflineDuration,
          message: 'User has been in offline mode for an extended period',
        );
      }

      // If validation passed with no errors and we were in offline mode, exit it
      if (errors.isEmpty && offlineModeStartedAt != null && !userInfoFailed) {
        exitOfflineMode(
          networkRestored: true,
          newToken: actualUser.token,
        );
      }

      // Emit warning if token validation was skipped
      if (hasExpiredTokenError &&
          settings.supportOfflineAuth &&
          isInOfflineMode) {
        emitOfflineAuthWarning(
          warningType: OfflineAuthWarningType.tokenValidationSkipped,
          message: 'Token validation skipped in offline mode',
        );
      }

      // apply userinfo if present
      if (userInfoResp != null) {
        actualUser = actualUser.withUserInfo(userInfoResp.src);
      }
      await saveUser(actualUser);
      userSubject.add(actualUser);
      return actualUser;
    } else {
      for (final element in errors) {
        logger.warning(
          'Found the following problem when validation JWT: $element',
          element,
          StackTrace.current,
        );
      }
      await store.setCurrentNonce(null, managerId: id);

      await store.removeMany(
        OidcStoreNamespace.secureTokens,
        keys: {
          OidcConstants_Store.currentToken,
          OidcConstants_Store.currentUserInfo,
          OidcConstants_Store.currentUserAttributes,
          OidcConstants_AuthParameters.nonce,
        },
        managerId: id,
      );
    }
    return null;
  }

  /// Removes every key of each namespace in [toDelete], except keys whose name
  /// starts with one of [preserveKeyPrefixes].
  ///
  /// The opt-out exists because some entries in a namespace are NOT
  /// user-scoped: the RFC 7591 client registration lives in
  /// [OidcStoreNamespace.secureTokens] (it holds bearer-grade secrets) but
  /// identifies the *app instance*, not the signed-in user, so [forgetUser]
  /// must not destroy it.
  @protected
  Future<void> cleanUpStore({
    required Set<OidcStoreNamespace> toDelete,
    Set<String> preserveKeyPrefixes = const {},
  }) async {
    for (final element in toDelete) {
      final keys = await store.getAllKeys(
        element,
        managerId: id,
      );
      // `getAllKeys` may return an unmodifiable set, so filter into a copy.
      final toRemove = preserveKeyPrefixes.isEmpty
          ? keys
          : keys.where((k) => !preserveKeyPrefixes.any(k.startsWith)).toSet();
      if (toRemove.isEmpty) {
        continue;
      }
      await store.removeMany(
        element,
        keys: toRemove,
        managerId: id,
      );
    }
  }

  /// The discovery document containing openid configuration.
  OidcProviderMetadata get discoveryDocument {
    ensureInit();
    return currentDiscoveryDocument!;
  }

  set discoveryDocument(OidcProviderMetadata value) {
    currentDiscoveryDocument = value;
  }

  @protected
  OidcProviderMetadata? currentDiscoveryDocument;

  /// The discovery document Uri containing openid configuration.
  final Uri? discoveryDocumentUri;

  /// Sidecar key suffix that holds the epoch-millis fetched-at timestamp next
  /// to a persisted discovery document. Mirrors [OidcJwksStoreLoader]'s
  /// `::oidc_jwks_fetched_at` pattern; cannot collide with a real discovery URL
  /// key.
  static const discoveryFetchedAtSuffix = '::oidc_discovery_fetched_at';

  /// Key prefix under which the issued client registration is persisted in
  /// [OidcStoreNamespace.secureTokens], following the `prefix.<id>` scheme of
  /// the PKCE `code_verifier.<state>` entry.
  static const clientRegistrationKeyPrefix = 'client_registration.';

  /// The member of the persisted record holding the RFC 7591 §3.2.1
  /// registration response exactly as the OP returned it.
  static const _recordResponseMember = 'registration';

  /// The member of the persisted record holding the staleness fingerprint of
  /// the request the registration was ISSUED FOR.
  ///
  /// Deliberately stored INSIDE the same value rather than in a sidecar key:
  /// [OidcStore] offers no atomicity across keys (`setMany` is not a
  /// transaction), so two keys can disagree after a torn write and the record
  /// would then claim to have been issued for metadata it was not. One key, one
  /// immutable record — a torn write can only lose the whole thing, which
  /// degrades to a cache miss.
  static const _recordFingerprintMember = 'registered_for';

  /// A loopback host per RFC 8252 §7.3 ("Loopback Interface Redirection").
  static bool _isLoopbackHost(String host) =>
      host == '127.0.0.1' || host == '::1' || host == 'localhost';

  /// Canonicalizes a redirect uri for COMPARISON, erasing the loopback port.
  ///
  /// RFC 8252 §7.3: a native app's loopback redirect gets an ephemeral port at
  /// runtime, and "the authorization server MUST allow any port to be specified
  /// at the time of the request for loopback IP redirect URIs". So
  /// `http://127.0.0.1:52341/cb` and `http://127.0.0.1:8912/cb` are the SAME
  /// registered redirect; comparing them verbatim would mark the persisted
  /// record stale on every desktop launch and mint one OP-side client per run,
  /// forever.
  ///
  /// Only loopback `http` is normalized. Everything else — including a custom
  /// scheme with an authority, and any `https` uri — compares byte-for-byte
  /// (RFC 3986 §6.2.1 Simple String Comparison, which RFC 8252 §7.3 carves out
  /// only for the port).
  static String _canonicalRedirectUriForComparison(Uri uri) {
    if (uri.scheme != 'http' || !_isLoopbackHost(uri.host)) {
      return uri.toString();
    }
    return uri.replace(port: 0).toString();
  }

  /// The OpenID Connect Dynamic Client Registration 1.0 §2 `application_type`
  /// implied by [redirectUris], or null when there are none to judge by.
  ///
  /// §2 states the rule as a client-side constraint, not a server-side one:
  /// "Native Clients MUST only register `redirect_uris` using custom URI
  /// schemes or loopback URLs using the `http` scheme", while Web Clients "MUST
  /// only register URLs using the `https` scheme ... they MUST NOT use
  /// `localhost` as the hostname". So the value is DERIVED from the uris rather
  /// than from the host platform: an Android app whose redirect is an App Link
  /// (`https://app.example.com/callback`) is a `web` application_type by this
  /// rule, and declaring it `native` because it runs on a phone authors a
  /// request a conformant OP must reject.
  ///
  /// §2 also makes `web` the default when the member is omitted, so the only
  /// case that actually needs stating is `native`. It is still emitted
  /// explicitly for both, because it is part of what the client is registered
  /// for and therefore part of the staleness fingerprint.
  static String? _applicationTypeFor(List<Uri> redirectUris) {
    if (redirectUris.isEmpty) {
      return null;
    }
    final allNative = redirectUris.every(
      (uri) =>
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          (uri.scheme == 'http' && _isLoopbackHost(uri.host)),
    );
    return allNative
        ? OidcConstants_ApplicationType.native
        : OidcConstants_ApplicationType.web;
  }

  /// Applies the manager-owned defaults to a registration request, in place.
  ///
  /// RFC 7591 §2: `redirect_uris` is REQUIRED for the flows this library
  /// drives, a registration whose `scope` differs from what the manager asks
  /// for fails at the authorization endpoint, and omitting `grant_types` /
  /// `response_types` registers the client for `authorization_code` / `code`
  /// ONLY — which would leave the manager's own auto-refresh presenting a
  /// grant the client was never registered for. OpenID Connect RP-Initiated
  /// Logout 1.0 §3 requires the same pre-registration for
  /// `post_logout_redirect_uris`.
  ///
  /// Each default only fires when
  /// [OidcDynamicClientRegistrationSettings.buildRequest] left the member null,
  /// which is exactly why the staleness fingerprint below is computed from the
  /// result of this rather than from [OidcUserManagerSettings]: for an app that
  /// sets these itself, the settings never move.
  static OidcClientRegistrationRequest _applyClientRegistrationDefaults(
    OidcClientRegistrationRequest request,
    OidcUserManagerSettings settings,
    OidcDynamicClientRegistrationSettings dcr,
  ) {
    request
      ..redirectUris ??= [settings.redirectUri]
      ..scope ??= settings.scope
      ..grantTypes ??= dcr.grantTypes
      ..responseTypes ??= dcr.responseTypes;
    final postLogoutRedirectUri = settings.postLogoutRedirectUri;
    if (postLogoutRedirectUri != null) {
      request.postLogoutRedirectUris ??= [postLogoutRedirectUri];
    }
    // DERIVED, not platform-keyed: see [_applicationTypeFor]. Runs after
    // `redirect_uris` is filled so it judges the uris that will actually be
    // registered.
    request.applicationType ??= _applicationTypeFor(request.redirectUris ?? []);
    return request;
  }

  /// The staleness fingerprint of an EFFECTIVE registration request (one the
  /// manager's defaults have already been applied to).
  ///
  /// Persisted INSIDE the issued registration's record so a later launch can
  /// tell whether the OP-side client still matches what this app build would
  /// ask for. When it no longer does, re-registering beats authenticating as a
  /// client whose OP-side metadata the OP will now reject.
  ///
  /// Members are restricted to the ones whose change makes the ISSUED client
  /// wrong, and every list is sorted so a pure reordering is not mistaken for a
  /// change:
  ///
  /// - `redirect_uris` — RFC 7591 §2: the OP binds the client to these, so a
  ///   build that changes them turns every authorization request into
  ///   `invalid_redirect_uri`. Compared through
  ///   [_canonicalRedirectUriForComparison], so an RFC 8252 §7.3 loopback port
  ///   that moves every launch is not mistaken for a metadata change.
  /// - `application_type` — OpenID Connect Dynamic Client Registration 1.0 §2:
  ///   it constrains which `redirect_uris` are legal, so a build that flips it
  ///   is registering for something else. Normally it just follows the uris
  ///   (see [_applicationTypeFor]); it is listed because
  ///   [OidcDynamicClientRegistrationSettings.buildRequest] may set it
  ///   explicitly.
  /// - `post_logout_redirect_uris` — OpenID Connect RP-Initiated Logout 1.0 §3
  ///   requires the value sent to the `end_session_endpoint` to have been
  ///   registered.
  /// - `scope` — RFC 7591 §2: an authorization request asking beyond the
  ///   registered scope is refused.
  /// - `grant_types` — RFC 7591 §2: a grant the client is not registered for is
  ///   refused at the token endpoint; this is how a build that starts using the
  ///   refresh or device-code grant reaches the OP.
  /// - `response_types` — RFC 7591 §2 / OpenID Connect Dynamic Client
  ///   Registration 1.0 §2: must stay consistent with `grant_types`.
  ///
  /// Deliberately EXCLUDED, because a change there must NOT orphan the OP-side
  /// client and mint a replacement:
  ///
  /// - `software_statement` (RFC 7591 §2.3) and `jwks` — re-signed / rotated on
  ///   their own schedule, frequently once per call; folding them in would
  ///   re-register on every launch.
  /// - `client_name`, `logo_uri`, `contacts`, `policy_uri`, `tos_uri` and every
  ///   other purely descriptive member — RFC 7592 §2.2 update is the remedy for
  ///   those, not re-registration.
  /// - `token_endpoint_auth_method` — the OP's echoed value is what drives the
  ///   credentials, and a response the manager cannot run as is already caught
  ///   by the conversion check on the read path.
  static String _clientRegistrationFingerprintOf(
    OidcClientRegistrationRequest effectiveRequest,
  ) {
    final json = effectiveRequest.toMap();
    List<String>? sorted(Iterable<Object?>? values) => values == null
        ? null
        : (values.map((e) => e.toString()).toList()..sort());
    List<String>? sortedUris(Iterable<Object?>? values) => values == null
        ? null
        : (values
              .map(
                (e) => _canonicalRedirectUriForComparison(
                  e is Uri ? e : Uri.parse(e.toString()),
                ),
              )
              .toList()
            ..sort());
    return jsonEncode({
      'redirect_uris': sortedUris(json['redirect_uris'] as List?),
      'post_logout_redirect_uris': sortedUris(
        json['post_logout_redirect_uris'] as List?,
      ),
      'scope': sorted(
        (json[OidcConstants_AuthParameters.scope] as String?)?.split(' '),
      ),
      'grant_types': sorted(json['grant_types'] as List?),
      'response_types': sorted(json['response_types'] as List?),
      'application_type': json['application_type'] as String?,
    });
  }

  /// The staleness fingerprint of the registration request this manager would
  /// send to [metadata]'s provider right now.
  ///
  /// Invokes [OidcDynamicClientRegistrationSettings.buildRequest] exactly once;
  /// the value it is compared against is not recomputed but read back from the
  /// store, where it was written at registration time.
  @visibleForTesting
  static String buildClientRegistrationFingerprint(
    OidcUserManagerSettings settings,
    OidcProviderMetadata metadata,
  ) {
    final dcr = settings.dynamicClientRegistration;
    if (dcr == null) {
      throw const OidcException(
        'Cannot fingerprint a client registration: '
        '`OidcUserManagerSettings.dynamicClientRegistration` is null.',
      );
    }
    return _clientRegistrationFingerprintOf(
      _applyClientRegistrationDefaults(
        dcr.buildRequest(metadata),
        settings,
        dcr,
      ),
    );
  }

  OidcClientRegistrationResponse? _clientRegistration;

  /// The RFC 7591 §3.2.1 registration this manager is running as — restored
  /// from the store or issued during [init]. Null when
  /// [OidcUserManagerSettings.dynamicClientRegistration] is disabled.
  ///
  /// Carries `registration_client_uri` / `registration_access_token` for RFC
  /// 7592 client management via [OidcEndpoints] — which is how an app performs
  /// every operation [ensureClientRegistration] lists as a non-goal.
  ///
  /// It does not move once [init] has resolved it: this is the identity every
  /// request the manager sends is built from, for the manager's whole life.
  OidcClientRegistrationResponse? get clientRegistration => _clientRegistration;

  @protected
  String clientRegistrationStoreKey(Uri issuer) =>
      '$clientRegistrationKeyPrefix$issuer';

  /// The issuer the registration is keyed by. Throws when it cannot be
  /// resolved, rather than risk cross-issuer credential reuse.
  Uri _requireClientRegistrationIssuer() =>
      currentDiscoveryDocument?.issuer ??
      _clientRegistrationIssuerFromDiscoveryUri() ??
      logAndThrow(
        'Dynamic client registration is enabled but neither the discovery '
        "document's `issuer` nor an issuer derivable from discoveryDocumentUri "
        'is available to key the persisted registration by.',
      );

  /// RFC 7592 §3 members that are bearer credentials for the client
  /// configuration endpoint, not protocol values.
  static const _managementCredentialMembers = {
    'registration_access_token',
    'registration_client_uri',
  };

  /// The issuer implied by [discoveryDocumentUri], or null.
  ///
  /// The fallback must yield the ISSUER, never the discovery URL itself. The
  /// write path always runs with [currentDiscoveryDocument] loaded, so it keys
  /// on the issuer; a caller that runs before init -- [forgetClientRegistration]
  /// is the one that matters -- would otherwise key on
  /// `https://op/.well-known/openid-configuration` and address a record that
  /// was never written there, removing nothing and reporting success.
  ///
  /// Returns null rather than guessing when the URL is not the §4.1 shape:
  /// deleting under a key the write path would never produce is worse than
  /// saying the issuer is unknown.
  Uri? _clientRegistrationIssuerFromDiscoveryUri() {
    final uri = discoveryDocumentUri;
    if (uri == null) {
      return null;
    }
    return OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(uri);
  }

  /// Swaps in the registered identity: sets [clientRegistration] and
  /// [clientCredentials].
  ///
  /// Only ever called with credentials that were already derived by
  /// [clientCredentialsForRegistration] — the conversion is a validation step
  /// that must happen (and be able to fail) BEFORE anything is stored or
  /// swapped, so it is not repeated here.
  void _applyClientRegistration(
    OidcClientRegistrationResponse response, {
    required OidcClientAuthentication credentials,
  }) {
    clientCredentials = credentials;
    _clientRegistration = response;
  }

  /// Converts a registration [response] into the credentials this manager would
  /// run as, rejecting one this platform must not accept.
  ///
  /// On web the client MUST be public: `OidcStoreNamespace.secureTokens` has no
  /// real secret-storage primitive in a browser (see `OidcDefaultStore`), so a
  /// `client_secret` — and the long-lived RFC 7592 `registration_access_token`
  /// beside it — would land in `localStorage`, readable by any injected script
  /// (OAuth 2.0 for Browser-Based Apps §6.1: browser-based apps "are considered
  /// public clients" and cannot keep a secret). Refusing loudly beats storing
  /// it: the app can then register a public client, or move the confidential
  /// client behind a backend.
  @protected
  OidcClientAuthentication clientCredentialsForRegistration(
    OidcClientRegistrationResponse response,
  ) {
    if (isWeb && response.clientSecret != null) {
      logAndThrow(
        'The provider issued a client_secret to a web client. A browser app '
        'cannot keep one: it would be persisted in localStorage, readable by '
        'any injected script (OAuth 2.0 for Browser-Based Apps §6.1). Register '
        'a public client instead (the manager already asks for '
        'token_endpoint_auth_method "none" on web), or keep the confidential '
        'client on a backend.',
      );
    }
    return OidcClientAuthentication.fromRegistrationResponse(
      response,
      preferredMethod:
          settings.dynamicClientRegistration?.preferredTokenEndpointAuthMethod,
    );
  }

  /// Whether [response]'s issued `client_secret` is past its expiry.
  ///
  /// RFC 7591 §3.2.1: `client_secret_expires_at` of 0 means the secret NEVER
  /// expires. [OidcClientRegistrationResponse.clientSecretExpiresAt] maps that
  /// same 0 to the Unix epoch, which is always in the past — so the
  /// never-expires case MUST be excluded before the comparison, or every such
  /// client would look expired on every launch.
  bool _clientSecretHasExpired(OidcClientRegistrationResponse response) {
    if (response.clientSecretNeverExpires) {
      return false;
    }
    final expiresAt = response.clientSecretExpiresAt;
    return expiresAt != null && expiresAt.isBefore(clock.now().toUtc());
  }

  /// The scope this client is actually REGISTERED for, falling back to
  /// [OidcUserManagerSettings.scope] when dynamic registration is off or the OP
  /// echoed nothing back.
  ///
  /// RFC 7591 §3.2.1 lets the authorization server replace any requested
  /// metadata with values it considers suitable and tells clients to check the
  /// response, so a `scope` the OP narrowed at registration time is what later
  /// requests must ask for — keep asking for the original set and the very
  /// first authorization request fails.
  @protected
  List<String> get effectiveScope {
    final registered = _clientRegistration?.scope;
    if (registered == null) {
      return settings.scope;
    }
    final values = registered.split(' ').where((e) => e.isNotEmpty).toList();
    return values.isEmpty ? settings.scope : values;
  }

  /// The redirect uri this client is actually REGISTERED for (same RFC 7591
  /// §3.2.1 substitution rule as [effectiveScope]).
  ///
  /// [OidcUserManagerSettings.redirectUri] wins whenever the OP registered it,
  /// so apps that register several uris keep the one they configured; only a
  /// server that substituted something else redirects this to its value.
  ///
  /// The match is RFC 8252 §7.3 loopback-port-insensitive: a desktop app whose
  /// loopback listener binds an ephemeral port would otherwise never match the
  /// port it registered with, and this would send the authorization request to
  /// a port nothing is listening on. The uri returned is still the CONFIGURED
  /// one, so the live port is what the OP redirects to — which §7.3 requires
  /// the OP to allow.
  @protected
  Uri get effectiveRedirectUri {
    final registered = _clientRegistration?.redirectUris;
    if (registered == null || registered.isEmpty) {
      return settings.redirectUri;
    }
    return _registersUri(registered, settings.redirectUri)
        ? settings.redirectUri
        : registered.first;
  }

  /// Whether [registered] contains [candidate], comparing loopback `http` uris
  /// without their port (RFC 8252 §7.3) and everything else verbatim (RFC 3986
  /// §6.2.1 Simple String Comparison).
  static bool _registersUri(List<Uri> registered, Uri candidate) {
    final wanted = _canonicalRedirectUriForComparison(candidate);
    return registered.any(
      (e) => _canonicalRedirectUriForComparison(e) == wanted,
    );
  }

  /// The post-logout redirect uri this client is actually REGISTERED for (same
  /// RFC 7591 §3.2.1 substitution rule as [effectiveRedirectUri]).
  ///
  /// OpenID Connect RP-Initiated Logout 1.0 §3 requires the
  /// `post_logout_redirect_uri` sent to the `end_session_endpoint` to have been
  /// registered, so an OP that normalised what it registered rejects every
  /// end-session request built from the raw setting.
  ///
  /// Null stays null: RP-Initiated Logout 1.0 §2 makes the parameter OPTIONAL,
  /// and an app that configured none is asking for no return trip — inventing
  /// one from the registration would turn its logout into a state-carrying
  /// flow that waits for a redirect back.
  @protected
  Uri? get effectivePostLogoutRedirectUri {
    final configured = settings.postLogoutRedirectUri;
    if (configured == null) {
      return null;
    }
    final registered = _clientRegistration?.postLogoutRedirectUris;
    if (registered == null || registered.isEmpty) {
      return configured;
    }
    return _registersUri(registered, configured)
        ? configured
        : registered.first;
  }

  /// Reads + validates the persisted record for [issuer], returning it together
  /// with why (if at all) it is stale, or null when there is nothing usable.
  ///
  /// This method NEVER mutates the store. Every failure — an unreadable store,
  /// an unparseable value, a record with no `client_id`, one that cannot become
  /// [OidcClientAuthentication] — degrades to the same thing: a CACHE MISS that
  /// leaves the key exactly as it was. Three consequences, all deliberate:
  ///
  /// - An unreadable store is not an empty store. An Android
  ///   `KeyPermanentlyInvalidatedException` after a biometric re-enrolment, or
  ///   an iOS keychain still locked at a background launch, must not be
  ///   answered by deleting the only copy of the `client_id` and of the RFC
  ///   7592 §3 `registration_access_token`. That would permanently orphan the
  ///   OP-side client to fix a condition that clears on its own.
  /// - Deleting before a replacement exists turns one failed POST (an offline
  ///   launch) into a permanently lost registration. The replacement overwrites
  ///   the same key when — and only when — it arrives.
  /// - It is what makes the ONE-remove-call-site invariant true: the only
  ///   deletion in the whole DCR path is [forgetClientRegistration], which an
  ///   app calls explicitly.
  Future<_OidcCachedClientRegistration?> _readCachedClientRegistration(
    Uri issuer,
    OidcProviderMetadata metadata,
  ) async {
    final key = clientRegistrationStoreKey(issuer);
    final String? raw;
    try {
      raw = await store.get(
        OidcStoreNamespace.secureTokens,
        key: key,
        managerId: id,
      );
    } on Object catch (e, st) {
      logger.warning(
        'The client registration at key: $key could not be READ (a locked '
        'keychain, an invalidated key). Treating it as a cache miss and '
        'leaving the key untouched — an unreadable store is not an empty one.',
        e,
        st,
      );
      return null;
    }
    if (raw == null) {
      return null;
    }
    final OidcClientRegistrationResponse response;
    final String? issuedFor;
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      response = OidcClientRegistrationResponse.fromJson(
        record[_recordResponseMember] as Map<String, dynamic>,
      );
      issuedFor = record[_recordFingerprintMember] as String?;
    } on Object catch (e, st) {
      logger.warning(
        'Found a client registration record at key: $key, but '
        "couldn't parse it. Registering anew; the bad value is left in place "
        'and will be overwritten by the replacement.',
        e,
        st,
      );
      return null;
    }
    if (response.clientId == null) {
      logger.warning(
        'The client registration record at key: $key has no client_id; '
        'registering anew.',
      );
      return null;
    }
    final OidcClientAuthentication credentials;
    try {
      credentials = clientCredentialsForRegistration(response);
    } on Object catch (e, st) {
      logger.warning(
        'The client registration record at key: $key cannot be converted into '
        'client credentials; registering anew.',
        e,
        st,
      );
      return null;
    }
    if (_clientSecretHasExpired(response)) {
      logger.info(
        'The client registration record at key: $key has an expired '
        'client_secret; registering anew.',
      );
      return (
        response: response,
        credentials: credentials,
        staleness: _OidcClientRegistrationStaleness.secretExpired,
      );
    }
    // The OP registered this client for the `redirect_uris` / `scope` (and the
    // grant/response types, and the application_type) that were current when it
    // was issued. An app update that changes any of them leaves this client
    // authenticating against OP-side values it will now be rejected for — a
    // permanent `invalid_redirect_uri` with no path back. Re-registering costs
    // one POST; silently running as a stale client costs the whole login.
    final expectedFingerprint = buildClientRegistrationFingerprint(
      settings,
      metadata,
    );
    if (issuedFor != expectedFingerprint) {
      logger.info(
        'The client registration record at key: $key was issued for different '
        'metadata (redirect uris / post logout redirect uris / scope / grant '
        'types / response types / application type); registering anew.',
      );
      return (
        response: response,
        credentials: credentials,
        staleness: _OidcClientRegistrationStaleness.superseded,
      );
    }
    return (
      response: response,
      credentials: credentials,
      staleness: _OidcClientRegistrationStaleness.current,
    );
  }

  /// Ensures [clientCredentials] are the dynamically-registered ones, reusing
  /// the persisted record when one is still usable and registering at the
  /// discovery document's `registration_endpoint` otherwise. No-op when DCR is
  /// disabled. Requires [currentDiscoveryDocument] to be loaded.
  ///
  /// Runs at most ONCE per manager: [init] is memoized and this returns
  /// immediately once a registration is applied. That is the whole lifecycle —
  /// the identity resolved here is served verbatim to every later request and
  /// is never re-derived.
  ///
  /// ## Non-goals
  ///
  /// Each of these is a capability the manager deliberately does not AUTOMATE.
  /// None of them is unavailable to apps: the full RFC 7592 client-management
  /// surface already ships as explicit calls on [OidcEndpoints], and
  /// [clientRegistration] hands over the `registration_client_uri` and
  /// `registration_access_token` they need.
  ///
  /// - **No mid-session `client_secret` rotation.** RFC 7592 App. A.1: "the
  ///   authorization server decides the frequency of the credential rotation
  ///   and not the client" — the §2.1 read is an OP-driven affordance, not a
  ///   client obligation, and an OP that conformantly returns the registration
  ///   verbatim leaves a client-driven rotation loop with nothing to make
  ///   progress on. Against an OP that DOES rotate on a schedule the session
  ///   breaks at expiry with a typed failure; the app's handler is
  ///   [OidcEndpoints.readClientConfiguration], or [forgetClientRegistration]
  ///   followed by a fresh `init()`.
  /// - **No automatic re-registration when the OP disowns the client.** RFC
  ///   6749 §5.2 makes `invalid_client` three-way ambiguous ("unknown client,
  ///   no client authentication included, or unsupported authentication
  ///   method") and OpenID Connect Registration §4.4 forbids the 404 that would
  ///   disambiguate it, so there is no reliable trigger to automate on. The
  ///   app's handler is `catch` → [forgetClientRegistration] → retry, or
  ///   [OidcEndpoints.registerClient] driven directly.
  /// - **No RFC 7592 `PUT`/`DELETE`, and no orphan tracking or reaping.** RFC
  ///   7591 §5 assigns cleanup of registered-but-unused clients to the
  ///   authorization server. An app that wants to edit or retire its own
  ///   OP-side client calls [OidcEndpoints.updateClientConfiguration] (RFC 7592
  ///   §2.2) or [OidcEndpoints.deleteClientConfiguration] (§2.3) before
  ///   [forgetClientRegistration].
  ///
  /// Every one of those would need DURABLE control state — a retry budget, an
  /// attempt counter, a rejection verdict, a generation number, a ledger of
  /// minted clients — and every such measure can be destroyed or reset by the
  /// very action it gates. There is none here: the store holds exactly one
  /// immutable record per issuer and nothing else, which is what
  /// `test/dcr_invariants_test.dart` counts.
  ///
  /// If a budget or guard is ever added, the SCOPE it is keyed on MUST be a
  /// digest of the material the gated action would change, so that a
  /// no-progress action yields the SAME scope and the guard stays armed. A
  /// guard keyed on something the gated action rewrites is a live-lock.
  @protected
  Future<void> ensureClientRegistration() async {
    final dcr = settings.dynamicClientRegistration;
    if (dcr == null) {
      return;
    }
    if (_clientRegistration != null) {
      return;
    }
    final issuer = _requireClientRegistrationIssuer();
    final metadata = _requireDiscoveryDocumentForRegistration();
    final cached = await _readCachedClientRegistration(issuer, metadata);
    if (cached != null &&
        cached.staleness == _OidcClientRegistrationStaleness.current) {
      _applyClientRegistration(
        cached.response,
        credentials: cached.credentials,
      );
      return;
    }
    await _registerClient(
      dcr: dcr,
      issuer: issuer,
      metadata: metadata,
      // A superseded registration is still a WORKING credential, so it is what
      // this launch keeps running as if the replacement cannot be obtained. An
      // expired secret is not (the OP retired it), so it is never a fallback.
      fallback: cached?.staleness == _OidcClientRegistrationStaleness.superseded
          ? cached
          : null,
    );
  }

  /// Registers a NEW client at the provider's `registration_endpoint` and makes
  /// it this manager's identity, ignoring whatever is persisted.
  ///
  /// The three steps are deliberately distinct and ordered:
  ///
  /// 1. CONVERT — a response the manager cannot run as (no `client_id`,
  ///    `private_key_jwt`, an unknown method, a `client_secret` on web) throws
  ///    here, before anything is stored or swapped, so it can never become a
  ///    poisoned cache entry that the next [init] replays.
  /// 2. PERSIST — overwriting the previous entry at the same key, so there is
  ///    no window in which neither the old nor the new registration exists.
  /// 3. APPLY — only once the write landed. RFC 7591 registration is NOT
  ///    idempotent: running as a client whose identity could not be written
  ///    down means every later launch mints another one at the OP, unbounded
  ///    and invisible. Failing loudly is the only honest outcome.
  ///
  /// [fallback] is the still-working registration this launch keeps using when
  /// the POST itself cannot be completed (an offline launch, a 5xx). It covers
  /// ONLY that transport failure: a response that arrives but cannot be
  /// converted, or that cannot be persisted, is a real error and is thrown.
  Future<void> _registerClient({
    required OidcDynamicClientRegistrationSettings dcr,
    required Uri issuer,
    required OidcProviderMetadata metadata,
    required _OidcCachedClientRegistration? fallback,
  }) async {
    // Deliberately NOT `OidcProviderMetadata.resolveEndpoint(...,
    // useMtlsAliases: settings.useMtlsEndpointAliases)`: registration runs
    // before the client has any mTLS identity to present.
    final endpoint = metadata.registrationEndpoint;
    if (endpoint == null) {
      logAndThrow(
        'Dynamic client registration is enabled but the provider at '
        '"$issuer" advertises no `registration_endpoint` in its discovery '
        'document. Either disable '
        '`OidcUserManagerSettings.dynamicClientRegistration`, or supply the '
        'endpoint via `OidcUserManagerSettings.metadataSeed`.',
        extra: {
          OidcConstants_Exception.discoveryDocumentUri: discoveryDocumentUri
              ?.toString(),
        },
      );
    }
    final request = _applyClientRegistrationDefaults(
      dcr.buildRequest(metadata),
      settings,
      dcr,
    );
    if (isWeb) {
      // RFC 7591 §2: an omitted `token_endpoint_auth_method` means
      // `client_secret_basic`, i.e. a CONFIDENTIAL client. A browser app is a
      // public client (OAuth 2.0 for Browser-Based Apps §6.1) and has nowhere
      // to keep a secret, so ask for `none` unless the app said otherwise.
      request.tokenEndpointAuthMethod ??=
          OidcConstants_ClientAuthenticationMethods.none;
    }
    // The fingerprint is taken from the request that is about to be SENT, not
    // recomputed later: it must describe what the OP actually registered this
    // client for.
    final fingerprint = _clientRegistrationFingerprintOf(request);
    final OidcClientRegistrationResponse response;
    try {
      response = await OidcEndpoints.registerClient(
        registrationEndpoint: endpoint,
        request: request,
        initialAccessToken: dcr.initialAccessToken,
        client: httpClient,
        headers: dcr.extraHeaders,
      );
    } on Object catch (e, st) {
      if (fallback == null) {
        rethrow;
      }
      logger.warning(
        'Registering a replacement client at "$endpoint" failed; keeping the '
        'previously-issued registration (client_id '
        '"${fallback.response.clientId}") for this session and retrying on a '
        'later launch.',
        e,
        st,
      );
      _applyClientRegistration(
        fallback.response,
        credentials: fallback.credentials,
      );
      return;
    }
    final credentials = clientCredentialsForRegistration(response);
    await _persistClientRegistration(
      issuer,
      response,
      fingerprint: fingerprint,
    );
    _applyClientRegistration(response, credentials: credentials);
  }

  /// The resolved discovery document, which dynamic client registration always
  /// needs (to build the request against, and to key the registration by).
  OidcProviderMetadata _requireDiscoveryDocumentForRegistration() =>
      currentDiscoveryDocument ??
      logAndThrow(
        'Dynamic client registration is enabled but the discovery document '
        'has not been resolved yet; `ensureDiscoveryDocument()` must run '
        'first.',
      );

  /// Serializes the ONE immutable record persisted per issuer: the RFC 7591
  /// §3.2.1 response exactly as the OP returned it, plus the staleness
  /// fingerprint of the request it was ISSUED FOR.
  ///
  /// Both members are written together, in one value, under one key, from
  /// values already in hand — never merged onto, incremented from, or otherwise
  /// derived from what the store currently holds. That is invariant 2 (no
  /// read-modify-write), and it is why [OidcStore] having no compare-and-set
  /// primitive is not a hazard here: a racing writer can only replace the whole
  /// record with another whole record, and a torn write can only produce
  /// garbage that the read path treats as a cache miss.
  ///
  /// Nothing else may join it. A counter, a latch, a rejection verdict, a
  /// generation number or a ledger of minted clients would be durable control
  /// state that the action it gates can reset — the defect this design exists
  /// to make unstateable.
  @visibleForTesting
  static String encodeClientRegistrationRecord(
    OidcClientRegistrationResponse response, {
    required String fingerprint,
    bool redactManagementCredentials = false,
  }) => jsonEncode({
    _recordResponseMember: redactManagementCredentials
        ? (Map<String, dynamic>.of(response.src)
            ..removeWhere((k, _) => _managementCredentialMembers.contains(k)))
        : response.src,
    _recordFingerprintMember: fingerprint,
  });

  /// Persists the record for [issuer]. THE ONLY WRITE of the registration key.
  ///
  /// A store that cannot take the write (a locked keychain, a full disk) throws
  /// a typed [OidcException] rather than passing the raw platform error up: the
  /// caller must not apply a registration it could not record. RFC 7591
  /// registration is not idempotent, so running as an identity that was never
  /// written down mints another OP-side client on every launch.
  Future<void> _persistClientRegistration(
    Uri issuer,
    OidcClientRegistrationResponse response, {
    required String fingerprint,
  }) async {
    final key = clientRegistrationStoreKey(issuer);
    try {
      await store.set(
        OidcStoreNamespace.secureTokens,
        key: key,
        value: encodeClientRegistrationRecord(
          response,
          fingerprint: fingerprint,
          // The web guard refuses an issued client_secret, but the RFC 7592
          // members are bearer credentials for the same client and were being
          // written whole via `response.src`. On web `secureTokens` is
          // localStorage unless the app supplies FlutterSecureStorage, so any
          // injected script could read them and take over the registration.
          // Refusing them costs RFC 7592 management on web, which the manager
          // does not automate anyway -- the app calls OidcEndpoints directly
          // and can hold the token itself if it accepts that risk.
          redactManagementCredentials: isWeb,
        ),
        managerId: id,
      );
    } on Object catch (e, st) {
      logAndThrow(
        'The client registration issued by "$issuer" (client_id '
        '"${response.clientId}") could not be persisted at key: $key. It is '
        'NOT applied: RFC 7591 registration is not idempotent, so continuing '
        'with an identity that was never written down would mint another '
        'OP-side client on every launch.',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Deletes the persisted client registration for the current issuer. THE ONLY
  /// REMOVAL of the registration key.
  ///
  /// This is the app's escape hatch out of every non-goal listed on
  /// [ensureClientRegistration]: an OP that rotated the `client_secret` on its
  /// own schedule, one that deleted or disabled the client, one that re-issued
  /// it under a new `client_id`. All of them surface as a typed failure from a
  /// back-channel call; the handler is
  ///
  /// ```dart
  /// // ... catch the OidcException, then:
  /// await manager.forgetClientRegistration();
  /// // build a new manager (init() is memoized) and init() it: the next
  /// // init registers a fresh client.
  /// ```
  ///
  /// Call [OidcEndpoints.deleteClientConfiguration] (RFC 7592 §2.3) with
  /// [clientRegistration]'s `registration_client_uri` /
  /// `registration_access_token` FIRST if the OP-side client should be retired
  /// too — this only forgets it locally, and RFC 7591 §5 leaves cleanup of a
  /// registered-but-unused client to the authorization server.
  ///
  /// Deliberately NOT called by [forgetUser]: the registration is app-instance
  /// identity, not user identity.
  ///
  /// It touches the STORE only. The identity this manager is already running as
  /// is left exactly as it is, because a manager whose `clientCredentials` were
  /// swapped out mid-session would have no valid identity to fall back to —
  /// [init] is memoized and the constructor seed is long gone. Forgetting is
  /// therefore a decision about the NEXT launch, and that is the only state it
  /// changes.
  Future<void> forgetClientRegistration() async {
    final key = clientRegistrationStoreKey(_requireClientRegistrationIssuer());
    await store.remove(
      OidcStoreNamespace.secureTokens,
      key: key,
      managerId: id,
    );
  }

  /// Cache-only counterpart used by the [OidcInitMode.cacheFirst] path (no
  /// network). Returns true when DCR is disabled or a usable persisted
  /// registration was applied; false when the caller must fall back to the
  /// blocking path.
  ///
  /// A stale entry answers false — replacing it needs the network, which this
  /// path does not have — but it is left on disk, so the blocking path can
  /// still fall back to it when the replacement cannot be issued.
  Future<bool> _loadClientRegistrationFromCacheOnly() async {
    if (settings.dynamicClientRegistration == null) {
      return true;
    }
    if (_clientRegistration != null) {
      return true;
    }
    final issuer = _requireClientRegistrationIssuer();
    final cached = await _readCachedClientRegistration(
      issuer,
      _requireDiscoveryDocumentForRegistration(),
    );
    if (cached == null ||
        cached.staleness != _OidcClientRegistrationStaleness.current) {
      return false;
    }
    _applyClientRegistration(cached.response, credentials: cached.credentials);
    return true;
  }

  /// Merges [OidcUserManagerSettings.metadataSeed] UNDER [doc] (doc members
  /// override the seed),
  /// matching oidc-client-ts `metadataSeed` semantics. No-op when no seed is set
  /// or when using an eagerly-supplied document (that path is a full override).
  OidcProviderMetadata _applyMetadataSeed(OidcProviderMetadata doc) {
    final seed = settings.metadataSeed;
    // The eager (non-`.lazy`) constructor path is a full override; the seed only
    // augments a fetched/cached document (discoveryDocumentUri != null).
    if (seed == null || discoveryDocumentUri == null) {
      return doc;
    }
    return OidcProviderMetadata.fromJson({...seed.src, ...doc.src});
  }

  /// Parses a persisted discovery document [OidcProviderMetadata] from [raw],
  /// removing the stored key on a parse failure. Returns `null` when [raw] is
  /// null or unparseable.
  Future<OidcProviderMetadata?> _parseCachedDiscovery(
    String key,
    String? raw,
  ) async {
    if (raw == null) {
      return null;
    }
    try {
      return OidcProviderMetadata.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (e, st) {
      logger.warning(
        "Found a cached discovery document at key: $key, but couldn't parse it.\n"
        'Removing the bad key now.\n'
        'cached document: $raw',
        e,
        st,
      );
      await store
          .remove(OidcStoreNamespace.discoveryDocument, key: key)
          .onError((error, stackTrace) => null);
      return null;
    }
  }

  /// Loads the discovery document from the [OidcStore] only (no network),
  /// applying [OidcUserManagerSettings.metadataSeed] and issuer validation.
  /// Returns `true` when a usable document is available (either eagerly-supplied
  /// or cached), `false` otherwise. Used by the [OidcInitMode.cacheFirst] path.
  Future<bool> _loadDiscoveryFromCacheOnly() async {
    if (currentDiscoveryDocument != null) {
      // Eagerly-supplied document.
      _validateDiscoveryIssuer();
      return true;
    }
    final uri = discoveryDocumentUri;
    if (uri == null) {
      return false;
    }
    final key = uri.toString();
    final cached = await _parseCachedDiscovery(
      key,
      await store.get(
        OidcStoreNamespace.discoveryDocument,
        key: key,
        managerId: id,
      ),
    );
    if (cached == null) {
      return false;
    }
    currentDiscoveryDocument = _applyMetadataSeed(cached);
    _validateDiscoveryIssuer();
    return true;
  }

  /// Returns `true` when the persisted discovery document is older than
  /// [OidcUserManagerSettings.discoveryDocumentMaxAge] (or its age is unknown).
  /// Eagerly-supplied documents (no [discoveryDocumentUri]) are never stale.
  Future<bool> _isDiscoveryStale() async {
    final uri = discoveryDocumentUri;
    if (uri == null) {
      return false;
    }
    final maxAge = settings.discoveryDocumentMaxAge;
    if (maxAge <= Duration.zero) {
      return true;
    }
    final sidecar = await store.get(
      OidcStoreNamespace.discoveryDocument,
      key: '$uri$discoveryFetchedAtSuffix',
      managerId: id,
    );
    final ms = sidecar == null ? null : int.tryParse(sidecar);
    if (ms == null) {
      return true;
    }
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return clock.now().toUtc().difference(fetchedAt) > maxAge;
  }

  /// Background (cache-first) discovery refresh: re-fetches from the network
  /// only when the persisted document is stale, keeping the cached document as
  /// an offline fallback on failure.
  Future<void> _refreshDiscoveryInBackgroundIfStale() async {
    final uri = discoveryDocumentUri;
    if (uri == null) {
      return;
    }
    if (!await _isDiscoveryStale()) {
      return;
    }
    await _fetchAndApplyDiscovery(uri);
    // A refreshed document may advertise a new jwks_uri.
    setupKeyStore();
  }

  /// Fetches the discovery document from the network for [uri], verifies signed
  /// metadata (when enabled), validates the issuer, persists the document with a
  /// fresh fetched-at timestamp, and applies
  /// [OidcUserManagerSettings.metadataSeed] in memory.
  ///
  /// On a network failure the previously-loaded [currentDiscoveryDocument]
  /// (cache) is kept as an offline fallback when present; only when there is no
  /// fallback does this throw.
  Future<void> _fetchAndApplyDiscovery(Uri uri) async {
    final key = uri.toString();
    var fetched = false;
    try {
      currentDiscoveryDocument = await OidcEndpoints.getProviderMetadata(
        uri,
        client: httpClient,
      );
      fetched = true;
    } catch (e, st) {
      //maybe there is no internet.
      if (currentDiscoveryDocument == null) {
        logAndThrow(
          "Couldn't fetch the discoveryDocument",
          error: e,
          stackTrace: st,
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
      // Keep the cached document as an offline fallback (do NOT re-persist or
      // refresh its timestamp — it stays as stale as it really is). Still
      // issuer-validate it: a poisoned cache must never be trusted, even offline
      // (mirrors the pre-refactor validate-before-use behavior).
      _validateDiscoveryIssuer();
      currentDiscoveryDocument = _applyMetadataSeed(currentDiscoveryDocument!);
      return;
    }

    // RFC 8414 §2.1/§3.2: when enabled, verify the document's `signed_metadata`
    // JWT (if present) and merge its verified claims OVER the plain JSON BEFORE
    // issuer-validation and persistence, so a signed-metadata issuer change is
    // still issuer-validated and only a verified+validated document is cached.
    if (settings.verifySignedMetadata &&
        currentDiscoveryDocument!.src.containsKey(
          OidcConstants_ProviderMetadata.signedMetadata,
        )) {
      try {
        currentDiscoveryDocument =
            await OidcEndpoints.verifyAndMergeSignedMetadata(
              metadata: currentDiscoveryDocument!,
              expectedIssuer:
                  settings.expectedIssuer ??
                  OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(uri),
              allowedAlgorithms:
                  settings.allowedSignedMetadataAlgorithms ??
                  currentDiscoveryDocument!.idTokenSigningAlgValuesSupported,
              cacheStore: store,
              client: httpClient,
              jwksCacheMaxAge: settings.jwksCacheMaxAge,
            );
      } on OidcException catch (e, st) {
        // Always fail-closed: refuse to use the document. There is no
        // unverified-fallback opt-out (mirrors id_token handling).
        logAndThrow(
          'Failed to verify the discovery `signed_metadata` JWT '
          '(RFC 8414 §2.1); refusing to use the document.',
          error: e,
          stackTrace: st,
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
    }

    // Validate the final document (network-sourced) BEFORE persisting, so a
    // mismatched/poisoned document is never written to the store.
    _validateDiscoveryIssuer();

    // Persist the raw fetched document + a fresh fetched-at timestamp together
    // (mirrors OidcJwksStoreLoader). Only reached on a successful fetch, so the
    // TTL timestamp never advances while serving a stale offline copy.
    if (fetched) {
      await store.setMany(
        OidcStoreNamespace.discoveryDocument,
        values: {
          key: jsonEncode(currentDiscoveryDocument!.src),
          '$key$discoveryFetchedAtSuffix': clock
              .now()
              .toUtc()
              .millisecondsSinceEpoch
              .toString(),
        },
        managerId: id,
      );
    }

    // Apply the seed in memory AFTER persistence so the seed is never baked
    // into the cache (fetched/cached values still override it).
    currentDiscoveryDocument = _applyMetadataSeed(currentDiscoveryDocument!);
  }

  /// First gets the cached discoveryDocument if any
  /// (based on discoveryDocumentUri).
  ///
  /// Then tries to get it from the network, unless a cached document exists and
  /// is still within [OidcUserManagerSettings.discoveryDocumentMaxAge] (in which
  /// case the network fetch is skipped).
  @protected
  Future<void> ensureDiscoveryDocument() async {
    final uri = discoveryDocumentUri;

    if (currentDiscoveryDocument != null) {
      // An eagerly-supplied discoveryDocument (eager constructor, where
      // discoveryDocumentUri is null) is still validated against
      // `settings.expectedIssuer`.
      _validateDiscoveryIssuer();
      return;
    }

    if (uri == null) {
      logAndThrow(
        'Impossible case of no discoveryDocument and no discoveryDocumentUri',
      );
    }
    final key = uri.toString();
    final cachedValues = await store.getMany(
      OidcStoreNamespace.discoveryDocument,
      keys: {key, '$key$discoveryFetchedAtSuffix'},
      managerId: id,
    );
    final cachedMetadata = await _parseCachedDiscovery(
      key,
      cachedValues[key],
    );
    // Keep the cached document as the offline fallback for the network fetch.
    currentDiscoveryDocument = cachedMetadata;

    // TTL cache: within `discoveryDocumentMaxAge`, skip the network fetch and
    // use the cached document (matching the JWKS loader's timestamp scheme).
    if (cachedMetadata != null &&
        settings.discoveryDocumentMaxAge > Duration.zero) {
      final tsRaw = cachedValues['$key$discoveryFetchedAtSuffix'];
      final ms = tsRaw == null ? null : int.tryParse(tsRaw);
      if (ms != null) {
        final fetchedAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        final age = clock.now().toUtc().difference(fetchedAt);
        if (age <= settings.discoveryDocumentMaxAge) {
          currentDiscoveryDocument = _applyMetadataSeed(cachedMetadata);
          _validateDiscoveryIssuer();
          return;
        }
      }
    }

    await _fetchAndApplyDiscovery(uri);
  }

  /// OIDC Discovery 1.0 §4.3 / RFC 8414 §3.3: the discovery document's `issuer`
  /// MUST be identical to the issuer used to fetch it.
  ///
  /// Controlled by [OidcUserManagerSettings.strictIssuerValidation]: when
  /// `true`, a mismatch (or a missing `issuer`) throws; when `false` (the
  /// default), a mismatch is only logged as a warning and the document is still
  /// used (preserves Entra multi-tenant / B2C compatibility).
  void _validateDiscoveryIssuer() {
    final strict = settings.strictIssuerValidation;
    // Resolve the expected issuer: explicit `expectedIssuer` is authoritative;
    // otherwise derive it from the well-known URL (the inverse of the builder
    // every in-repo call site uses).
    final uri = discoveryDocumentUri;
    final expected =
        settings.expectedIssuer ??
        (uri == null
            ? null
            : OidcUtils.getIssuerFromOpenIdConfigWellKnownUri(uri));

    if (expected == null) {
      if (strict) {
        logger.warning(
          'strictIssuerValidation is enabled but no expected issuer could be '
          'determined (no `expectedIssuer` was set and the discovery URL could '
          'not be inverted, e.g. an eagerly-supplied document or a custom '
          'discovery URL); skipping the §4.3 issuer check.',
        );
      }
      return;
    }

    final actual = currentDiscoveryDocument?.issuer;
    if (actual == null) {
      if (strict) {
        logAndThrow(
          'Discovery document is missing the required `issuer` member '
          '(OIDC Discovery §3 / RFC 8414 §2).',
          extra: {
            OidcConstants_Exception.discoveryDocumentUri: uri,
          },
        );
      }
      logger.warning(
        'Discovery document is missing the required `issuer` member; '
        'strictIssuerValidation is disabled so it is being used anyway.',
      );
      return;
    }

    if (OidcUtils.issuersAreIdentical(expected, actual)) {
      return;
    }
    if (strict) {
      logAndThrow(
        'Issuer mismatch (OIDC Discovery §4.3 / RFC 8414 §3.3): discovery '
        'issuer ($actual) != expected issuer ($expected).',
        extra: {
          OidcConstants_Exception.discoveryDocumentUri: uri,
        },
      );
    }
    logger.warning(
      'Issuer mismatch (OIDC Discovery §4.3 / RFC 8414 §3.3): discovery issuer '
      '($actual) != expected issuer ($expected); strictIssuerValidation is '
      'disabled so the document is being used anyway.',
    );
  }

  /// Loads and verifies the tokens.
  ///
  /// When [forceRebuild] is `true`, the user is rebuilt from scratch (verifying
  /// the id_token signature) rather than replacing the token on the current
  /// user — used by cache-first background revalidation, whose surfaced user was
  /// restored locally without verification.
  @protected
  Future<void> loadCachedTokens({bool forceRebuild = false}) async {
    final usedKeys = <String>{
      OidcConstants_Store.currentToken,
      OidcConstants_Store.currentUserAttributes,
      OidcConstants_Store.currentUserInfo,
    };

    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: usedKeys,
      managerId: id,
    );
    final rawToken = tokens[OidcConstants_Store.currentToken];
    final rawUserInfo = tokens[OidcConstants_Store.currentUserInfo];
    final rawAttributes = tokens[OidcConstants_Store.currentUserAttributes];
    if (rawToken == null) {
      return;
    }

    // Captured (when available) so the discard branch can consult
    // [OidcUserManagerSettings.shouldRemoveInvalidToken] with the same user +
    // validation errors that were evaluated.
    OidcUser? policyUser;
    var policyErrors = const <Exception>[];
    try {
      final decodedAttributes = rawAttributes == null
          ? null
          : jsonDecode(rawAttributes) as Map<String, dynamic>;
      final decodedUserInfo = rawUserInfo == null
          ? null
          : jsonDecode(rawUserInfo) as Map<String, dynamic>;
      final decodedToken = jsonDecode(rawToken) as Map<String, dynamic>;
      final token = OidcToken.fromJson(decodedToken);
      final metadata = discoveryDocument;
      var loadedUser = await createUserFromToken(
        token: token,
        // nonce is only checked for new tokens.
        nonce: null,
        attributes: decodedAttributes,
        userInfo: decodedUserInfo,
        metadata: metadata,
        validateAndSave: false,
        ignoreCurrentUser: forceRebuild,
      );
      if (loadedUser != null) {
        final validationErrors = validateUser(
          user: loadedUser,
          metadata: metadata,
        );
        policyUser = loadedUser;
        policyErrors = validationErrors;

        // Developer control (#205): let callers override whether the loaded
        // token is acceptable, evaluated with the validation error list BEFORE
        // the default refresh / discard policy. `null` keeps current behavior.
        final acceptable = settings.isLoadedTokenAcceptable?.call(
          loadedUser,
          validationErrors,
        );
        if (acceptable == true) {
          // Explicitly accepted: surface the loaded user as-is, skipping the
          // refresh / userinfo round-trips.
          await saveUser(loadedUser);
          userSubject.add(loadedUser);
          return;
        }
        if (acceptable == false) {
          // Explicitly rejected: fall through to the discard branch.
          loadedUser = null;
        } else {
          final idTokenNeedsRefresh = validationErrors
              .whereType<JoseException>()
              .any((element) => element.message.startsWith('JWT expired'));

          if (token.refreshToken != null &&
              (idTokenNeedsRefresh || token.isAccessTokenExpired())) {
            // #120: _refreshToken owns the failure signalling and offline
            // handling for this path now. Passing source: startupLoad makes the
            // single OidcTokenRefreshFailedEvent it emits carry the correct
            // source, and its internal handleOfflineEligibleFailure is the
            // single offline-handling pass. A failure that offline mode absorbs
            // returns the cached [loadedUser] (so we continue with cached
            // state); a terminal / offline-disabled failure rethrows to the
            // outer catch below, which then consults shouldRemoveInvalidToken
            // (#205). This removes the previous double-signal (two events + two
            // offline-handling passes) per startup refresh failure.
            final refreshedUser = await _refreshToken(
              overrideRefreshToken: token.refreshToken,
              currentUserOverride: loadedUser,
              source: OidcTokenRefreshSource.startupLoad,
            );
            if (refreshedUser != null) {
              loadedUser = refreshedUser;
            }
          }
          // [loadedUser] is provably non-null here (this branch is only entered
          // with a non-null user and only ever reassigns it to a non-null
          // refreshed user), so it is passed directly to validation.
          loadedUser = await validateAndSaveUser(
            user: loadedUser,
            metadata: metadata,
            // #302: this validates a resumed (already-established) session, so a
            // UserInfo 401 from a revoked access token should trigger the
            // recover-via-refresh + typed-event reaction.
            reactToUserInfoUnauthorized: true,
          );
        }
      }

      if (loadedUser == null) {
        logAndThrow(
          'Found a cached token, but the user could not be created or validated',
        );
      }
    } on Object catch (_) {
      // Developer control (#205): let callers override the keep/discard
      // decision. `null` (default) removes the tokens unless offline auth is
      // enabled — the current behavior, preserved exactly.
      final shouldRemove = policyUser == null
          ? !settings.supportOfflineAuth
          : (settings.shouldRemoveInvalidToken?.call(
                  policyUser,
                  policyErrors,
                ) ??
                !settings.supportOfflineAuth);
      if (shouldRemove) {
        // remove invalid tokens, so that they don't get used again.
        await store.removeMany(
          OidcStoreNamespace.secureTokens,
          keys: usedKeys,
          managerId: id,
        );
      }
    }
  }

  /// Loads the current state, and checks if it has a result.
  ///
  /// if this returns `true`, a result has been found, and there is no need to
  /// load cached tokens.
  @protected
  Future<bool> loadStateResult() async {
    final statesWithResponses = await store.getStatesWithResponses();
    if (statesWithResponses.isEmpty) {
      return false;
    }

    for (final entry in statesWithResponses.entries) {
      final (stateData: stateDataRaw, stateResponse: stateResponseRaw) =
          entry.value;

      final stateResponseUrl = Uri.tryParse(stateResponseRaw);
      if (stateResponseUrl == null) {
        continue;
      }

      final stateData = OidcState.fromStorageString(stateDataRaw);
      if (stateData.managerId != id) {
        continue; // this state is not for this manager.
      }
      switch (stateData) {
        case OidcAuthorizeState():
          final resp = await OidcEndpoints.parseAuthorizeResponse(
            responseUri: stateResponseUrl,
            // Enables JARM: a signed `response` JWT is verified against the
            // provider keys (never `alg:none`) and its `iss`/`aud`/`exp` are
            // enforced before its inner parameters are used.
            keyStore: keyStore,
            allowedAlgorithms:
                discoveryDocument.idTokenSigningAlgValuesSupported,
            expectedAudience: clientCredentials.clientId,
            // RFC 9207: validate `iss` (incl. on error redirects) before the
            // server-error throw; require it when the AS advertises support.
            expectedIssuer: discoveryDocument.issuer,
            requireIss: discoveryDocument
                .authorizationResponseIssParameterSupportedOrDefault,
          );

          await handleSuccessfulAuthResponse(
            response: resp,
            grantType: resp.code == null
                ? OidcConstants_GrantType.implicit
                : OidcConstants_GrantType.authorizationCode,
            metadata: discoveryDocument,
          );
          return true;
        case OidcEndSessionState():
          final resp = OidcEndSessionResponse.fromJson(
            stateResponseUrl.queryParameters,
          );
          await handleEndSessionResponse(result: resp);
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  /// returns true if there was a logout request.
  @protected
  Future<bool> loadLogoutRequests() async {
    final request = await store.getCurrentFrontChannelLogoutRequest();
    if (request == null) {
      return false;
    }
    final requestUri = Uri.tryParse(request);
    if (requestUri == null) {
      return false;
    }
    final requestType =
        requestUri.queryParameters[OidcConstants_Store.requestType];
    if (requestType != OidcConstants_Store.frontChannelLogout) {
      return false;
    }
    final parsedRequest = OidcFrontChannelLogoutIncomingRequest.fromJson(
      requestUri.queryParameters,
    );
    if (parsedRequest.managerId != id) {
      //this request is not for this manager.
      return false;
    }
    await handleFrontChannelLogoutRequest(parsedRequest);
    return true;
  }

  /// true if [init] has been called with no exceptions.
  bool get didInit => initMemoizer.hasRun;

  /// A future that completes when [init] completes.
  Future<void> get initFuture => initMemoizer.future;

  @protected
  AsyncMemoizer<void> initMemoizer = AsyncMemoizer();

  @protected
  final toDispose = <StreamSubscription<dynamic>>[];

  @protected
  Future<void> clearUnusedStates() async {
    await OidcState.clearStaleState(
      store: store,
      age: const Duration(days: 1),
    );
  }

  /// Registers the current [discoveryDocument]'s `jwks_uri` with [keyStore].
  ///
  /// The symmetric HS* key (RFC 7518 §3.2, the `client_secret` octets) is
  /// deliberately NOT added here: [keyStore] derives it from the CURRENT
  /// [clientCredentials] on every lookup instead. Adding it eagerly would leave
  /// the pre-registration seed's secret able to verify id_tokens for the
  /// manager's whole life, since [JsonWebKeyStore] cannot remove a key.
  @protected
  void setupKeyStore() {
    final jwksUri = currentDiscoveryDocument?.jwksUri;
    if (jwksUri != null) {
      keyStore.addKeySetUrl(jwksUri);
    }
  }

  /// Attaches the manager's lifecycle stream subscriptions (front-channel
  /// logout, token-refresh scheduling, session monitoring, token-expiry, and
  /// native browser events). Shared by both `init()` code paths.
  @protected
  void attachLifecycleListeners() {
    final frontChannelLogoutUri = settings.frontChannelLogoutUri;
    if (frontChannelLogoutUri != null) {
      toDispose.add(
        listenToFrontChannelLogoutRequests(
          frontChannelLogoutUri,
          settings.frontChannelRequestListeningOptions,
        ).listen(handleFrontChannelLogoutRequest),
      );
    }

    //start listening to token events, if the user enabled them.

    toDispose
      ..add(
        userSubject.listen(
          (value) => listenToTokenRefreshIfSupported(tokenEvents, value),
        ),
      )
      ..add(userSubject.listen(listenToUserSessionIfSupported))
      ..add(tokenEvents.expiring.listen(handleTokenExpiring))
      ..add(tokenEvents.expired.listen(handleTokenExpired))
      // Surface native browser-layer observability through events().
      ..add(listenToNativeBrowserEvents().listen(emitEvent));
  }

  /// Initializes the user manager, this also gets the [discoveryDocument] if it
  /// wasn't provided.
  ///
  /// The restore behavior depends on [OidcUserManagerSettings.initMode]:
  /// - [OidcInitMode.cacheFirst] (the **default**): a cached user is restored
  ///   by a pure local deserialize (no network) and `init()` completes
  ///   immediately, then the user is revalidated in the background. When there
  ///   is no cached user / cached discovery document, this transparently falls
  ///   back to the blocking network path below. Note this surfaces the user
  ///   through [userChanges] TWICE on a cold start (restored-then-revalidated) —
  ///   see [OidcInitMode.cacheFirst] for why the second emission is intentional.
  /// - [OidcInitMode.blockingValidate]: the previous semantics — block until
  ///   the discovery document is fetched and the cached token fully re-verified.
  ///   Not a byte-for-byte replica of the pre-1.0 network behavior unless
  ///   combined with `discoveryDocumentMaxAge: Duration.zero` (the discovery
  ///   document is otherwise served from its TTL cache).
  Future<void> init() {
    return initMemoizer.runOnce(() async {
      await store.init();
      if (settings.initMode == OidcInitMode.cacheFirst &&
          await _tryCacheFirstInit()) {
        attachLifecycleListeners();
        return;
      }
      // Blocking / network path (the [OidcInitMode.blockingValidate] semantics,
      // also the fallback when cache-first has nothing to restore).
      await ensureDiscoveryDocument();
      // Must precede `loadStateResult()` and `loadCachedTokens()`, which
      // validate `aud` against `clientCredentials.clientId`. (The HS* `oct`
      // verification key needs no ordering: [keyStore] derives it from the
      // current credentials at lookup time.)
      await ensureClientRegistration();
      setupKeyStore();
      await clearUnusedStates();
      if (!await loadLogoutRequests()) {
        //no logout requests.
        if (!await loadStateResult()) {
          //no state results.
          await loadCachedTokens();
        }
      }
      attachLifecycleListeners();
    });
  }

  /// Attempts the [OidcInitMode.cacheFirst] restore: deserialize the cached user
  /// purely from the [OidcStore] (no network) and schedule background
  /// revalidation. Returns `false` (leaving state untouched for the blocking
  /// path) when there is nothing to restore locally, a redirect/logout result
  /// is pending, or the local restore fails.
  Future<bool> _tryCacheFirstInit() async {
    // No cached token → nothing to restore; use the network path.
    final rawToken = await store.get(
      OidcStoreNamespace.secureTokens,
      key: OidcConstants_Store.currentToken,
      managerId: id,
    );
    if (rawToken == null) {
      return false;
    }
    // A pending redirect result or front-channel logout is the interactive
    // path (it needs the network); defer to the blocking path.
    if ((await store.getStatesWithResponses()).isNotEmpty) {
      return false;
    }
    if (await store.getCurrentFrontChannelLogoutRequest() != null) {
      return false;
    }
    // Need a locally-available discovery document (no network) to build the
    // user; otherwise fall back to the network path.
    if (!await _loadDiscoveryFromCacheOnly()) {
      return false;
    }
    if (!await _loadClientRegistrationFromCacheOnly()) {
      // Reset the cache-only document so the blocking path re-runs the full
      // TTL/network discovery logic (`ensureDiscoveryDocument()` returns early
      // when `currentDiscoveryDocument` is already set). Mirrors the
      // `restored == null` handling below.
      if (discoveryDocumentUri != null) {
        currentDiscoveryDocument = null;
      }
      return false;
    }
    setupKeyStore();
    await clearUnusedStates();
    final restored = await _restoreCachedUserLocally();
    if (restored == null) {
      // Couldn't restore locally; reset the (cache-only) discovery document so
      // the network path re-fetches it. Keep an eagerly-supplied document.
      if (discoveryDocumentUri != null) {
        currentDiscoveryDocument = null;
      }
      return false;
    }
    // #201: arm the gate BEFORE returning (so it is set before `init()` attaches
    // the lifecycle listeners and the restored-user replay arms the expiry
    // timers). The background pass owns the first refresh; the expiry-driven
    // auto-refresh stays suppressed until [_scheduleBackgroundRevalidation]
    // clears the gate.
    //
    // The future is captured into [_cacheFirstRevalidationFuture] in the SAME
    // synchronous step (calling an async function runs it up to its first
    // `await` and returns its Future immediately) so there is never a window
    // where the bool is `true` but the future field is still `null` for a
    // concurrent [getAccessToken] / [signInSilent] to observe.
    _cacheFirstRevalidationInFlight = true;
    final revalidationFuture = _scheduleBackgroundRevalidation(restored);
    _cacheFirstRevalidationFuture = revalidationFuture;
    unawaited(revalidationFuture);
    return true;
  }

  /// Deserializes and surfaces the cached user WITHOUT any network access
  /// (no signature verification, no refresh, no userinfo). Returns the restored
  /// user, or `null` when there is no usable cached token.
  Future<OidcUser?> _restoreCachedUserLocally() async {
    final tokens = await store.getMany(
      OidcStoreNamespace.secureTokens,
      keys: {
        OidcConstants_Store.currentToken,
        OidcConstants_Store.currentUserAttributes,
        OidcConstants_Store.currentUserInfo,
      },
      managerId: id,
    );
    final rawToken = tokens[OidcConstants_Store.currentToken];
    if (rawToken == null) {
      return null;
    }
    try {
      final rawUserInfo = tokens[OidcConstants_Store.currentUserInfo];
      final rawAttributes = tokens[OidcConstants_Store.currentUserAttributes];
      final decodedAttributes = rawAttributes == null
          ? null
          : jsonDecode(rawAttributes) as Map<String, dynamic>;
      final decodedUserInfo = rawUserInfo == null
          ? null
          : jsonDecode(rawUserInfo) as Map<String, dynamic>;
      final token = OidcToken.fromJson(
        jsonDecode(rawToken) as Map<String, dynamic>,
      );
      // Pure-local restore: pass `keystore: null` so `OidcUser.fromIdToken`
      // parses the id_token unverified (`JsonWebToken.unverified`) instead of
      // fetching the JWKS. The token was already verified when it was saved;
      // the scheduled background revalidation re-verifies it against the network.
      final user = await OidcUser.fromIdToken(
        token: token,
        attributes: decodedAttributes,
        userInfo: decodedUserInfo,
      );
      userSubject.add(user);
      return user;
    } on Object catch (e, st) {
      logger.warning(
        'cache-first init: failed to restore the cached user locally; '
        'falling back to the network path.',
        e,
        st,
      );
      return null;
    }
  }

  /// Runs the cache-first background revalidation after `init()` has completed.
  ///
  /// Refreshes the discovery document if it is stale, then re-runs the full
  /// [loadCachedTokens] validation (re-verify, refresh-if-expired, userinfo,
  /// save) so the outcome is surfaced through [userChanges]/[events]. If the
  /// token is discarded as invalid (and offline auth is not keeping it), the
  /// stale restored user is forgotten.
  Future<void> _scheduleBackgroundRevalidation(OidcUser restoredUser) async {
    try {
      // Wait until init() has fully returned (didInit == true) before
      // touching init-guarded getters. Deliberately INSIDE this try: if
      // `init()` itself fails (e.g. `attachLifecycleListeners()`, called
      // AFTER this revalidation is armed — see `_tryCacheFirstInit` — throws
      // synchronously), `initFuture` rethrows that same error here, and it
      // must still hit the catch-all below so the `finally` always runs. An
      // earlier revision awaited `initFuture` OUTSIDE this try: a failed
      // `init()` then permanently skipped the `finally`, leaving
      // `_cacheFirstRevalidationFuture` pointing at a forever-errored future
      // that every later [_joinCacheFirstRevalidationIfInFlight] call
      // (`getAccessToken`/`signInSilent`) re-awaited and rethrew, AND leaving
      // `_cacheFirstRevalidationInFlight` stuck `true` forever, permanently
      // suppressing the on-expiry auto-refresh gated on it in
      // [handleTokenExpiring]/[handleTokenExpired].
      await initFuture;
      await _refreshDiscoveryInBackgroundIfStale();
      await loadCachedTokens(forceRebuild: true);
      // Reconcile the optimistically-surfaced restore with the authoritative
      // [loadCachedTokens] outcome so cache-first converges on exactly what
      // blockingValidate would have surfaced.
      //
      // [loadCachedTokens] REPLACES the surfaced user (a freshly-rebuilt object,
      // `ignoreCurrentUser: true`) on every path where it accepts a token —
      // refresh success, an explicit `isLoadedTokenAcceptable == true`, or a
      // clean validation. So if `currentUser` is STILL the exact restored object
      // afterwards, the pass rejected/discarded that token (policy or
      // validation) and surfaced no replacement — blockingValidate would show no
      // user here.
      //
      // #201/#205: retract it IN-MEMORY regardless of whether the on-disk copy
      // was removed. The on-disk retention is a SEPARATE decision owned by
      // `shouldRemoveInvalidToken` / `supportOfflineAuth`; a policy that KEEPS a
      // rejected token on disk (reject-but-keep) must not leave that rejected
      // user logged in — matching blockingValidate, which keeps the disk tokens
      // yet surfaces no user under identical settings.
      if (!_isDisposed && identical(currentUser, restoredUser)) {
        emitEvent(OidcPreLogoutEvent.now(currentUser: restoredUser));
        // Surface null WITHOUT clearing the store: `forgetUser()` would delete
        // the secureTokens namespace and defeat a reject-but-keep policy. The
        // null userChange also unloads the token-events timers (via the
        // userSubject listener), retiring the stale expired token's timers.
        userSubject.add(null);
      }
    } on Object catch (e, st) {
      logger.warning(
        'cache-first init: background revalidation failed.',
        e,
        st,
      );
    } finally {
      // Re-arm normal on-expiry auto-refresh now that the background pass has
      // settled. On success the winning token already re-armed the timers; on
      // rejection the retraction above unloaded them. Either way subsequent real
      // expiries must go through [handleTokenExpiring] / [handleTokenExpired]
      // again.
      _cacheFirstRevalidationInFlight = false;
      // Clear alongside the bool above: a caller that captured this future via
      // [_joinCacheFirstRevalidationIfInFlight] already holds its own
      // reference (it read the field into a local before this `finally` runs),
      // so nulling the field here only stops a LATER caller from joining a
      // revalidation that has already settled — it does not affect anyone
      // already awaiting it.
      _cacheFirstRevalidationFuture = null;
    }
  }

  /// Disposes the resources used by this class.
  Future<void> dispose() async {
    // Flip the disposed flag BEFORE tearing anything down so an in-flight
    // auto-refresh whose response lands mid-dispose observes it and no-ops
    // (see [isDisposed] / [_performAutoRefresh]).
    _isDisposed = true;
    // The shared in-flight auto-refresh already swallows its own outcome once
    // disposed, but latch onto it here too so its settling can never surface an
    // unhandled error into the zone after teardown. Mirrors how the other
    // in-flight subscriptions below are cancelled rather than left dangling.
    final inFlightRefresh = _autoRefreshInFlight;
    if (inFlightRefresh != null) {
      unawaited(
        inFlightRefresh.then(
          (_) {},
          onError: (Object e, StackTrace st) {
            logger.finest(
              'In-flight auto-refresh settled after dispose; swallowed.',
              e,
              st,
            );
          },
        ),
      );
    }
    await sessionSub?.cancel();
    await tokenEvents.dispose();
    await userSubject.close();
    await eventsController.close();
    await Future.wait(toDispose.map((e) => e.cancel()));
  }

  @protected
  Future<void> handleFrontChannelLogoutRequest(
    OidcFrontChannelLogoutIncomingRequest request,
  ) async {
    await store.remove(
      OidcStoreNamespace.request,
      key: OidcConstants_Store.frontChannelLogout,
    );
    final currentUser = this.currentUser;
    if (currentUser == null) {
      return;
    }

    // Validate `iss`/`sid` ONLY when the OP actually sent them. Per OpenID
    // Connect Front-Channel Logout 1.0 §3, both are OPTIONAL (sent only when
    // `frontchannel_logout_session_required` is true); a spec-compliant OP MAY
    // omit them. The previous `request.iss != issuer` compare treated a missing
    // (null) param as a mismatch and silently refused to log the user out
    // against every such OP. Now: a PRESENT-but-mismatched value is rejected
    // (defense), an ABSENT value is accepted.
    final issMismatch =
        request.iss != null &&
        request.iss != currentUser.parsedIdToken.claims.issuer;
    final sidMismatch =
        request.sid != null &&
        request.sid != currentUser.parsedIdToken.claims.sid;
    if (issMismatch || sidMismatch) {
      //invalid request, do nothing.
      logger.severe(
        'Received a front channel logout request, but the issuer '
        'or the session ids were different.',
      );
      return;
    }
    //forget the user.
    await forgetUser();
  }

  /// The OpenID Connect Core 1.0 §3.1.2.6 authorization-error codes that mean
  /// "the OP cannot satisfy this without showing the user something", i.e.
  /// exactly the `prompt=none` outcomes that require an interactive login.
  static const _interactionRequiredErrorCodes = {
    'login_required',
    'interaction_required',
    'consent_required',
    'account_selection_required',
  };

  /// Renews the session WITHOUT any user interaction.
  ///
  /// Two mechanisms, in order:
  ///
  /// 1. the refresh-token grant, when the current session has a refresh token.
  ///    This shares the same in-flight latch as [getAccessToken] and the
  ///    automatic on-expiry refresh, so it never races a second exchange; it
  ///    also joins an in-flight [OidcInitMode.cacheFirst] background
  ///    revalidation the same way [getAccessToken] does, reusing its outcome
  ///    instead of presenting the refresh token a second time.
  /// 2. otherwise `prompt=none` against the authorization endpoint, which
  ///    renews off the OP's own session cookie. This is the classic web-SPA
  ///    renewal path for a public client whose OP issues no refresh token.
  ///
  /// ## Platform matrix — read before relying on step 2
  ///
  /// The `prompt=none` variant runs in a HIDDEN IFRAME and is therefore
  /// **web-only**: on native platforms the navigation mode is ignored and the
  /// request would surface a browser/Custom Tab, which is not silent. On native,
  /// treat this method as "refresh-token renewal" and expect
  /// [OidcInteractionRequiredException] when there is no refresh token.
  ///
  /// Even on web the iframe variant is not universally reliable: it depends on
  /// the OP session cookie being readable in a third-party context, which
  /// Safari's ITP blocks outright and Chrome restricts. Prefer a refresh token
  /// when your OP can issue one.
  ///
  /// ## Return value and errors
  ///
  /// Returns the renewed [OidcUser], or `null` when the platform completes the
  /// flow out-of-band (a full-page redirect hands the result to
  /// `init()` instead) or when the manager was disposed mid-flight.
  ///
  /// Throws [OidcInteractionRequiredException] when the OP requires interaction
  /// — a terminal refresh failure (`invalid_grant`), or a `prompt=none` response
  /// of `login_required` / `interaction_required` / `consent_required` /
  /// `account_selection_required`. Throws a `kind`-stamped [OidcException] for a
  /// transient refresh failure that offline mode did NOT absorb — same caveat
  /// as [getAccessToken]: with [OidcUserManagerSettings.supportOfflineAuth]
  /// enabled and an offline-eligible error, this returns the retained
  /// [currentUser] instead of throwing.
  ///
  /// [timeout] overrides `hiddenIframeTimeout` for this call only.
  /// [scopeOverride] and [extraParameters] are forwarded to
  /// [loginAuthorizationCodeFlow] on the `prompt=none` path (they do not apply
  /// to the refresh-token path, which always uses the configured scope).
  Future<OidcUser?> signInSilent({
    Duration? timeout,
    List<String>? scopeOverride,
    Map<String, dynamic>? extraParameters,
  }) async {
    ensureInit();
    // Join (rather than race) an in-flight cache-first background
    // revalidation — see [_cacheFirstRevalidationFuture]. Re-read
    // [currentUser] AFTER the join (not a pre-join local) so the
    // refresh-token check below reflects whatever the revalidation concluded.
    final joinedRevalidation = await _joinCacheFirstRevalidationIfInFlight();
    final token = currentUser?.token;
    if (token != null && token.refreshToken != null) {
      // #421/#422/#423: when we just joined an in-flight revalidation AND its
      // outcome left this token no longer close to expiring, mechanism #1's
      // goal ("renew via the refresh-token grant") is ALREADY satisfied by
      // that revalidation — reuse it instead of presenting the refresh token
      // a second time (the very race this join exists to prevent).
      //
      // When the token is STILL stale — no revalidation ran (joinedRevalidation
      // is false: the normal, non-racing case, entirely unchanged below), or
      // one ran but failed to refresh it (a transient failure that offline
      // mode absorbed, retaining the old token) — fall through to the
      // existing unconditional renewal attempt, so a real failure is still
      // thrown here with the correct [OidcTokenRefreshFailureKind], exactly as
      // this method has always promised. (A terminal failure during the
      // revalidation instead forgets the user entirely, so `token` above is
      // `null` and this whole branch is skipped in favor of the prompt=none
      // fallback below — unchanged.)
      final tokenIsFreshEnough =
          token.expiresIn == null || !token.isAccessTokenAboutToExpire();
      if (joinedRevalidation && tokenIsFreshEnough) {
        return currentUser;
      }
      final outcome = await _autoRefresh(
        token,
        source: OidcTokenRefreshSource.manual,
      );
      return _userFromRefreshOutcome(outcome);
    }

    final baseOptions = getPlatformOptions();
    try {
      return await loginAuthorizationCodeFlow(
        promptOverride: const ['none'],
        scopeOverride: scopeOverride,
        extraParameters: extraParameters,
        options: OidcPlatformSpecificOptions(
          // Every non-web section is carried over untouched: forcing the hidden
          // iframe must not silently reset the caller's Custom Tabs / native
          // options.
          android: baseOptions.android,
          ios: baseOptions.ios,
          macos: baseOptions.macos,
          linux: baseOptions.linux,
          windows: baseOptions.windows,
          web: OidcPlatformSpecificOptions_Web(
            navigationMode:
                OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
            popupWidth: baseOptions.web.popupWidth,
            popupHeight: baseOptions.web.popupHeight,
            broadcastChannel: baseOptions.web.broadcastChannel,
            hiddenIframeTimeout: timeout ?? baseOptions.web.hiddenIframeTimeout,
          ),
        ),
      );
    } on OidcException catch (e, st) {
      final errorCode = e.errorResponse?.error;
      if (errorCode != null &&
          _interactionRequiredErrorCodes.contains(errorCode)) {
        throw OidcInteractionRequiredException.from(
          e,
          message:
              'The authorization server answered a prompt=none request with '
              '`$errorCode`; interactive re-authentication is required.',
          stackTrace: st,
        );
      }
      rethrow;
    }
  }

  /// Attempts a `prompt=none` re-authorization, forgetting the user when the OP
  /// answers with an error response.
  ///
  /// Prefer the public [signInSilent], which additionally tries the
  /// refresh-token grant first, lets the caller override the iframe timeout, and
  /// reports an interaction requirement as a typed
  /// [OidcInteractionRequiredException] instead of a bare `null`. This method is
  /// retained because the session-monitor reaction wants the
  /// forget-on-error behaviour rather than a throw.
  @Deprecated('use signInSilent')
  @protected
  Future<OidcUser?> reAuthorizeUser() async {
    try {
      final user = await loginAuthorizationCodeFlow(
        promptOverride: ['none'],
        options: const OidcPlatformSpecificOptions(
          web: OidcPlatformSpecificOptions_Web(
            navigationMode:
                OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
          ),
        ),
      );
      return user;
    } on OidcException catch (e) {
      if (e.errorResponse != null) {
        if (!settings.supportOfflineAuth) {
          await forgetUser();
        }
        return null;
      }
      rethrow;
    }
  }
}
