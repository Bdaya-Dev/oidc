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
  ),
);
