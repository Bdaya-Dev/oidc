import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';

// Future<Map<String, dynamic>> prepareConformanceTest(String token) async {}
OidcUserManager conformanceManager(
  String issuer, {
  required String clientId,
  required String clientSecret,
  required Uri redirectUri,
  Uri? postLogoutRedirectUri,
  Uri? frontChannelLogoutUri,
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
      ios: OidcNativeOptionsApple(
        prefersEphemeralWebBrowserSession: true,
        flowTimeoutSeconds: 30,
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
      // 10s, not the 30s every other platform uses, because web is the only
      // platform whose runner imposes a PER-TEST cap: patrol drives it through
      // Playwright, which kills a test at 600s
      // (patrol_plus/web_runner/playwright.config.ts:66). Hybrid RP is 48
      // modules, so 48 x 30s = 1440s could not fit -- a plan whose redirects
      // never arrive was killed mid-plan instead of failing, and a killed test
      // emits no closing patrol entry, so it landed in Total and in none of
      // successful/failed/skipped. That is exactly how Hybrid RP and Implicit
      // RP disappeared from the web job while it printed "Failed: 0"
      // (run 90178636000; each consumed ~629s and emitted nothing).
      //
      // At 10s the worst case is 48 x 10s + setup = 540s, which fits, so the
      // plan runs to completion and fails on its own `successfulLogins > 0`
      // assertion -- naming the plan and dumping the per-module suite status --
      // instead of vanishing. Still 5x the ~2s a healthy web module takes (the
      // Basic RP plan ran 14 modules in 26s of wall clock in the same job).
      // The arithmetic is asserted in test/conformance_flow_timeout_test.dart.
      web: OidcPlatformSpecificOptions_Web(flowTimeoutSeconds: 10),
    ),
    scope: const [
      OidcConstants_Scopes.openid,
      OidcConstants_Scopes.profile,
      OidcConstants_Scopes.email,
      OidcConstants_Scopes.address,
      OidcConstants_Scopes.phone,
    ],
  ),
);
