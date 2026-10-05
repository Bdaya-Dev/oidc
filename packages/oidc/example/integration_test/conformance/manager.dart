import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

/// iOS's conformance flow timeout. Why it is longer than the other
/// platforms' 30s is written up at its use in [conformanceManager].
const iosConformanceFlowTimeoutSeconds = 90;

/// The slowest iOS-simulator browser start seen so far: seconds from the
/// login starting to the authorization request reaching the suite
/// (oidcc-client-test-idtoken-sig-none, CI run 37380923417).
/// [iosConformanceFlowTimeoutSeconds] has to stay clear of it.
const observedIosBrowserStartSeconds = 49.5;

// Future<Map<String, dynamic>> prepareConformanceTest(String token) async {}
OidcUserManager conformanceManager(
  String issuer, {
  required String clientId,
  required String clientSecret,
  required Uri redirectUri,
  Uri? postLogoutRedirectUri,
  Uri? frontChannelLogoutUri,
  // oidcc-client-test-discovery-jwks-uri-keys (see
  // moduleFinishesBeforeUserinfo in conformance/api.dart) finishes the moment
  // the client has fetched BOTH the discovery document and jwks_uri -- before
  // a normal login's own userinfo call. Defaulting to true keeps every other
  // module's existing behaviour unchanged; only that one module's manager is
  // built with this false.
  bool sendUserInfoRequest = true,
  // OidcSessionManagementSettings.enabled defaults to false, and gates EVERY
  // OIDC Session Management 1.0 behaviour the manager has: capturing
  // session_state into the logout state, listenToUserSessionIfSupported's
  // automatic post-login check_session_iframe monitor, AND
  // startEndSessionConfirmation's post-logout probe (user_manager_base.dart).
  // Leaving it false is why oidcc-client-test-session-management (see
  // requiresSessionManagementMonitoring in conformance/api.dart) saw none of
  // the check_session_iframe traffic it waits for. True only for that
  // module's manager; every other module is unaffected.
  bool sessionManagementEnabled = false,
}) => OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse(issuer),
  ),
  clientCredentials: OidcClientAuthentication.clientSecretBasic(
    clientId: clientId,
    clientSecret: clientSecret,
  ),
  store: OidcDefaultStore(),
  settings: OidcUserManagerSettings(
    redirectUri: redirectUri,
    postLogoutRedirectUri: postLogoutRedirectUri,
    frontChannelLogoutUri: frontChannelLogoutUri,
    options: const OidcPlatformSpecificOptions(
      // On headless CI emulators/simulators the system auth browser opens but no
      // user can interact, so the redirect never arrives and
      // loginAuthorizationCodeFlow hangs. A flowTimeoutSeconds lets each module
      // fail-fast (caught by the try/catch in shared_e2e) so the rest of the
      // conformance suite still runs. Real conformance is exercised on
      // desktop (loopback) + macOS (real-OS browser completes).
      //
      // Every platform the suite runs on needs one. Leaving it off is not a
      // test that fails: it is a job that hangs until the runner kills it,
      // reporting no assertion and no stack.
      //
      // iOS NOTE: the iOS-18 simulator (Xcode 16) auto-completed the redirect in
      // ~4.5 min, but the iOS-26 simulator (Xcode 26) hangs — hence iOS now also
      // needs the timeout. `prefersEphemeralWebBrowserSession` avoids popups.
      macos: OidcNativeOptionsApple(
        prefersEphemeralWebBrowserSession: true,
        flowTimeoutSeconds: 30,
      ),
      // iOS gets longer than the others because on the CI simulator the
      // browser itself can take that long to START (#469). Each
      // ASWebAuthenticationSession is hosted by the long-lived
      // SafariViewService, and that process sometimes takes tens of seconds
      // to get a WebKit WebContent process to load the authorize URL in.
      // Simulator unified log, run 37384969496,
      // oidcc-client-test-missing-iat (hybrid):
      //   23:09:53.86  session presented
      //   23:10:15.47  runningboard: launch request for WebKit.WebContent
      //   23:10:21.10  launch response
      //   23:10:23.41  decidePolicyForNavigationAction .../authorize   (+29.6s)
      //   23:10:24.31  redirect to com.bdayadev.oidc.example:/oauth2redirect
      // At 30s that is a coin flip against this timeout. Lose it and the
      // session is cancelled before the authorization request leaves the
      // simulator ("NO authorization request received", missing-iat in run
      // 37380923417), or after Safari already started it, so it reaches the
      // suite ~49.5s in, long after the client gave up (idtoken-sig-none, same
      // run). Either way the module sits at status=WAITING and the plan fails,
      // while the library under test did nothing wrong. Positive and negative
      // modules are equally exposed; the reports named only negative ones
      // because they were the majority of the plan.
      //
      // 90s is just under twice the worst start observed (~49.5s). It costs
      // nothing when the browser is healthy: the flow ends at the redirect,
      // and no iOS conformance module legitimately goes without one.
      ios: OidcNativeOptionsApple(
        prefersEphemeralWebBrowserSession: true,
        flowTimeoutSeconds: iosConformanceFlowTimeoutSeconds,
      ),
      android: OidcNativeOptionsAndroid(flowTimeoutSeconds: 30),
      // Desktop was assumed to complete on its own because the loopback
      // listener needs no user. That holds only while every module's redirect
      // actually arrives. It does not for the Config RP plan: the run stopped
      // dead at oidcc-client-test-discovery-issuer-mismatch and GitHub Actions
      // killed the job ten minutes later. Same listener on both, so both get
      // the same bound.
      linux: OidcPlatformSpecificOptions_Native(flowTimeoutSeconds: 30),
      windows: OidcPlatformSpecificOptions_Native(flowTimeoutSeconds: 30),
      // Web hung the same way and had no knob at all until now:
      // hiddenIframeTimeout bounds the silent-renew iframe, not the popup the
      // interactive flow actually uses.
      //
      // 10s matches the other platforms deliberately. web is the only platform
      // whose runner imposes a PER-TEST cap -- patrol drives it through
      // Playwright -- so the temptation is to shrink this until it fits that
      // cap. It does not fit: Hybrid RP is 48 modules and the harness pays
      // ~5s of non-flow overhead per module (measured at 34-35s per module
      // against a 30s timeout, on the eight back-channel modules of commit
      // 05b0c84), so 48 x (10 + 5) + 20 = 740s against Playwright's 600s
      // default. That is how Hybrid RP and Implicit RP disappeared from the
      // web job while it printed "Failed: 0": a killed test emits no closing
      // patrol entry, so it lands in Total and in none of
      // successful/failed/skipped (run 90178636000, ~629s each).
      //
      // The fix is to raise the cap, not to shrink this. Fitting 740s under
      // 600s needs 7s, which is within an order of magnitude of a healthy web
      // module (~1.9s all in -- Basic RP ran 14 modules in 26s in the same
      // job) and would start cutting off real redirects: trading a loud
      // failure for a fake one. The web job passes --web-timeout 900000
      // instead. Both bounds are asserted in
      // test/conformance_flow_timeout_test.dart.
      web: OidcPlatformSpecificOptions_Web(flowTimeoutSeconds: 10),
    ),
    scope: const [
      OidcConstants_Scopes.openid,
      OidcConstants_Scopes.profile,
      OidcConstants_Scopes.email,
      OidcConstants_Scopes.address,
      OidcConstants_Scopes.phone,
    ],
    userInfoSettings: OidcUserInfoSettings(
      sendUserInfoRequest: sendUserInfoRequest,
    ),
    sessionManagementSettings: OidcSessionManagementSettings(
      enabled: sessionManagementEnabled,
    ),
  ),
);
