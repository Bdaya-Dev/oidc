// ignore_for_file: avoid_print
//
// Harness-agnostic OIDC e2e logic, shared by both runners:
//   * `integration_test` (testWidgets) — used by the linux/windows CI jobs
//   * Patrol (patrolTest)               — used by android/iOS/macOS/web
//
// The ONLY coupling to the test harness is a `pumpAndSettle` callback, so the
// exact same conformance flow runs everywhere.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_example/app_state.dart' as app_state;

import 'conformance/api.dart';
import 'conformance/manager.dart';
import 'helpers.dart';

/// A harness-agnostic "launch the example app (and settle)" hook. Each runner
/// provides its own: integration_test runs the app's `main()`; Patrol pumps a
/// widget via the PatrolTester instead, to avoid double-initializing the
/// Flutter engine (Patrol already bootstraps the app via `$dartRunMain`).
typedef LaunchApp = Future<void> Function();

const String oidcConformanceToken = String.fromEnvironment(
  'OIDC_CONFORMANCE_TOKEN',
);

final Logger _testLogger = Logger('oidc.conformance');

/// The Config RP module whose correct outcome is `init()` throwing: the RP
/// must stop after fetching a discovery document with the wrong `issuer`.
const discoveryIssuerMismatchModule =
    'oidcc-client-test-discovery-issuer-mismatch';

/// Whether [planName] is one of the four logout profiles.
///
/// Matched on substring rather than an enumerated list: the logout plans also
/// ship `-rp-hybrid` and `-rp-implicit` variants that are not wired yet, and a
/// list would silently drive those as login-only when they are added -- the
/// same failure this predicate exists to remove.
bool isLogoutConformancePlan(String planName) =>
    planName.contains('-logout-') || planName.contains('-session-management-');

// There is deliberately no fragment gate any more. A fragment never reaches a
// server, so a bare loopback listener could not observe one and linux/windows
// skipped the hybrid and implicit plans. oidc_loopback_listener 1.1.0 serves a
// relay page that promotes `location.hash` into the query string -- the trick
// CLI OAuth tools use -- and oidc_desktop 1.1.0 turns it on exactly when the
// flow's response mode calls for it (responseArrivesInFragment). Every
// platform can now receive a fragment response, and a universally-true gate is
// dead code.

/// Whether [planName] is the third-party-initiated login profile.
///
/// In that flow the OP starts the login by calling the RP's
/// `initiate_login_uri` (OIDC Core §4). The RP must therefore HOST an endpoint
/// the OP can reach and act on. This example is a Flutter app -- it has no
/// server, and `redirect.html` on web only receives a redirect, it cannot be
/// invoked to begin one. So the module waits for the app to react to a call it
/// never receives.
///
/// Observed on linux at de71aa7: the plan created 1 module and the job log
/// simply ends there, with `dynamic` and `config` never reaching the runner --
/// this module consumed the remaining job budget. Everything before it passed
/// or skipped correctly.
bool isThirdPartyInitPlan(String planName) =>
    planName.contains('3rd-party-init');

/// Whether [planName] requires the RP to HOST a request object the suite
/// fetches, rather than to send one.
///
/// The Dynamic plan pins `request_type=request_uri` at plan level for every one
/// of its modules (`OIDCCClientDynamicTestPlan.java:41`), and the suite resolves
/// it by fetching:
///
///   callAndStopOnFailure(FetchRequestUriAndExtractRequestObject.class,
///                        "OIDCC-6.2")   -- AbstractOIDCCClientTest.java:1019
///
/// `ClientRequestType` has exactly three values -- `plain_http_request`,
/// `request_object`, `request_uri` -- and none is PAR, so pushing a signed
/// request object through the PAR endpoint does not satisfy it either. The RP
/// must serve the object at an https URL the suite can reach, and a CI runner
/// behind NAT cannot. That is the same inbound-reachability wall as
/// [isBackChannelLogoutPlan], not a missing library feature: request objects
/// BY VALUE are implemented (`oidc_core/lib/src/jar/`).
///
/// This gate is about the harness, not the library. `package:oidc` supports
/// dynamic client registration -- the other half of this profile -- and it is
/// exercised by the oidc_core suite.
bool planNeedsHostedRequestUri(String planName) =>
    planName == 'oidcc-client-dynamic-certification-test-plan';

/// Whether [planName] is the Back-Channel Logout profile.
///
/// Back-Channel Logout is the one logout profile with no browser in the loop:
/// the OP POSTs a logout token DIRECTLY to the RP's `backchannel_logout_uri`
/// (OpenID Connect Back-Channel Logout 1.0 section 2.5). That makes it the only
/// profile here whose transport runs inbound, from the public internet to the
/// RP.
///
/// A CI runner's RP listens on loopback behind NAT, so certification.openid.net
/// cannot reach it, and no `backchannel_logout_uri` value fixes that -- the URI
/// is missing from the plan request because there is no reachable value to put
/// there, not the other way round. On linux all eight of its modules therefore
/// ended in "The end session flow timed out after 30 seconds", while the plan
/// still reported success because the aggregate counted logins only.
///
/// Running it would need a publicly reachable tunnel to the runner. Until then
/// this is stated rather than scored.
bool isBackChannelLogoutPlan(String planName) =>
    planName.contains('back-channel-logout');

/// Whether the suite can compute a `session_state` for [redirectUri].
///
/// OpenID Connect Session Management derives `session_state` from the Client's
/// ORIGIN, and the suite builds that origin as `scheme://host` taken from
/// `redirect_uri` (`GenerateSessionState.java:69`). Every logout plan inherits
/// that condition through
/// `AbstractOIDCCClientLogoutTest.validateAuthorizationEndpointRequestParameters`,
/// so it runs on the AUTHORIZATION request, before any redirect is issued.
///
/// A private-use URI scheme has no authority, so `URI.getHost()` returns null
/// and the suite throws an NPE it does not catch (its handler covers only
/// `URISyntaxException`). The module then never redirects, the client waits out
/// `flowTimeoutSeconds`, and the plan reports zero logins.
///
/// The redirect URI is NOT the thing to change. RFC 8252 section 7.1: "as there
/// is no naming authority for private-use URI scheme redirects, only a single
/// slash ('/') appears after the scheme component". Giving it an authority to
/// please the suite would break the BCP this package exists to conform to, on
/// every native plan, to work around an upstream defect. It is also consistent
/// with README.md scoping Session Management as web-only: a native app has no
/// origin for `session_state` to be computed from in the first place.
bool canGenerateSessionState(Uri redirectUri) => redirectUri.host.isNotEmpty;

/// Whether [planName] is an OpenID Connect Session Management RP profile
/// (`oidcc-client-rp-session-management-rp-basic`, plus the not-yet-wired
/// `-rp-hybrid`/`-rp-implicit` variants, matched the same way
/// [isLogoutConformancePlan] matches its own substring family).
bool isSessionManagementConformancePlan(String planName) =>
    planName.contains('-session-management-');

/// Whether this platform can satisfy OpenID Connect Session Management's
/// RP-side session-status check: hosting `check_session_iframe` in a frame
/// the RP controls, posting `"$clientId $sessionState"` into it, and reading
/// back the OP's postMessage result.
///
/// This is `true` ONLY on web (`package:oidc`'s decision, made and verified
/// with the user, oidc#467): two independent reasons, either one sufficient
/// on its own, rule out every other platform:
///
/// * RFC 8252 section 8.12 requires native apps to perform the authorization
///   request in an external user-agent (the system browser), explicitly
///   forbidding an embedded WebView for login. So on android/ios/macos/
///   linux/windows, package:oidc's login flow never runs inside any
///   app-controlled browser surface at all -- there is no WebView around,
///   embedded or otherwise, for the app to host a frame in.
/// * Even granting an embedded WebView purely for session monitoring (a
///   SEPARATE browser surface from the one that performed login), OpenID
///   Connect Session Management 1.0 section 3.2 computes `check_session_iframe`'s
///   answer from the OP SESSION COOKIE held by whichever user-agent is
///   loading it. That cookie lives in the EXTERNAL user-agent the §8.12 login
///   happened in (the system browser), not in any separate surface the app
///   might create -- a second, app-controlled WebView would carry no OP
///   session cookie and could only ever answer "changed"/"error", which is
///   not a meaningful session check, it is a permanently-broken one.
///
/// `monitorSessionStatus` reflects exactly this split today:
/// `oidc_web_core`'s implementation does the real iframe + postMessage dance
/// (the web page IS the browser the login ran in, so the cookie is right
/// there); `oidc_desktop`/`oidc_android`/`oidc_darwin` each return
/// `Stream.empty()`, tested explicitly in their own `library_surface_test.dart`
/// files. See `packages/oidc/README.md`'s Session Management section for the
/// native-platform alternatives (`OidcTokenRefreshFailedEvent`,
/// `OidcUserInfoFailedEvent`, back-channel logout, OpenID Connect Native SSO).
bool get supportsSessionManagement => kIsWeb;

/// The OIDC Registration 1.0 section 2 `application_type` this platform's RP
/// truthfully is.
///
/// The suite defaults an omitted value to `web`, and a web client "using the
/// OAuth Implicit Grant Type MUST only register URLs using the https scheme as
/// redirect_uris; they MUST NOT use localhost as the hostname" -- which is how
/// the first live run of the hybrid and implicit plans on linux produced 36
/// suite-side rejections of the loopback redirect before any browser was
/// involved.
///
/// Every non-web platform here is a native client, and the same section
/// sanctions exactly their redirect shapes: "Native Clients MUST only register
/// redirect_uris using custom URI schemes or loopback URLs using the http
/// scheme; loopback URLs use localhost or the IP loopback literals". Declaring
/// `native` is not a workaround for the check; it is the metadata that was
/// always true and simply never sent.
String applicationTypeForPlatform(String platform) =>
    platform.toLowerCase() == 'web' ? 'web' : 'native';

/// Whether [planName] uses `response_mode=form_post`.
bool isFormPostConformancePlan(String planName) =>
    planName.contains('-formpost-');

/// Whether an authorization response can be delivered as a form POST to
/// [redirectUri] on [platform].
///
/// `response_mode=form_post` has the browser deliver the response as an HTTP
/// POST body to the redirect URI. Per transport:
///   * loopback (linux/windows) -- YES since oidc_loopback_listener 1.1.0,
///     which reads an application/x-www-form-urlencoded body and folds it into
///     the returned Uri's query parameters. Earlier versions answered 405 to
///     every non-GET, and an earlier version of this predicate returned false
///     everywhere because of it.
///   * custom scheme (iOS/macOS/Android) -- NO: not an HTTP endpoint at all,
///     so no browser can POST to it. Caught by the scheme check.
///   * web -- NO: redirect.html reads location.hash/search in JS, and a page
///     script has no access to the request body that delivered it. This is why
///     [platform] is a parameter: the web page and the desktop listener are
///     both http(s), so the URI alone cannot tell them apart.
///
/// The predicate stays a real capability statement rather than
/// `scheme == http`: that earlier shortcut ran the formpost plans into the
/// listener's 405, burned flowTimeoutSeconds per module, and reported an
/// Android-specific failure message on Linux.
bool canReceiveFormPost(Uri redirectUri, String platform) {
  if (platform.toLowerCase() == 'web') {
    return false;
  }
  return redirectUri.isScheme('http') || redirectUri.isScheme('https');
}

bool _planIdsLogged = false;

/// Logs every RP plan id the suite actually publishes, once per run.
///
/// Plan ids have been the single biggest source of wasted CI round trips here:
/// a wrong one is an HTTP 400 at creation, and the logout profiles could not be
/// wired at all because their ids were never found in any public document --
/// openid.net names the four logout PROFILES but not their plan ids, and the
/// only concrete name findable elsewhere turned out to be an OP-side plan.
///
/// Guessing was refused, and that was right; but "unverifiable" was wrong. The
/// suite will simply list them, and CI holds the token that makes it answer.
/// Read the ids out of the CI log rather than searching for them again.
Future<void> _logAvailableClientPlanIds(Dio dio) async {
  if (_planIdsLogged) {
    return;
  }
  _planIdsLogged = true;
  try {
    final resp = await dio.get<List<dynamic>>('api/plan/available');
    final names =
        (resp.data ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => e['planName'] as String?)
            .whereType<String>()
            .where((e) => e.contains('client'))
            .toList()
          ..sort();
    _testLogger.info('Available RP plan ids (${names.length}):');
    for (final name in names) {
      _testLogger.info('  PLAN_ID $name');
    }
  } on Object catch (e) {
    // Never fail a conformance run over a diagnostic.
    _testLogger.warning('Could not list available plans: $e');
  }
}

bool _loggingConfigured = false;

/// Configures hierarchical logging once, printing every record.
void ensureLoggingConfigured() {
  if (_loggingConfigured) {
    return;
  }
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer()
      ..write('[${record.time.toIso8601String()}]')
      ..write('[${record.level.name}]')
      ..write('[${record.loggerName}] ')
      ..write(record.message);
    if (record.error != null) {
      buffer
        ..write(' | error: ')
        ..write(record.error);
    }
    if (record.stackTrace != null) {
      buffer.write('\n${record.stackTrace}');
    }
    print(buffer);
  });
  _loggingConfigured = true;
}

/// Describes a token by shape, never by value.
///
/// Every record reaches stdout via the root listener above and is archived with
/// the conformance logs; both are public artifacts, so bearer material must not
/// appear in either. The shape is what the assertion cares about anyway.
String _describeToken(OidcToken token) {
  final present = [
    if (token.accessToken != null) 'access',
    if (token.idToken != null) 'id',
    if (token.refreshToken != null) 'refresh',
  ];
  return 'tokens=[${present.join(', ')}] type=${token.tokenType} '
      'expiresIn=${token.expiresIn?.inSeconds}s '
      'scope=${token.scope?.join(' ')}';
}

/// Appends a failure line to [moduleFailures] when [verdict] (from
/// [pollConformanceModuleVerdict]) is not one this harness accepts for
/// [moduleName], and always logs what the suite reported.
///
/// [authDescription] is purely descriptive context for the log/failure
/// message (what the CLIENT observed -- logged in, no user, or not driven at
/// all for the discovery-only module) and plays no part in the verdict: the
/// decision is the suite's own `result`, not what package:oidc returned.
///
/// A rejected verdict also carries [describeSuiteLogForFailure]'s digest of
/// the module's suite log, fetched from [dio] only on that path: the failure
/// line is the one piece of output every platform's job log shows (iOS shows
/// nothing else), and "WAITING, no user" alone cannot say whether the suite
/// ever received the authorization request.
Future<void> _recordModuleVerdict({
  required Dio dio,
  required String instanceId,
  required List<String> moduleFailures,
  required Logger logger,
  required String moduleName,
  required Map<String, dynamic> verdict,
  required String authDescription,
  int? clientLoginStartedAtMs,
}) async {
  final status = verdict['status'] as String?;
  final result = verdict['result'] as String?;
  // Set only when every poll inside pollConformanceModuleVerdict exhausted its
  // retries (or hit a non-transient error) -- see _pollSummaryTolerant in
  // api.dart. Surfaced here, not swallowed, so a transient-poll-induced
  // non-terminal status is distinguishable from a module that is genuinely
  // stuck.
  final pollError = verdict['pollError'] as String?;
  logger.info(
    'Suite verdict for $moduleName: status=$status result=$result '
    '(client: $authDescription)'
    '${pollError == null ? '' : ', last poll error: $pollError'}.',
  );
  final terminal = isTerminalConformanceStatus(status);
  if (terminal && isAcceptableConformanceResult(result)) {
    return;
  }
  final suiteLog = describeSuiteLogForFailure(
    await fetchTestLogs(dio: dio, instanceId: instanceId),
    clientLoginStartedAtMs: clientLoginStartedAtMs,
  );
  if (!terminal) {
    moduleFailures.add(
      '$moduleName: suite status never reached FINISHED/INTERRUPTED within '
      'the poll timeout (last status=$status, result=$result; client: '
      '$authDescription)'
      '${pollError == null ? '' : ' -- the last poll of it failed: $pollError'}'
      '. $suiteLog',
    );
  } else {
    moduleFailures.add(
      '$moduleName: suite result was $result (status=$status; client: '
      '$authDescription). Acceptable results are PASSED, WARNING, REVIEW, '
      'SKIPPED. $suiteLog',
    );
  }
}

/// When a still-pending login is reported as stalled, with a LOGIN-PENDING
/// line.
/// A healthy iOS login takes ~3-5s (median 3.3s, p90 4.7s in run
/// 37384969496), so the first report only fires on a login that has already
/// stalled. The lines are timestamps for the iOS job's screen recording, which
/// shows what was on screen.
///
/// A plain print, deliberately: an earlier version queried the native UI
/// through Patrol's XCUITest automator. While a browser sheet was up, those
/// queries took 8s+ or timed out, and XCTest recorded unmatched queries as
/// test failures. That failed plans that had passed (runs 37428137698,
/// 37430662455). A diagnostic must not change the outcome it observes.
const loginStallProbeOffsets = [
  Duration(seconds: 20),
  Duration(seconds: 50),
  Duration(seconds: 80),
];

/// A short label for a native browser-layer event, for a failure line.
String describeNativeBrowserEvent(OidcNativeBrowserEvent event) =>
    switch (event) {
      OidcBrowserOpeningEvent() => 'opening',
      OidcBrowserOpenedEvent() => 'opened',
      OidcBrowserRedirectReceivedEvent() => 'redirectReceived',
      // On darwin/android this is also what flowTimeoutSeconds produces.
      OidcBrowserFlowCancelledEvent() => 'cancelled',
      final OidcBrowserFlowFailedEvent e =>
        'failed(${e.error.kind.name}: ${e.error.message})',
      OidcBrowserNativeWarningEvent() => 'warning',
    };

/// Smoke path used when no conformance token is supplied: just initialize the
/// example's default manager.
Future<void> runManagerSmokeTest(LaunchApp launchApp) async {
  _testLogger.info('Running smoke test path (no OIDC token supplied).');
  print('Starting test: Simple manager initializes correctly');
  await launchApp();
  print('App launched');

  if (!app_state.currentManagerRx.$.didInit) {
    print('Initializing manager...');
    await app_state.currentManagerRx.$.init();
    print('Manager initialization complete');
  }

  expect(app_state.currentManagerRx.$.didInit, true);
  print('Verified that manager is initialized');
}

/// Full OIDC conformance flow against certification.openid.net.
/// Runs one OpenID Connect RP certification plan end to end.
///
/// [planName] is a conformance-suite plan id. Each plan is driven as its own
/// test case rather than looped here, so a failure names the profile that broke
/// and one profile's outage cannot mask another's.
///
/// Plan ids, all four confirmed green against the live suite:
///   oidcc-client-basic-certification-test-plan    - 14 modules; the certified
///                                                   profile
///   oidcc-client-hybrid-certification-test-plan   - 48 modules; includes the
///                                                   invalid/missing c_hash
///                                                   negatives
///   oidcc-client-implicit-certification-test-plan - 27 modules
///   oidcc-client-config-certification-test-plan   -  6 modules; OP config
///                                                   from .well-known
///
/// The flow each module needs is read from that module's own `response_type`
/// variant rather than assumed, so hybrid and implicit need no special driving
/// here -- only their plan id.
///
/// The logout profiles ARE wired now, and they are two-step: log in, then
/// logout. See [isLogoutConformancePlan] -- driving only the login leaves every
/// module waiting for an end-session request that never arrives.
///
/// [clientRegistration], [requestType] and [clientAuthType] are the plan's
/// variant dimensions, and which ones a plan REQUIRES is not uniform. The
/// basic plan resolves `client_auth_type` to `client_secret_basic` on its own,
/// so omitting it works there. The config plan does not:
///
///   TestModule 'oidcc-client-test-discovery-openid-config' requires a value
///   for variant 'client_auth_type'
///
/// which is an HTTP 400 at plan creation, before any module runs. Pass
/// [clientAuthType] for any plan whose modules need it stated outright.
Future<void> runOidcConformanceTest(
  LaunchApp launchApp, {
  String planName = 'oidcc-client-basic-certification-test-plan',
  String? clientRegistration = 'static_client',
  String? requestType = 'plain_http_request',
  String? clientAuthType,
  Map<String, String> extraPlanVariant = const {},
}) async {
  _testLogger.info('Running OIDC conformance plan: $planName');
  await launchApp();
  _testLogger.info('Example app launched and settled.');

  const baseUrl = 'https://www.certification.openid.net/';
  _testLogger.fine('Conformance base URL: $baseUrl');

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'Authorization': 'Bearer $oidcConformanceToken',
        'Accept': 'application/json',
      },
    ),
  );
  if (kIsWeb) {
    // The suite sends no CORS headers, so a browser has to go through a
    // CORS-proxying Cloudflare Worker instead of calling it directly. That
    // worker's calling convention is a single query parameter:
    // `.../corsproxy/?apiurl=<the FULL target URL, own path and query
    // included, percent-encoded as one value>`.
    //
    // This used to be done by baking a half-finished `apiurl=<bare origin>`
    // into [BaseOptions.baseUrl] and relying on dio's `RequestOptions.uri`
    // getter -- a plain `baseUrl + path` STRING CONCATENATION, not URI
    // resolution (see package:dio's `lib/src/options.dart`) -- to extend
    // that value as each call's `path` was appended. That only produces a
    // correct `apiurl` for a `path` with no leading `/` and no query string
    // of its own: a leading `/` lands right after the baseUrl's already
    // percent-encoded trailing slash (`%2F`) and decodes to a literal
    // double slash, and an embedded `?`/`&` -- which every endpoint that
    // takes its own query parameters has, being built via
    // `Uri(path: ..., queryParameters: {...})` -- breaks OUT of the
    // `apiurl` value and starts new top-level query parameters on the
    // proxy request that the worker has no use for and drops.
    //
    // `POST api/plan` (`conformance/api.dart`'s `prepareTestPlanRequest`)
    // hit both: its path has a leading `/` AND its own `planName`/`variant`
    // query, so the worker actually proxied to
    // `https://www.certification.openid.net//api/plan?planName=...` with
    // `variant` silently dropped. The suite's router does not recognize
    // that double-slash path as the authenticated REST endpoint and falls
    // back to its default web handling: a 302 to `login.html`, which the
    // browser refuses to follow cross-origin (`net::ERR_FAILED`), surfacing
    // here as "Creating the plan test plan failed with status null".
    // `api/server`, `api/currentuser` and `api/plan/available` all pass a
    // bare relative path with no leading slash and no query of its own, so
    // the same string concatenation happens to land on the right value --
    // which is exactly why only plan *creation* was failing.
    //
    // Fixed by not pre-baking `apiurl` at all: let dio resolve this
    // request's OWN baseUrl+path+queryParameters first -- against the
    // suite's bare origin, which carries no dangling query, that
    // composition is correct for any path, leading slash or embedded query
    // or not -- then wrap the single resulting absolute URL as the proxy's
    // `apiurl` value via [Uri.replace], which percent-encodes it correctly
    // regardless of what it contains.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final target = options.uri;
          options
            ..baseUrl = ''
            ..queryParameters = {}
            ..path =
                Uri.parse('https://cors-proxy.bdaya-dev.workers.dev/corsproxy/')
                    .replace(queryParameters: {'apiurl': target.toString()})
                    .toString();
          handler.next(options);
        },
      ),
    );
  }
  _testLogger
    ..info('Dio client configured for conformance API.')
    ..info('Fetching server diagnostics (api/server)...');
  final serverInfo = await dio.get<Map<String, dynamic>>('api/server');
  _testLogger.info('Server info OK (status ${serverInfo.statusCode}).');
  expect(serverInfo.statusCode, 200);

  _testLogger.info('Fetching current user (api/currentuser)...');
  final currentUser = await dio.get<Map<String, dynamic>>('api/currentuser');
  _testLogger.info('Current user OK (status ${currentUser.statusCode}).');
  expect(currentUser.statusCode, 200);

  await _logAvailableClientPlanIds(dio);

  final platform = getPlatformName();
  _testLogger.info('Detected platform: $platform');

  if (isThirdPartyInitPlan(planName)) {
    markTestSkipped(
      '$planName needs the RP to host an initiate_login_uri the OP can call '
      '(OIDC Core §4). This example app hosts no such endpoint on any '
      'platform, so the module waits for a call that never arrives.',
    );
    return;
  }

  if (planNeedsHostedRequestUri(planName)) {
    markTestSkipped(
      '$planName pins request_type=request_uri for every module and the suite '
      'fetches that URI (FetchRequestUriAndExtractRequestObject, '
      'AbstractOIDCCClientTest.java:1019). The RP would have to serve a signed '
      'request object at an https URL reachable from '
      'certification.openid.net, which a CI runner behind NAT cannot. PAR does '
      'not substitute: ClientRequestType has no PAR value. Dynamic client '
      'registration itself IS implemented and covered by the oidc_core suite.',
    );
    return;
  }

  if (isBackChannelLogoutPlan(planName)) {
    markTestSkipped(
      '$planName needs the OP to POST a logout token directly to the RP, and a '
      'CI runner listening on loopback is not reachable from '
      'certification.openid.net. Every module timed out waiting for that POST '
      'while the plan reported success, because the aggregate counted logins '
      'only. Unskip once the runner is publicly reachable.',
    );
    return;
  }

  if (isSessionManagementConformancePlan(planName) &&
      !supportsSessionManagement) {
    // Confirmed against the suite's own public log (oidc#467, CI run
    // 37273454165, linux instance LGM4mkXj5oBdTTq / windows instance
    // 4l3cX3OUWBhPQYg): the RP's observed request sequence was discovery ->
    // authorize -> token -> jwks -> userinfo -> end_session_endpoint, with
    // ZERO requests to check_session_iframe before or after logout, so the
    // module sits at status=WAITING forever -- no poll timeout fixes a
    // module waiting on an interaction that structurally never happens on
    // this platform. See [supportsSessionManagement] for why.
    markTestSkipped(
      '$planName needs the RP to host check_session_iframe in a frame it '
      'controls and read back its postMessage result. RFC 8252 section 8.12 '
      'requires $platform to run login in an external user-agent (no '
      'embedded WebView), and OpenID Connect Session Management 1.0 section '
      "3.2 ties check_session_iframe's answer to the OP session cookie held "
      'by THAT external user-agent -- a cookie this app has no access to and '
      'no frame to host against. package:oidc implements session-status '
      "monitoring for web only; see packages/oidc/README.md's Session "
      'Management section for native alternatives '
      '(OidcTokenRefreshFailedEvent, OidcUserInfoFailedEvent, back-channel '
      'logout, OpenID Connect Native SSO).',
    );
    return;
  }

  if (isLogoutConformancePlan(planName) &&
      !canGenerateSessionState(getPlatformRedirectUri())) {
    // Not a client defect and not a skipped failure: the suite aborts before it
    // ever issues a redirect, so there is no client behaviour to observe.
    markTestSkipped(
      '$planName runs GenerateSessionState on the AUTHORIZATION request, which '
      'builds an origin as scheme://host from redirect_uri '
      '(GenerateSessionState.java:69). $platform redirects to '
      '${getPlatformRedirectUri()}, a private-use scheme with no authority, so '
      'getHost() is null and the suite throws before issuing any redirect. '
      'RFC 8252 section 7.1 requires that shape, so the redirect URI is correct '
      'and the suite cannot run these modules against it.',
    );
    return;
  }

  if (isFormPostConformancePlan(planName) &&
      !canReceiveFormPost(getPlatformRedirectUri(), platform)) {
    // Not a skipped failure: nothing on this platform can observe a POST body,
    // so there is no outcome to test. Two distinct reasons share this gate:
    // a custom scheme is not an HTTP endpoint (no browser can POST to it), and
    // a web page script cannot read the request body that delivered it.
    markTestSkipped(
      '$planName delivers the response as a form POST, which $platform cannot '
      'receive: ${platform.toLowerCase() == 'web' ? 'redirect.html reads '
                'location.hash/search, and a page script has no access to a '
                'POST body' : '${getPlatformRedirectUri().scheme}: is not an '
                'HTTP endpoint, so no browser can POST to it'}.',
    );
    return;
  }

  const clientId = 'my_client';
  const clientSecret = 'my_client_secret';
  final redirectUri = getPlatformRedirectUri();
  _testLogger.fine('Client ID: $clientId, redirectUri: $redirectUri');

  final (path, body) = prepareTestPlanRequest(
    clientId: clientId,
    clientSecret: clientSecret,
    planName: planName,
    description: 'package:oidc $planName on $platform',
    alias: planNeedsAlias(planName)
        ? conformanceAlias(planName: planName, platform: platform)
        : null,
    redirectUri: redirectUri.toString(),
    requestType: requestType,
    clientRegistration: clientRegistration,
    applicationType: applicationTypeForPlatform(platform),
    extraVariant: {
      if (clientAuthType != null) 'client_auth_type': clientAuthType,
      ...extraPlanVariant,
    },
    postLogoutRedirectUri: redirectUri.toString(),
    frontChannelLogoutUri: getPlatformFrontChannelLogoutUri().toString(),
  );
  _testLogger.info('Submitting test plan request to $path...');

  // A 4xx here is a plan-configuration error, not a protocol failure: the
  // variant dimensions a plan accepts differ per plan, and one the plan does
  // not declare is rejected outright. Dio's own message reports the status
  // code and nothing else, so a wrong variant surfaces as a bare "status code
  // of 400" that names neither the plan nor the offending key. The suite does
  // say which dimension it rejected, in the response body — surface it, or the
  // next person debugging this has to re-run CI to learn what the server
  // already told us.
  final Response<Map<String, dynamic>> testPlanResponse;
  try {
    testPlanResponse = await dio.post<Map<String, dynamic>>(path, data: body);
  } on DioException catch (e) {
    final response = e.response;
    throw StateError(
      'Creating the "$planName" test plan failed with status '
      '${response?.statusCode}.\n'
      'Conformance suite response: ${response?.data}\n'
      'Request path: $path\n'
      'If this names a variant dimension, the plan disagrees with what this '
      'test sent: pass or drop it via `clientAuthType`, `clientRegistration`, '
      '`requestType`, or `extraPlanVariant`.\n'
      'Note the local guard in api.dart only checks that a dimension is '
      'PRESENT or ABSENT, never that its VALUE is one the plan accepts, so a '
      '4xx can still come from a wrong clientAuthType even when the guard is '
      'satisfied.',
    );
  }
  _testLogger.info('Test plan response status ${testPlanResponse.statusCode}.');
  expect(testPlanResponse.data, isMap);

  final testPlanData = testPlanResponse.data!;
  final testPlanId = testPlanData['id'] as String;
  final testPlanModules = testPlanData['modules'] as List<dynamic>? ?? [];
  _testLogger.info(
    'Test plan created: id=$testPlanId, modules=${testPlanModules.length}.',
  );

  final archive = Archive();

  // The probe's positive controls (can it see the browser sheet, and a known
  // system alert?) run in their own patrolTest, after every plan
  // (patrol_test/app_test.dart). Run inside a plan, they broke it (run
  // 37428137698).

  // The plan mixes positive modules with negative ones such as
  // oidcc-client-test-invalid-iss, where the OP returns a deliberately broken
  // response and a null result is the correct outcome. No single module can be
  // required to succeed, so the aggregate is asserted after the loop instead.
  var successfulLogins = 0;
  // Counted separately because counting logins alone made the logout plans
  // report success while every one of their logout calls threw: on linux all
  // eight back-channel modules ended with "The end session flow timed out after
  // 30 seconds", and the plan still passed. An assertion that cannot observe
  // the thing the plan exists to test is not a test of it.
  var successfulLogouts = 0;
  // Per-module suite verdicts this harness rejects, collected across the
  // whole plan rather than failing at the first one. Neither aggregate above
  // can see this: a negative module that WRONGLY logs in still increments
  // successfulLogins, so the plan stayed green through #447's CI even though
  // oidcc-client-test-missing-athash should have ended with no user (#467).
  // Asking the suite itself for each module's result (not just login/no-login
  // on the client side) is what catches that.
  final moduleFailures = <String>[];
  // Null when the plan has no discovery-issuer-mismatch module.
  bool? issuerMismatchRejected;

  moduleLoop:
  for (final testPlanModule
      in testPlanModules.whereType<Map<String, dynamic>>()) {
    final moduleName = testPlanModule['testModule'] as String;
    final variant =
        testPlanModule['variant'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    // Set when an earlier instance of this module was discarded because its
    // browser never reached the suite (shouldRerunModuleOnFreshInstance,
    // api.dart). Carried into this module's verdict line so a rerun is never
    // invisible.
    String? rerunNote;

    // Each pass runs the module on its own fresh suite instance. Every path
    // ends the pass with `break` (or `continue moduleLoop`) except the one
    // rerun shouldRerunModuleOnFreshInstance allows.
    for (var attempt = 1; ; attempt++) {
      final testInstance = await createTestModuleInstance(
        dio: dio,
        planId: testPlanId,
        moduleName: moduleName,
        clientAuthType:
            variant['client_auth_type'] as String? ?? 'client_secret_basic',
        responseType: variant['response_type'] as String? ?? 'code',
        responseMode: variant['response_mode'] as String? ?? 'default',
        // Dynamic RP sends no variant at all: every dimension stated here becomes
        // an equality the plan's stored module entry must satisfy, and one it
        // recorded differently makes the attach match nothing.
        variantFromPlan: moduleVariantComesFromPlan(planName),
        // Module-level variants are NOT the same as plan-level ones. Dynamic RP
        // rejects client_registration at api/plan and requires it at api/runner.
        extraVariant: moduleVariantFor(planName),
      );

      final testInstanceId = testInstance['id'] as String;
      final logger = Logger('oidc.conformance.$moduleName.$testInstanceId');
      final logsToWrite = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        final message =
            '[${record.time} ${record.level.name}][${record.loggerName}]: ${record.message}';
        logsToWrite.add(message);
      });
      final url = testInstance['url'] as String;
      logger
        ..info('Module starting. Variant: $variant')
        ..info('Test instance created: $testInstance')
        ..info('Test Instance ID: $testInstanceId, URL: $url')
        ..info(
          'Monitoring logs for test instance to wait for ready state: '
          '$testInstanceId',
        );
      final setupStopwatch = Stopwatch()..start();
      var pollCount = 0;
      monitorLogsLoop:
      await for (final logs in monitorTestLogs(
        dio: dio,
        instanceId: testInstanceId,
      )) {
        pollCount += 1;
        if (pollCount % 5 == 0) {
          logger.info(
            'Still waiting for setup... polls=$pollCount, elapsed=${setupStopwatch.elapsed}.',
          );
        }
        for (final log in logs) {
          logger.fine('Log: $log');
          if (log['msg'] == 'Setup Done') {
            logger.info('Test instance setup done: $testInstanceId');
            break monitorLogsLoop;
          }
        }
      }
      setupStopwatch.stop();
      logger.info(
        'Setup completed after ${setupStopwatch.elapsed} (polls=$pollCount).',
      );

      // The WebFinger modules do NOT issue at the URL above. The suite appends a
      // random per-run suffix to the issuer for exactly these two modules, and
      // hands the result out only through the WebFinger response -- so this
      // lookup is load-bearing: skip it and discovery goes to the wrong issuer.
      //
      // Resolved through the library rather than the harness's Dio on purpose.
      // These modules test whether the RELYING PARTY can do WebFinger; a lookup
      // written here would pass while package:oidc still could not.
      //
      // It runs AFTER the setup wait, not before: the suite's dispatcher refuses
      // a WebFinger lookup for a test still in CREATED state ("Please wait for
      // the test to be in WAITING state"), and every other suite request this
      // loop makes is already gated behind the same wait -- the manager is lazy,
      // so its discovery fetch happens at init() below.
      var issuer = url;
      final webFingerIdentifier = webFingerIdentifierFor(
        moduleName: moduleName,
        alias: conformanceAlias(planName: planName, platform: platform),
        host: Uri.parse(baseUrl).host,
      );
      if (webFingerIdentifier != null) {
        logger.info('Resolving issuer via WebFinger: $webFingerIdentifier');
        // The suite is a live third party and this Dio carries no timeout, so an
        // unbounded lookup would hang the job rather than fail it -- the exact
        // failure mode manager.dart's flowTimeoutSeconds exists to prevent, but
        // that bounds the browser flow only, not a bare GET.
        final resolved = await OidcEndpoints.getIssuerViaWebFinger(
          webFingerIdentifier,
        ).timeout(const Duration(seconds: 30));
        issuer = resolved.toString();
        logger.info('WebFinger resolved issuer: $issuer');
      }

      final manager = conformanceManager(
        issuer,
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: redirectUri,
        postLogoutRedirectUri: redirectUri,
        frontChannelLogoutUri: Uri(path: 'redirect.html'),
        // See moduleFinishesBeforeUserinfo (api.dart): this one module's suite
        // instance finishes the moment the client has fetched discovery + jwks,
        // and the manager's own (otherwise-automatic) userinfo call arrives
        // after that, which the suite answers with an "Illegal test state
        // change" error that flips an otherwise-correct login to FAILED.
        sendUserInfoRequest: !moduleFinishesBeforeUserinfo(moduleName),
        // See requiresSessionManagementMonitoring (api.dart): OidcSessionManagementSettings.enabled
        // defaults to false, and this module needs it true to get ANY
        // check_session_iframe traffic at all -- the automatic post-login
        // monitor and the post-logout probe are both gated on it.
        sessionManagementEnabled: requiresSessionManagementMonitoring(
          moduleName,
        ),
      );
      app_state.managersRx.update((managers) => managers..add(manager));
      app_state.currentManagerRx.$ = manager;

      logger.info('Initializing manager for test instance: $testInstanceId');
      // NOTE (merge with #469, test/467-per-module-conformance): this module's
      // correct outcome is init() itself throwing -- the RP must stop after
      // fetching discovery (OIDC Discovery §4.3) -- so it is the one module whose
      // init failure is caught here instead of aborting the whole plan.
      if (moduleName == discoveryIssuerMismatchModule) {
        var rejected = false;
        try {
          await manager.init();
          logger.severe(
            'init() accepted a discovery document with a bad issuer',
          );
        } on OidcException catch (e) {
          // Only the issuer rejection counts; anything else (e.g. the discovery
          // fetch failing) is a real failure and aborts as for other modules.
          if (!e.message.contains('Issuer mismatch')) {
            rethrow;
          }
          rejected = true;
          logger.info('Rejected at discovery, as the module requires: $e');
        }
        issuerMismatchRejected = rejected;
        print('[e2e] $moduleName -> rejected at discovery: $rejected');
        if (rejected) {
          final verdict = await pollConformanceModuleVerdict(
            dio: dio,
            instanceId: testInstanceId,
          );
          await _recordModuleVerdict(
            dio: dio,
            instanceId: testInstanceId,
            moduleFailures: moduleFailures,
            logger: logger,
            moduleName: moduleName,
            verdict: verdict,
            authDescription: 'rejected at discovery (expected)',
          );
          await sub.cancel();
          app_state.currentManagerRx.$ = app_state.managersRx.$.first;
          app_state.managersRx.update((managers) => managers..remove(manager));
          if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
            archive.addFile(
              ArchiveFile.bytes(
                '$moduleName.log',
                utf8.encode(logsToWrite.join('\n')),
              ),
            );
          }
          continue moduleLoop;
        }
      } else {
        await manager.init();
      }
      expect(manager.didInit, true);
      logger.info('Manager initialized');
      if (moduleName == 'oidcc-client-test-discovery-openid-config') {
        final verdict = await pollConformanceModuleVerdict(
          dio: dio,
          instanceId: testInstanceId,
        );
        await _recordModuleVerdict(
          dio: dio,
          instanceId: testInstanceId,
          moduleFailures: moduleFailures,
          logger: logger,
          moduleName: moduleName,
          verdict: verdict,
          authDescription: 'not driven (discovery-only module)',
        );
        app_state.currentManagerRx.$ = app_state.managersRx.$.first;
        app_state.managersRx.update((managers) => managers..remove(manager));
        await sub.cancel();
        continue moduleLoop;
      }
      // Recorded rather than discarded: swallowing the result here would let the
      // suite pass whether or not the browser can capture a redirect at all. Not
      // asserted per-module, since a negative module ends with no user by design.
      // Which flow to drive is the module's decision, not ours: the suite states
      // it in the variant, and the Basic/Config plans simply always say `code`.
      // Hardcoding the code flow is why the hybrid and implicit plans could not
      // be run at all -- every module would have been driven with the wrong
      // response_type and failed for a reason that had nothing to do with the
      // library.
      final responseTypes = (variant['response_type'] as String? ?? 'code')
          .split(' ')
          .where((e) => e.isNotEmpty)
          .toList();
      final hasCode = responseTypes.contains('code');
      final hasFrontChannelToken =
          responseTypes.contains('id_token') || responseTypes.contains('token');
      final flowName = hasCode
          ? (hasFrontChannelToken ? 'hybrid' : 'authorization code')
          : 'implicit';
      logger.info(
        'Starting login $flowName flow (${responseTypes.join(' ')})...',
      );
      // Extracted so [requiresSecondLoginForKeyRotation] modules can call it a
      // SECOND time below: the suite rotates its signing key only once a second
      // `authorize` request arrives, so without a second real interaction here
      // the module waits forever for one the harness never made (#467).
      // What the CLIENT saw, carried into the per-module failure line: on iOS
      // that line is the only output that reaches the job log (see
      // describeSuiteLogForFailure, api.dart).
      String? loginError;
      int? loginStartedAtMs;
      final loginStopwatch = Stopwatch();
      // The native browser layer's own events (oidc_android / oidc_darwin; empty
      // elsewhere), timed from the login start: they show whether the browser
      // opened promptly, and whether the flow ended in a redirect or in
      // flowTimeoutSeconds' cancel.
      //
      // Subscribed for the whole module rather than per attempt: the native
      // event channel and the method reply that completes the login are
      // separate channels, so the final event can land just after the login's
      // Future does. It is cancelled once the verdict is recorded.
      final browserTimeline = <String>[];
      var loginStartedAt = DateTime.now();
      final browserEvents = manager.events().listen((event) {
        if (event is! OidcNativeBrowserEvent) {
          return;
        }
        final offset =
            event.at.difference(loginStartedAt).inMilliseconds / 1000;
        browserTimeline.add(
          '${describeNativeBrowserEvent(event)}@'
          '${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(2)}s',
        );
      });
      Future<OidcUser?> attemptLogin() async {
        browserTimeline.clear();
        loginError = null;
        loginStartedAt = DateTime.now();
        loginStartedAtMs = loginStartedAt.millisecondsSinceEpoch;
        loginStopwatch
          ..reset()
          ..start();
        // A login still pending far past a healthy one is reported with a
        // timestamp, so the iOS screen recording can be read at that moment
        // (see loginStallProbeOffsets). print(), because the iOS job only
        // keeps print output (via the simulator log capture).
        final stallReports = [
          for (final offset in loginStallProbeOffsets)
            Timer(offset, () {
              print(
                '[e2e] LOGIN-PENDING $moduleName ($testInstanceId) after '
                '${offset.inSeconds}s; browser events '
                '[${browserTimeline.join(', ')}]',
              );
            }),
        ];
        try {
          if (!hasCode) {
            // No code comes back, so there is nothing to exchange. Deprecated in
            // the library and by the OAuth Security BCP, but the Implicit RP
            // profile is defined in terms of it.
            // ignore: deprecated_member_use
            return await manager.loginImplicitFlow(responseType: responseTypes);
          }
          if (hasFrontChannelToken) {
            return await manager.loginHybridFlow(responseType: responseTypes);
          }
          return await manager.loginAuthorizationCodeFlow();
        } catch (e, stackTrace) {
          // Expected for the negative modules, whose broken responses the client
          // must reject, so record it rather than failing the run here.
          logger.severe('Login flow threw for $moduleName', e, stackTrace);
          loginError = '$e';
          return null;
        } finally {
          loginStopwatch.stop();
          for (final report in stallReports) {
            report.cancel();
          }
        }
      }

      final authResult = await attemptLogin();
      if (authResult == null && attempt <= maxModuleReruns) {
        // Did the browser reach the suite at all? Only the suite's own log can
        // say, and only a "no" from it lets this instance be discarded (see
        // shouldRerunModuleOnFreshInstance for why that cannot hide a verdict).
        final suiteLog = await fetchTestLogs(
          dio: dio,
          instanceId: testInstanceId,
        );
        if (shouldRerunModuleOnFreshInstance(
          loggedIn: false,
          attempt: attempt,
          suiteLog: suiteLog,
        )) {
          rerunNote =
              'RERUN: instance $testInstanceId was discarded because the suite '
              'received NO authorization request (client: no user after '
              '${loginStopwatch.elapsed.inMilliseconds}ms'
              '${loginError == null ? '' : ', login threw: $loginError'}'
              '; browser events [${browserTimeline.join(', ')}])';
          // print(), not logger: logger output is invisible in the iOS job log.
          print(
            '[e2e] $moduleName -> $rerunNote; running it once more on a '
            'fresh instance',
          );
          logger.warning(rerunNote);
          try {
            // Stop the abandoned instance rather than leave it WAITING on the
            // suite.
            await cancelTest(dio: dio, instanceId: testInstanceId);
          } on Object catch (e) {
            logger.warning('Could not stop instance $testInstanceId: $e');
          }
          await browserEvents.cancel();
          await sub.cancel();
          app_state.currentManagerRx.$ = app_state.managersRx.$.first;
          app_state.managersRx.update((managers) => managers..remove(manager));
          continue;
        }
      }
      if (authResult != null) {
        successfulLogins++;
        // oidcc-client-test-signing-key-rotation (see
        // requiresSecondLoginForKeyRotation, api.dart) only rotates its signing
        // key, and only finishes, once it sees a SECOND full authorization
        // interaction. package:oidc_core already self-heals a rotated key on
        // its own (one rate-limited, cache-busting jwks refetch on a kid miss --
        // OIDC Core §10.1.1); the harness just has to actually issue the second
        // login the module is waiting for.
        if (requiresSecondLoginForKeyRotation(moduleName)) {
          logger.info(
            'Signing-key-rotation module: issuing a second login to trigger '
            'the key rotation and re-verification...',
          );
          final secondAuthResult = await attemptLogin();
          logger.info(
            secondAuthResult == null
                ? 'Second login for $moduleName did not complete; the suite '
                      'verdict below will most likely be non-terminal.'
                : 'Second login completed: '
                      '${_describeToken(secondAuthResult.token)}',
          );
        }
        // oidcc-client-test-session-management (see
        // requiresSessionManagementMonitoring, api.dart) will not finish unless
        // the suite observes a check_session_iframe postMessage round trip
        // BEFORE logout, and `listenToUserSessionIfSupported`'s automatic
        // monitor runs on its own schedule (iframe load, then
        // sessionManagementSettings.interval) -- calling logout() immediately
        // after login, as every other module does, would very likely race it.
        // Poll the suite's own log for its confirmation instead of guessing a
        // sleep duration that either races the monitor or wastes every other
        // module's time budget.
        if (requiresSessionManagementMonitoring(moduleName)) {
          logger.info(
            'Session management module: waiting for the suite to observe the '
            'pre-logout check_session_iframe round trip...',
          );
          final sawPreLogoutCheck = await waitForSuiteLogEntry(
            dio: dio,
            instanceId: testInstanceId,
            matches: (entry) =>
                isSessionCheckPostMessageLogEntry(entry['msg'] as String?),
          );
          logger.info(
            sawPreLogoutCheck
                ? 'Suite confirmed the pre-logout check_session_iframe round '
                      'trip.'
                : 'Suite log never showed the pre-logout check_session_iframe '
                      'round trip within the wait budget; logging out anyway so '
                      'the suite verdict below names the real failure instead '
                      'of the harness hanging silently.',
          );
        }
        // The logout profiles are two-step: log in, THEN initiate logout, and the
        // module only completes once it observes the end-session request. This
        // harness drove the login and stopped, so every logout module sat waiting
        // for a logout that never came, timed out at flowTimeoutSeconds, and
        // reported no user -- four plans failing for one missing call, not four
        // separate defects.
        //
        // postLogoutRedirectUri and frontChannelLogoutUri were already configured
        // on the plan request, which is exactly why this looked wired.
        if (isLogoutConformancePlan(planName)) {
          logger.info('Logout profile: initiating RP-initiated logout...');
          try {
            await manager.logout();
            successfulLogouts++;
            logger.info('Logout completed.');
          } catch (e, stackTrace) {
            // Some logout modules deliberately break the end-session response;
            // record it rather than failing the whole plan here, matching how the
            // login step treats its own negative modules.
            logger.severe('Logout threw for $moduleName', e, stackTrace);
          }
        }
      }
      // print(), not logger: logger output goes into the certification archive
      // rather than CI stdout. patrol also drops test stdout unless --verbose.
      print(
        '[e2e] $moduleName -> authResult ${authResult == null ? 'NULL' : 'ok'}',
      );
      if (authResult == null) {
        // "No user returned" is all the client can say, and it is not enough: a
        // login that silently timed out and a negative module the client
        // correctly rejected produce the identical line. The suite knows which
        // happened -- ask it, rather than inferring from the client side.
        //
        // This is what the logout modules needed: each spent ~33s in
        // loginAuthorizationCodeFlow and returned nothing, with no exception, so
        // there was no way to tell whether the OP was waiting on the client or
        // the client was waiting on the OP.
        try {
          final status = await getTestStatus(
            dio: dio,
            instanceId: testInstanceId,
          );
          // Log the WHOLE payload. The first version of this read
          // status['status'] and status['result'] -- key names invented rather
          // than looked up -- and printed "status=null result=null" for every
          // module. A diagnostic added to stop guessing that was itself a guess.
          // Print what the endpoint actually returns, then read real keys off a
          // real response.
          logger.info('Suite status for $moduleName: $status');
        } on Object catch (e) {
          logger.warning('Could not read suite status for $moduleName: $e');
        }
        // `status` says WHETHER the suite issued a response; its log says WHY it
        // did not. The harness already fetches this endpoint via monitorTestLogs
        // and stops at "Setup Done", so every entry the suite wrote DURING the
        // module was retrieved and discarded -- which is how 75 web fragment
        // modules failed with nothing but a client-side timeout to go on.
        //
        // Tail only: the head is the setup chatter already seen, and the
        // refusal, when there is one, is the last thing written.
        final suiteLog = await fetchTestLogs(
          dio: dio,
          instanceId: testInstanceId,
        );
        if (suiteLog.isEmpty) {
          logger.info('Suite log for $moduleName: empty.');
        } else {
          final tail = suiteLog.length <= 12
              ? suiteLog
              : suiteLog.sublist(suiteLog.length - 12);
          logger.info(
            'Suite log tail for $moduleName (${tail.length} of '
            '${suiteLog.length} entries):',
          );
          for (final entry in tail) {
            logger.info(
              '  [${entry['result'] ?? '-'}] ${entry['msg']}'
              '${entry['error'] == null ? '' : ' | error: ${entry['error']}'}',
            );
          }
        }
      }
      // Ask the suite itself whether THIS module is one it considers passed,
      // regardless of what the client observed. authResult alone cannot tell a
      // negative module that correctly saw no user from one that WRONGLY logged
      // in -- successfulLogins only counts the latter case as a win -- and a
      // module that is supposed to log in could still fail a suite-side check
      // (e.g. a required requirement) after the client's own flow looked clean.
      // See #467.
      final verdict = await pollConformanceModuleVerdict(
        dio: dio,
        instanceId: testInstanceId,
      );
      await _recordModuleVerdict(
        dio: dio,
        instanceId: testInstanceId,
        moduleFailures: moduleFailures,
        logger: logger,
        moduleName: moduleName,
        verdict: verdict,
        clientLoginStartedAtMs: loginStartedAtMs,
        authDescription:
            '${authResult == null ? 'no user' : 'logged in'} after '
            '${loginStopwatch.elapsed.inMilliseconds}ms'
            '${loginError == null ? '' : ', login threw: $loginError'}'
            '; browser events [${browserTimeline.join(', ')}]'
            '${rerunNote == null ? '' : '; $rerunNote'}',
      );
      if (rerunNote != null) {
        print(
          '[e2e] $moduleName -> rerun on $testInstanceId: suite status='
          '${verdict['status']} result=${verdict['result']}',
        );
      }
      logger
        ..info(
          authResult == null
              ? 'No user returned (expected for a negative module).'
              : 'Login successful: ${_describeToken(authResult.token)}',
        )
        ..info('Cleaning up manager for test instance: $testInstanceId');
      await browserEvents.cancel();
      await sub.cancel();
      app_state.currentManagerRx.$ = app_state.managersRx.$.first;
      app_state.managersRx.update((managers) => managers..remove(manager));
      if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
        final strToWrite = logsToWrite.join('\n');
        final data = utf8.encode(strToWrite);
        archive.addFile(ArchiveFile.bytes('$moduleName.log', data));
      }
      break;
    }
  }

  expect(
    issuerMismatchRejected,
    isNot(false),
    reason:
        '$discoveryIssuerMismatchModule: init() must reject a discovery '
        'document whose issuer does not match (OIDC Discovery §4.3).',
  );

  // Individual modules may legitimately end with no user, but a platform that
  // cannot capture the browser redirect at all scores zero here.
  print(
    '[e2e] successful logins: $successfulLogins / ${testPlanModules.length}',
  );
  expect(
    successfulLogins,
    greaterThan(0),
    reason:
        'no module of $planName completed a login on ${getPlatformName()}. '
        'Two very different causes produce this, and the per-module suite '
        'status dumped above distinguishes them: either the redirect never '
        'reached the app, or the suite aborted before issuing one (a module '
        'whose status carries an error stack and no '
        'authorization_endpoint_response_redirect never redirected at all). '
        'Do not assume the former -- this message previously blamed the '
        "Android intent-filter, and the real cause was the suite's "
        'GenerateSessionState throwing on a host-less redirect_uri, on macOS '
        'as much as on Android.',
  );

  // The per-module gate the aggregate above cannot be: successfulLogins only
  // ever moves in the direction a negative module must NOT move, so a
  // negative module that wrongly logs in stays invisible to it as long as any
  // other module in the plan still passes. Asking the suite for each module's
  // own result closes that gap (#467) -- including for the implicit-flow
  // oidcc-client-test-missing-athash module that PR #447's CI let through.
  expect(
    moduleFailures,
    isEmpty,
    reason:
        'The conformance suite itself rejected these $planName modules on '
        '${getPlatformName()} (status/result read from GET api/info/{id}; '
        'acceptable results are PASSED, WARNING, REVIEW, SKIPPED -- the same '
        'set certification.openid.net itself accepts -- FAILED and a '
        'non-terminal status after the poll timeout are not):\n'
        '${moduleFailures.join('\n')}',
  );

  // The logout plans exist to exercise logout, so a login-only gate cannot
  // report on them. Kept separate from the login gate above so a failure says
  // which half broke.
  if (isLogoutConformancePlan(planName)) {
    print(
      '[e2e] successful logouts: $successfulLogouts / ${testPlanModules.length}',
    );
    expect(
      successfulLogouts,
      greaterThan(0),
      reason:
          'every logout in $planName threw on ${getPlatformName()}, so the '
          'plan proves nothing about logout even though its logins succeeded. '
          'Check the end-session redirect: back-channel modules need a '
          'backchannel_logout_uri the OP can reach, and front-channel modules '
          'need a frontchannel_logout_uri this platform can actually serve.',
    );
  }

  if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
    try {
      print('Creating archive of client logs...');

      final ms = OutputMemoryStream();
      ZipEncoder().encodeStream(archive, ms);
      final bytes = ms.getBytes();
      print('Sending certification package request to server...');
      final resultLogs = await publishCertificationPackage(
        dio: dio,
        planId: testPlanId,
        clientSideData: bytes,
      );
      if (resultLogs == null) {
        print('No Logs returned from server');
      } else {
        var outputFile = File('client-logs/final.zip').absolute;
        outputFile = await outputFile.create(recursive: true);
        outputFile = await outputFile.writeAsBytes(resultLogs);
        print('Saving logs archive at: ${outputFile.path}');
      }
    } catch (e, stackTrace) {
      _testLogger.severe(
        'Failed to publish certification package',
        e,
        stackTrace,
      );
      print('failed to zip test logs: $e');
    }
  }
  print('OIDC Conformance Test completed');
  _testLogger.info('OIDC Conformance Test completed successfully.');
}
