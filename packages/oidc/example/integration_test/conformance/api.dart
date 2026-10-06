// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Variant dimensions a plan's modules require to be stated outright.
///
/// The suite defaults some dimensions and demands others, and which is which
/// cannot be read off the plan name. Getting it wrong is not a test failure:
/// it is an HTTP 400 at plan creation, from a live third-party server, so the
/// mistake costs a full CI round trip to discover. `client_auth_type` is
/// recorded here because the config plan's discovery module refuses the whole
/// plan without it, while the basic plan resolves it to `client_secret_basic`
/// on its own -- which is exactly why the omission went unnoticed on the only
/// plan that had ever been run.
///
/// Add a plan here when the suite rejects it for a missing dimension. The
/// entry turns that network round trip into an immediate local error.
const _requiredExtraVariants = <String, List<String>>{
  'oidcc-client-config-certification-test-plan': ['client_auth_type'],
  // All four logout plans demand it too, like config and unlike hybrid and
  // implicit, which reject it. Five plans, three answers, one dimension.
  'oidcc-client-rp-initiated-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-front-channel-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-back-channel-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-rp-session-management-rp-basic': ['client_auth_type'],
  'oidcc-client-test-3rd-party-init-login-test-plan': [
    'client_auth_type',
    'response_type',
  ],
  // Dynamic RP is the fourth distinct combination for the same three
  // dimensions: FORBIDS request_type and client_registration (below), and
  // REQUIRES client_auth_type. Its webfinger module said so:
  //   TestModule 'oidcc-client-test-discovery-webfinger-acct' requires a
  //   value for variant 'client_auth_type'
  'oidcc-client-dynamic-certification-test-plan': ['client_auth_type'],
};

/// Variant dimensions a plan sets ITSELF, and rejects the caller for setting.
///
/// The exact inverse of [_requiredExtraVariants], for the same dimension:
///
///   Variant 'client_auth_type' has been set by user, but test plan already
///   sets this variant for module 'oidcc-client-test'
///
/// So `client_auth_type` is optional on the basic plan, mandatory on the
/// config plan, and forbidden on these two. Three rules for one dimension,
/// none of them derivable from the plan name -- each cost an HTTP 400 to
/// learn, which is precisely why both directions are recorded here instead of
/// being rediscovered from CI.
const _forbiddenExtraVariants = <String, List<String>>{
  'oidcc-client-hybrid-certification-test-plan': ['client_auth_type'],
  'oidcc-client-implicit-certification-test-plan': ['client_auth_type'],
  // A SECOND dimension with per-plan rules. Dynamic RP sets request_type
  // itself, so the plain_http_request every other plan needs is rejected here.
  // request_type is therefore nullable below: "always send it" was an
  // assumption, not a requirement.
  // Dynamic RP sets BOTH itself. Passing client_registration: dynamic_client
  // looked like the obvious counterpart to static_client and was rejected --
  // the plan is "dynamic" precisely because it owns that dimension.
  'oidcc-client-dynamic-certification-test-plan': [
    'request_type',
    'client_registration',
  ],
};

/// Extra variant dimensions a plan needs at the MODULE endpoint
/// (`api/runner`), which are NOT the same as the ones it needs at the PLAN
/// endpoint (`api/plan`).
///
/// Dynamic RP is the case that forced this to exist, and it is the sharpest
/// rule in the whole set because the two endpoints disagree:
///
///   api/plan    Variant 'client_registration' has been set by user, but test
///               plan already sets this variant
///   api/runner  createTestModule failed: Missing value for required variant
///               parameter: client_registration
///
/// Forbidden on one, required on the other, same dimension, same plan. The
/// plan endpoint chooses the value and the module endpoint makes you restate
/// it.
///
/// No plan needs an entry today. Dynamic RP had one -- client_registration
/// and request_type -- and it was the wrong answer to the right complaint:
/// stating them silenced "Missing value for required variant parameter" and
/// replaced it with a 500 carrying "modifiedCount=0". See
/// [moduleVariantComesFromPlan] for why restating a dimension the plan owns
/// cannot work. The map stays because the plan endpoint's asymmetry is real
/// and the next plan may genuinely need it.
const _extraModuleVariants = <String, Map<String, String>>{};

/// Plans whose module instances are created with NO `variant` at all, letting
/// the suite fill it in from the plan.
///
/// The suite attaches a module instance to its plan with a Mongo arrayFilter
/// assembled from the variant the caller sent
/// (`DBTestPlanService.updateTestPlanWithModule`):
///
///   variant.getVariant().forEach((name, value) ->
///       updateCriteria.and("module.variant." + name).is(value));
///   updateCriteria.and("module.testModule").is(testName);
///
/// Each dimension sent is one more equality the STORED module entry has to
/// satisfy. Send a dimension the plan recorded differently -- or did not
/// record -- and the filter matches no array element, the update reports
/// `modifiedCount=1 != 0`, and the whole request 500s with a Java stack trace
/// that names neither the dimension nor the value.
///
/// Sending nothing is the path the suite is built for: `TestRunner` reaches
/// `getFixedVariantIfOnlyOneMatchingModuleInPlan` -- which hands back the
/// module's own stored variant -- only when no variant arrived from the API.
/// That value satisfies the filter by construction, so this works without the
/// harness ever knowing what the plan chose.
///
/// Scoped to the one plan that needs it. The other twelve pass while stating
/// their variant, which means theirs already matches what the plan stored.
const _moduleVariantFromPlan = <String>{
  'oidcc-client-dynamic-certification-test-plan',
};

/// Whether [planName]'s module instances omit the `variant` parameter.
bool moduleVariantComesFromPlan(String planName) =>
    _moduleVariantFromPlan.contains(planName);

/// The `api/runner` URL that creates a module instance, with `variant` present
/// only when [variant] is non-null.
Uri moduleInstanceUri({
  required String planId,
  required String moduleName,
  Map<String, dynamic>? variant,
}) => Uri(
  path: 'api/runner',
  queryParameters: {
    'plan': planId,
    'test': moduleName,
    if (variant != null) 'variant': jsonEncode(variant),
  },
);

/// The extra module-level variant [planName] requires, empty when it needs none.
Map<String, String> moduleVariantFor(String planName) =>
    _extraModuleVariants[planName] ?? const {};

/// Whether [planName] contains modules that address the running test through
/// the suite's `alias` rather than through the URL `api/runner` hands back.
///
/// Only the Dynamic RP plan does. Its WebFinger modules expect the RP to look
/// up `acct:<alias>.oidcc-client-test-discovery-webfinger-acct@<host>`, and the
/// suite resolves that alias to the running test -- there is no other way to
/// name it. Every other plan reads its test URL straight out of the
/// module-instance response, so they are deliberately left alone: sending an
/// alias changes the URL shape the suite issues, and twelve currently-passing
/// profiles are not worth risking for a field they never read.
bool planNeedsAlias(String planName) =>
    planName == 'oidcc-client-dynamic-certification-test-plan';

/// An alias that survives the suite dispatcher's parse.
///
/// The dispatcher splits a WebFinger `acct:` resource with
/// `^acct:([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)@.*$`, so a dot inside the alias
/// would be read as the alias/test-name separator and the lookup would resolve
/// to neither. Every character outside that class is folded to `_`.
///
/// Both [platform] and [planName] are in the key because the CI matrix runs
/// platforms as parallel jobs against one shared suite instance: an alias
/// another job already registered would resolve to that job's test.
String conformanceAlias({required String planName, required String platform}) =>
    'oidc_${platform}_$planName'.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');

/// The WebFinger identifier [moduleName] expects the RP to start discovery
/// from, or null when the module resolves its issuer the ordinary way.
///
/// Only two modules use WebFinger, and they demand different syntaxes. Each
/// validates the scheme of the resource it was queried with, so the shapes are
/// not interchangeable:
///
///   acct  acct:<alias>.<moduleName>@<host>
///   url   https://<host>/<alias>/<moduleName>
///
/// The `<alias>.<moduleName>` pair is how the suite finds the running test --
/// its dispatcher splits on the first dot -- which is why [conformanceAlias]
/// must never produce one.
///
/// This returns the identifier only. Resolving it is the library's job, via
/// `OidcEndpoints.getIssuerViaWebFinger`: the module under test is a test of
/// the RP, so a lookup performed by the harness would prove nothing about
/// package:oidc.
String? webFingerIdentifierFor({
  required String moduleName,
  required String alias,
  required String host,
}) => switch (moduleName) {
  'oidcc-client-test-discovery-webfinger-acct' =>
    'acct:$alias.$moduleName@$host',
  'oidcc-client-test-discovery-webfinger-url' =>
    'https://$host/$alias/$moduleName',
  _ => null,
};

/// Whether [moduleName] finishes as soon as the RP has fetched BOTH the
/// discovery document and the (randomized-path) `jwks_uri`, before any
/// userinfo call.
///
/// `OIDCCClientTestDiscoveryJwksUriKeys`
/// (openid-certification/conformance-suite,
/// `src/main/java/net/openid/conformance/openid/client/config/OIDCCClientTestDiscoveryJwksUriKeys.java`)
/// overrides `finishTestIfAllRequestsAreReceived` to call `fireTestFinished()`
/// the instant `receivedDiscoveryRequest && receivedJwksRequest` are both
/// true -- i.e. right after the client verifies the id_token's signature
/// against the freshly-fetched jwks_uri, well before a normal login's own
/// userinfo call. `OidcUserInfoSettings.sendUserInfoRequest` (package:oidc)
/// defaults to `true`, so the manager's own userinfo call used to arrive
/// AFTER the suite had already finished the module, and the suite answered it
/// with "Illegal test state change: FINISHED -> RUNNING" -- confirmed on CI
/// run 37252425838 (linux instance Bji4pEGUaWavYTg, windows instance
/// sGDQlFZLvzCkkUY), which turned an otherwise-correct login into a FAILED
/// verdict. `runOidcConformanceTest` in shared_e2e.dart builds exactly this
/// module's manager with userinfo disabled rather than weakening the
/// per-module assertion; see oidc#467.
bool moduleFinishesBeforeUserinfo(String moduleName) =>
    moduleName == 'oidcc-client-test-discovery-jwks-uri-keys';

/// Whether [moduleName] requires a SECOND full authorization interaction
/// after the first one succeeds.
///
/// `OIDCCClientTestSigningKeyRotation`
/// (openid-certification/conformance-suite,
/// `src/main/java/net/openid/conformance/openid/client/config/OIDCCClientTestSigningKeyRotation.java`)
/// rotates its signing key only once a SECOND `authorize` request arrives
/// (`handleClientRequestForPath` sets `receivedSecondAuthorizationRequest` and
/// calls `configureServerJWKS()` again at exactly that point, not before), and
/// its `finishTestIfAllRequestsAreReceived` override will not fire finished
/// for the CODE response type -- the one this harness drives it with in the
/// Config RP plan -- until BOTH `receivedSecondUserinfoRequest` and
/// `receivedSecondJwksRequest` are true. That needs a second complete login:
/// a second token exchange whose id_token is signed by the ROTATED key (so
/// `package:oidc_core`'s own kid-miss forced-refetch self-heal -- OIDC Core
/// §10.1.1, see `OidcUser.fromIdToken` -- fetches the jwks a second time) and
/// a second userinfo call with the new access_token. Confirmed stuck at
/// `status=WAITING result=null` after only ONE login on CI run 37252425838
/// (linux instance A8MLwlTP0UizYW0, windows instance WmGCI7Zvht0bmZl) because
/// the harness never issued that second interaction. See oidc#467.
bool requiresSecondLoginForKeyRotation(String moduleName) =>
    moduleName == 'oidcc-client-test-signing-key-rotation';

/// Whether [moduleName] needs OpenID Connect Session Management 1.0 actually
/// turned on for the manager driving it, and a wait for the suite to observe
/// the PRE-logout `check_session_iframe` round trip before logging out.
///
/// `OIDCCClientTestSessionManagement`
/// (openid-certification/conformance-suite,
/// `src/main/java/net/openid/conformance/openid/client/logout/OIDCCClientTestSessionManagement.java`,
/// extending `AbstractOIDCCClientLogoutTest`) will not fire finished until
/// `receivedAuthorizationRequest && receivedEndSessionRequest &&
/// receivedCheckSessionRequestBeforeLogout &&
/// receivedCheckSessionRequestAfterLogout` are ALL true. The suite sets the
/// latter two only from `handleGetSessionStateViaAjaxRequest`: the OP's
/// `check_session_iframe` page itself calls back to `get_session_state`
/// (`check_session_ajax_url`) the moment it RECEIVES a postMessage from the
/// RP, logging "OP iframe received postMessage request from RP iframe" --
/// see [isSessionCheckPostMessageLogEntry]. Loading the iframe alone
/// ("The client requested check_session_iframe") is not enough.
///
/// `package:oidc`'s own `OidcSessionManagementSettings.enabled` defaults to
/// `false` and gates EVERY piece of this: capturing `session_state` into the
/// logout state, the automatic post-login monitor
/// (`listenToUserSessionIfSupported`, wired to `userChanges` in
/// `user_manager_base.dart`), and the post-logout probe
/// (`startEndSessionConfirmation`, called from `handleEndSessionResponse`
/// right before `forgetUser()`). Confirmed on CI (oidc#467): with it left at
/// the default, login was immediately followed by logout with no
/// `check_session_iframe` traffic at all, and the module sat at
/// `status=WAITING result=null` forever. `conformanceManager`'s
/// `sessionManagementEnabled` parameter is `true` for exactly this module.
///
/// Even with it enabled, the regular monitor's first postMessage lands on its
/// OWN schedule (iframe load, then `sessionManagementSettings.interval`) --
/// calling `logout()` immediately after login would very likely race it. The
/// harness polls the suite's log for [isSessionCheckPostMessageLogEntry]
/// before logging out, rather than sleeping a guessed duration.
bool requiresSessionManagementMonitoring(String moduleName) =>
    moduleName == 'oidcc-client-test-session-management';

(String path, Map<String, dynamic> body) prepareTestPlanRequest({
  // oidcc-client-basic-certification-test-plan
  required String planName,
  required String description,
  required String clientId,
  required String redirectUri,
  // {"request_type":"plain_http_request","client_registration":"static_client"}
  String? clientRegistration,
  String? requestType,
  String? alias,
  String? clientSecret,
  String? postLogoutRedirectUri,
  String? frontChannelLogoutUri,
  // OIDC Registration 1.0 section 2 client metadata; the suite defaults an
  // omitted value to `web`, whose redirect_uri rules then reject a loopback
  // http redirect for any non-code response type. A native RP must say so.
  String? applicationType,
  Map<String, String>? extraVariant,
  String publish = 'everything',
}) {
  final variant = {
    if (requestType != null) 'request_type': requestType,
    if (clientRegistration != null) 'client_registration': clientRegistration,
    ...?extraVariant,
  };
  final missing = (_requiredExtraVariants[planName] ?? const <String>[])
      .where((dimension) => !variant.containsKey(dimension))
      .toList();
  if (missing.isNotEmpty) {
    throw ArgumentError(
      'The "$planName" plan requires the variant dimension(s) '
      '${missing.join(', ')}. The conformance suite enforces this at plan '
      'creation and answers HTTP 400, so pass them via extraVariant rather '
      'than discovering it from CI.',
    );
  }
  final forbidden = (_forbiddenExtraVariants[planName] ?? const <String>[])
      .where(variant.containsKey)
      .toList();
  if (forbidden.isNotEmpty) {
    throw ArgumentError(
      'The "$planName" plan sets the variant dimension(s) '
      '${forbidden.join(', ')} itself and rejects a caller-supplied value '
      'with HTTP 400. Drop them rather than discovering it from CI.',
    );
  }
  final uri = Uri(
    path: '/api/plan',
    queryParameters: {'planName': planName, 'variant': jsonEncode(variant)},
  );
  final body = {
    'description': description,
    'client': {
      'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret,
      if (applicationType != null) 'application_type': applicationType,
      'redirect_uri': redirectUri,
      if (postLogoutRedirectUri != null)
        'post_logout_redirect_uri': postLogoutRedirectUri,
      if (frontChannelLogoutUri != null)
        'frontchannel_logout_uri': frontChannelLogoutUri,
    },
    if (alias != null) 'alias': alias,
    'publish': publish,
  };
  return (uri.toString(), body);
}

Future<Map<String, dynamic>> getPlan({
  required Dio dio,
  required String planId,
  bool public = false,
}) async {
  final uri = Uri(
    path: 'api/plan/$planId',
    queryParameters: {'public': public.toString()},
  );
  // Assuming you have a Dio instance or similar HTTP client
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<void> deletePlan({required Dio dio, required String planId}) async {
  final uri = Uri(path: 'api/plan/$planId');
  // Assuming you have a Dio instance or similar HTTP client
  await dio.deleteUri<void>(uri);
}

/*
returns:
{
    "name": "oidcc-client-test-invalid-iss",
    "id": "5KqBAUA5ZqCKzci",
    "url": "https://www.certification.openid.net/test/a/package_oidc_windows"
}
*/
Future<Map<String, dynamic>> createTestModuleInstance({
  required Dio dio,
  required String planId,
  required String moduleName,
  String clientAuthType = 'client_secret_basic',
  String responseType = 'code',
  String responseMode = 'default',
  Map<String, dynamic>? extraVariant,
  bool variantFromPlan = false,
}) async {
  /*
  {"client_auth_type":"client_secret_basic","response_type":"code","response_mode":"default"}
   */
  final variant = variantFromPlan
      ? null
      : <String, dynamic>{
          'client_auth_type': clientAuthType,
          'response_type': responseType,
          'response_mode': responseMode,
          ...?extraVariant,
        };
  final uri = moduleInstanceUri(
    planId: planId,
    moduleName: moduleName,
    variant: variant,
  );
  // Same treatment prepareTestPlanRequest already gets, for the same reason.
  // Dio reports only the status code, and a bare "500" from this endpoint says
  // nothing about WHICH of the three dimensions below the suite objected to.
  // Dynamic RP fails here, and three earlier mysteries at the plan endpoint
  // each turned into a one-line fix the moment the server's own words were
  // printed instead of guessed at.
  final Response<Map<String, dynamic>> response;
  try {
    response = await dio.postUri<Map<String, dynamic>>(uri);
  } on DioException catch (e) {
    // `modifiedCount=0` from DBTestPlanService.updateTestPlanWithModule is the
    // shape that matters here: it is a Mongo update that matched NOTHING, so
    // the suite could not attach the module to the plan. That is not a
    // validation complaint about a missing dimension -- it means the
    // VariantSelection we sent is not the one the plan recorded for this
    // module. Guessing which dimension differs has cost three CI round trips
    // already, so on failure dump what the plan actually stored and compare.
    var planDump = '(plan could not be read)';
    try {
      final plan = await getPlan(dio: dio, planId: planId);
      final modules = plan['modules'];
      planDump = const JsonEncoder.withIndent(
        '  ',
      ).convert({'planVariant': plan['variant'], 'modules': modules});
    } on Object catch (inner) {
      planDump = '(plan fetch threw: $inner)';
    }
    throw StateError(
      'Creating a module instance for "$moduleName" failed with status '
      '${e.response?.statusCode}.\n'
      'Conformance suite response: ${e.response?.data}\n'
      'Request path: $uri\n'
      '${variant == null ? 'Variant sent: none (supplied by the plan).\n' : 'Variant sent: $variant\n'}'
      'Note this endpoint takes the variant PER MODULE, and a plan that '
      'rejects a dimension at plan level may reject it here too.\n'
      'PLAN AS STORED BY THE SUITE (compare its module variant to the one '
      'sent above):\n$planDump',
    );
  }
  return response.data ?? {};
}

Future<Map<String, dynamic>> getTestStatus({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<Map<String, dynamic>> startTest({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.postUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<Map<String, dynamic>> cancelTest({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.deleteUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

//api/plan/:id/certificationpackage
Future<List<int>?> publishCertificationPackage({
  required Dio dio,
  required String planId,
  required Uint8List clientSideData,
}) async {
  final uri = Uri(path: 'api/plan/$planId/certificationpackage');

  var attempt = 0;
  const maxAttempts = 5;
  const initialDelay = Duration(seconds: 1);

  while (true) {
    try {
      final formData = FormData();
      formData.files.add(
        MapEntry(
          'clientSideData',
          MultipartFile.fromBytes(
            clientSideData,
            filename: 'client_side_logs.zip',
            contentType: DioMediaType('application', 'zip'),
          ),
        ),
      );
      final response = await dio.postUri<Uint8List>(
        uri,
        data: formData,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/zip',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode != 422 || attempt >= maxAttempts - 1) {
        rethrow;
      }

      // Calculate backoff delay: initialDelay * 2^attempt, with jitter
      final backoff = initialDelay * (1 << attempt);
      final jitter = Duration(
        milliseconds:
            (backoff.inMilliseconds * 0.2 * (Random().nextDouble() * 2 - 1))
                .toInt(),
      );
      final delay = backoff + jitter;

      print(
        'Retrying publishCertificationPackage (attempt ${attempt + 1}/$maxAttempts) after ${delay.inMilliseconds}ms',
      );
      await Future<void>.delayed(delay);
      attempt++;
    }
  }
}

Future<Map<String, dynamic>> getTestSummary({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/info/$instanceId');
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

/// `TestModule.Result` values (the suite's own source,
/// `net.openid.conformance.testmodule.TestModule`) this harness accepts for
/// ANY module, positive or negative.
///
/// PASSED is the obvious case. WARNING, REVIEW and SKIPPED are accepted too,
/// matching what certification itself accepts: a profile can be certified
/// with PASSED, REVIEW, WARNING or SKIPPED results, and cannot be certified
/// with FAILED or INTERRUPTED. REVIEW usually asks a human to confirm
/// something like a screenshot; this harness runs unattended and cannot act
/// on it, so treating it as a failure would fail module categories the suite
/// itself does not consider broken. SKIPPED means the suite decided the
/// module could not run against this configuration (e.g. a server-side
/// feature the plan variant does not exercise), not a client defect.
const acceptableConformanceResults = {'PASSED', 'WARNING', 'REVIEW', 'SKIPPED'};

/// `TestModule.Status` values after which `TestModule.Result` is final --
/// the module will not take any further RP-observable step.
///
/// `TestModule.Status` also has `NOT_YET_CREATED`, `CREATED`, `CONFIGURED`,
/// `RUNNING` and `WAITING`, all non-terminal: the suite can still change its
/// mind about the result while a module is in any of those.
const terminalConformanceStatuses = {'FINISHED', 'INTERRUPTED'};

/// Whether the suite's own verdict for a module is one this harness accepts.
///
/// `null` is never accepted: either the field was absent, or the module's
/// result is still the suite's own `UNKNOWN` ("not yet known, probably still
/// running"), neither of which is a verdict.
bool isAcceptableConformanceResult(String? result) =>
    result != null && acceptableConformanceResults.contains(result);

/// Whether [status] is one of `TestModule.Status` after which the module's
/// result will not change further. See [terminalConformanceStatuses].
bool isTerminalConformanceStatus(String? status) =>
    status != null && terminalConformanceStatuses.contains(status);

/// Whether [error], raised by a [getTestSummary] call inside
/// [pollConformanceModuleVerdict], is worth retrying rather than letting it
/// end the poll outright.
///
/// A transient network hiccup or a suite-side 5xx against ONE poll must not
/// take the rest of the plan down with it: CodeRabbit and a human reviewer
/// both flagged that an uncaught exception here used to propagate out of
/// `pollConformanceModuleVerdict` -- an uncaught `Future` error inside the
/// `testWidgets`/`patrolTest` body running `runOidcConformanceTest` -- failing
/// the whole plan and losing every module after the one being polled, not
/// just the single bad request. A 4xx, a malformed response, or any other
/// non-transient error is NOT retried: retrying cannot change a deterministic
/// failure, and masking it behind a retry delay would only slow the run down
/// before it fails anyway.
bool isTransientConformancePollError(Object error) {
  if (error is! DioException) {
    return false;
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      return statusCode != null && statusCode >= 500;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return false;
    // A timeout while Dio's own response transformer (JSON decode) was
    // running, not a network condition -- not expected for this endpoint's
    // tiny JSON body, so treated conservatively as non-transient rather than
    // retried blind.
    case DioExceptionType.transformTimeout:
      return false;
  }
}

/// Retries [poll] while it fails with a transient error
/// ([isTransientConformancePollError]), up to [maxAttempts] attempts total,
/// waiting `initialDelay * 2^(attempt - 1)` between tries.
///
/// The last error is rethrown once attempts are exhausted, or immediately for
/// a non-transient error: this function only decides whether to retry, not
/// what an exhausted/non-transient failure means for the caller's verdict --
/// see [pollConformanceModuleVerdict], which turns that rethrow into a verdict
/// map rather than letting it escape.
///
/// [maxAttempts] and [initialDelay] are parameters (not hardcoded) so a test
/// can keep this fast and deterministic without mocking Dio or the clock: the
/// retry COUNT and the transient/non-transient DECISION are the pure logic
/// worth pinning down, and a millisecond-scale [initialDelay] exercises both
/// without a real wait.
Future<T> retryTransientConformancePollErrors<T>(
  Future<T> Function() poll, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await poll();
    } on Object catch (e) {
      attempt++;
      if (attempt >= maxAttempts || !isTransientConformancePollError(e)) {
        rethrow;
      }
      await Future<void>.delayed(initialDelay * (1 << (attempt - 1)));
    }
  }
}

/// One [getTestSummary] read, tolerant of a failure that survives
/// [retryTransientConformancePollErrors]: rather than letting it escape (and
/// taking the rest of the plan down with it), it is folded into a verdict map
/// carrying `pollError`. `isTerminalConformanceStatus(null)` is false, so
/// [pollConformanceModuleVerdict]'s own timeout loop, and
/// `_recordModuleVerdict`'s "never reached FINISHED/INTERRUPTED" message in
/// shared_e2e.dart, already handle a map shaped like this; `pollError` just
/// explains why THIS read could not refresh it. [previous] (the last summary
/// that DID succeed, if any) is carried forward so a poll that fails after the
/// module already reported something is not reported as if nothing had ever
/// been read.
Future<Map<String, dynamic>> _pollSummaryTolerant({
  required Dio dio,
  required String instanceId,
  Map<String, dynamic>? previous,
}) async {
  try {
    return await retryTransientConformancePollErrors(
      () => getTestSummary(dio: dio, instanceId: instanceId),
    );
  } on Object catch (e) {
    return {
      'status': previous?['status'],
      'result': previous?['result'],
      'pollError': '$e',
    };
  }
}

/// Polls `GET api/info/{id}` ([getTestSummary]) until the suite reports a
/// terminal `TestModule.Status` ([isTerminalConformanceStatus]) or [timeout]
/// elapses, returning whatever the last poll read either way.
///
/// This is `api/info`, deliberately NOT `api/runner` ([getTestStatus]):
/// confirmed against real CI output (oidc#467) that `api/runner/{id}` --
/// which this harness already called for null-result diagnostics below --
/// returns only the TestRunner's live browser-interaction state (`owner`,
/// `created`, `browser`, `name`, `exposed`, `id`, `error`, `updated`), with
/// no `status` or `result` key at all; that is why an earlier version of this
/// harness read `status['status']`/`status['result']` and got `null` for
/// every module, a payload-shape guess that was never corrected. The suite's
/// own OpenAPI document (`frontend/src/api/openapi.json` in
/// openid/conformance-suite) says outright: "Read the outcome from GET
/// /api/info/{id} (status and result)". `TestInfoResponse.status`/`.result`
/// there enumerate exactly `TestModule.Status`/`TestModule.Result`.
///
/// [timeout] defaults to 30s, widened from an earlier 15s: CI run 37252425838
/// (the same run that exposed the jwks-uri-keys and signing-key-rotation
/// gaps above) hit `status=WAITING result=null` at the OLD 15s bound for
/// `oidcc-client-test-session-management` on BOTH linux and windows, and that
/// module passed on an unrelated retry -- i.e. the suite was still working,
/// not stuck, when the old bound gave up on it.
/// `AbstractOIDCCClientTest.waitTimeoutSeconds` defaults to 5s in the suite's
/// own source -- the longest a module legitimately waits on purpose, for a
/// negative module expecting the RP to detect a problem and go silent -- so
/// 30s leaves a 6x margin for suite-side load/poll jitter, including the
/// extra round trip [requiresSecondLoginForKeyRotation] modules now make
/// through this same poll budget.
///
/// Each read is retried through [retryTransientConformancePollErrors]
/// ([_pollSummaryTolerant]) rather than letting a single transient failure
/// (network blip, suite-side 5xx) escape and fail the rest of the plan; a read
/// that still fails after that degrades to a non-terminal verdict map instead
/// of throwing, so a timeout (transient-poll-induced or genuine) still ends in
/// the SAME named per-module failure `_recordModuleVerdict` already produces,
/// rather than an uncaught exception with no module name attached.
Future<Map<String, dynamic>> pollConformanceModuleVerdict({
  required Dio dio,
  required String instanceId,
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(seconds: 1),
}) async {
  final stopwatch = Stopwatch()..start();
  var summary = await _pollSummaryTolerant(dio: dio, instanceId: instanceId);
  while (!isTerminalConformanceStatus(summary['status'] as String?) &&
      stopwatch.elapsed < timeout) {
    await Future<void>.delayed(interval);
    summary = await _pollSummaryTolerant(
      dio: dio,
      instanceId: instanceId,
      previous: summary,
    );
  }
  return summary;
}

/// The suite's own log for [instanceId].
///
/// `public: false` is the authenticated view. The public one omits the entries
/// that carry a failure reason, which is the only reason to fetch this at all.
Uri testLogUri({required String instanceId, int? since}) => Uri(
  path: 'api/log/$instanceId',
  queryParameters: {'public': 'false', if (since != null) 'since': '$since'},
);

/// Reads the suite's log for [instanceId] once.
///
/// [monitorTestLogs] polls the same endpoint but stops at `Setup Done`, so
/// everything the suite records DURING a module -- including why it refused a
/// request -- is fetched and thrown away. When a module ends with no user the
/// client can only report "no user"; this is the other half of that story.
///
/// Never throws: it runs on the failure path, where an exception would replace
/// the diagnosis with a second failure.
Future<List<Map<String, dynamic>>> fetchTestLogs({
  required Dio dio,
  required String instanceId,
}) async {
  try {
    final response = await dio.getUri<List<dynamic>>(
      testLogUri(instanceId: instanceId),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  } on Object {
    return const [];
  }
}

/// The block name `AbstractOIDCCClientTest.getAuthorizationEndpointBlockText`
/// opens for every authorization request the suite receives.
const _authorizationEndpointBlock = 'Authorization endpoint';

/// A one-line digest of a module's suite log ([fetchTestLogs]) for a
/// per-module FAILURE line, i.e. for the one channel every platform's job log
/// shows.
///
/// The iOS job prints no Dart `print`/`logging` output at all -- patrol only
/// forwards the failure the test throws -- so a module stuck at
/// `status=WAITING` there could not say whether the suite ever received its
/// authorization request (the client never reached the OP), or received it
/// and the client's later requests raced the suite's own negative-module
/// timer (`AbstractOIDCCClientTest.startWaitingForTimeout`, which finishes the
/// module only if the status is still WAITING the instant
/// `waitTimeoutSeconds` elapses after the authorization request). The two
/// need opposite fixes, and the suite's log tells them apart.
///
/// Lists every request block the suite opened (`startBlock` entries:
/// "Discovery endpoint", "Authorization endpoint", "Jwks endpoint", ...)
/// with its time relative to the FIRST authorization request -- both clocks
/// are the suite's, so there is no client/server skew in these offsets --
/// followed by the last [tailLength] entries verbatim (truncated).
///
/// [clientLoginStartedAtMs] (the client's epoch ms when it started the login,
/// if it did) adds when the first authorization request reached the suite
/// relative to that. That offset compares the suite's clock with the
/// client's (both NTP-synced, so expect about a second of skew). Good enough
/// to tell "arrived right away" from "arrived 25s in" from "arrived after the
/// client's flowTimeoutSeconds had already cancelled the browser".
String describeSuiteLogForFailure(
  List<Map<String, dynamic>> entries, {
  int tailLength = 3,
  int? clientLoginStartedAtMs,
}) {
  if (entries.isEmpty) {
    return 'suite log: empty or unreadable';
  }
  int? timeOf(Map<String, dynamic> entry) => (entry['time'] as num?)?.toInt();
  String clip(Object? value, int max) {
    final text = '$value'.replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= max ? text : '${text.substring(0, max)}...';
  }

  final blocks = entries.where((e) => e['startBlock'] == true).toList();
  final authorize = blocks
      .where((e) => '${e['msg']}'.startsWith(_authorizationEndpointBlock))
      .firstOrNull;
  final anchor = authorize == null ? null : timeOf(authorize);
  String offset(Map<String, dynamic> entry) {
    final time = timeOf(entry);
    if (anchor == null || time == null) {
      return '';
    }
    final seconds = (time - anchor) / 1000;
    return '@${seconds >= 0 ? '+' : ''}${seconds.toStringAsFixed(2)}s';
  }

  final requestBlocks = blocks
      .map((e) => '${clip(e['msg'], 60)}${offset(e)}')
      .join(', ');
  final tail = entries.length <= tailLength
      ? entries
      : entries.sublist(entries.length - tailLength);
  final tailText = tail
      .map(
        (e) =>
            '[${e['result'] ?? '-'}]${offset(e)} ${clip(e['msg'], 140)}'
            '${e['error'] == null ? '' : ' | error: ${clip(e['error'], 140)}'}',
      )
      .join(' / ');
  final crossClock = anchor == null || clientLoginStartedAtMs == null
      ? ''
      : 'first authorization request arrived '
            '${((anchor - clientLoginStartedAtMs) / 1000).toStringAsFixed(2)}s '
            'after the client started the login (suite vs client clock); ';
  return 'suite log (${entries.length} entries): '
      '${authorize == null ? 'NO authorization request received; ' : ''}'
      '$crossClock'
      'request blocks (relative to the first authorization request) '
      '[$requestBlocks]; last ${tail.length}: $tailText';
}

/// Whether [suiteLog] ([fetchTestLogs]) records that the suite received at
/// least one authorization request.
bool suiteLogShowsAuthorizationRequest(List<Map<String, dynamic>> suiteLog) =>
    suiteLog.any(
      (e) =>
          e['startBlock'] == true &&
          '${e['msg']}'.startsWith(_authorizationEndpointBlock),
    );

/// The most times a module is run on a fresh instance after its browser never
/// reached the suite. See [shouldRerunModuleOnFreshInstance].
const maxModuleReruns = 1;

/// Whether a module attempt should be discarded and the module run again on a
/// fresh suite instance.
///
/// This is for the iOS CI simulator, where the browser sometimes never
/// delivers the authorization request at all (#469). In run 37395358046 the
/// SafariViewService process hosting the session stopped responding and was
/// killed by the watchdog (`0x8badf00d`), and the session never recovered: no
/// timeout is long enough for a browser that is gone. Other runs had WebKit
/// WebContent launches taking 27-56s before the request left the simulator.
///
/// The rerun can never hide a verdict, because it requires ALL of:
///   * the client did not log in ([loggedIn] false);
///   * the suite's own log for the instance is readable and records NO
///     authorization request ([suiteLogShowsAuthorizationRequest]). The suite
///     observed nothing and so judged nothing. A module whose authorization
///     request did arrive, and whose response the client then rejected (every
///     negative module), is never rerun;
///   * this is not already a rerun ([attempt] counts from 1;
///     [maxModuleReruns] caps it).
/// An empty log means it could not be read, which proves nothing, so it does
/// not qualify either.
bool shouldRerunModuleOnFreshInstance({
  required bool loggedIn,
  required int attempt,
  required List<Map<String, dynamic>> suiteLog,
}) =>
    !loggedIn &&
    attempt <= maxModuleReruns &&
    suiteLog.isNotEmpty &&
    !suiteLogShowsAuthorizationRequest(suiteLog);

/// Whether suite log entry message [msg] confirms the OP's
/// `check_session_iframe` page completed one postMessage round trip with the
/// RP (`LogGetSessionStateRequest`, openid-certification/conformance-suite:
/// `src/main/java/net/openid/conformance/condition/as/logout/LogGetSessionStateRequest.java`).
///
/// This is the suite's OWN confirmation that `get_session_state` -- the ajax
/// call `check_session_iframe`'s page makes back to the suite the instant it
/// RECEIVES a postMessage (`AbstractOIDCCClientLogoutTest.handleGetSessionStateViaAjaxRequest`)
/// -- actually fired, which is exactly what flips
/// `receivedCheckSessionRequestBeforeLogout`/`...AfterLogout`
/// (see [requiresSessionManagementMonitoring]). The suite logs one of two
/// messages depending on whether a user happens to be logged in at that
/// instant; both still flip the boolean, so both are matched by this shared
/// prefix:
///   - "OP iframe received postMessage request from RP iframe"
///   - "OP iframe received postMessage request from RP iframe but the user
///     is not logged in"
///
/// A weaker "The client requested check_session_iframe" entry
/// (`LogCheckSessionIframeRequest`) only confirms the RP loaded the iframe,
/// not that a postMessage reached it, so it is deliberately NOT matched here.
bool isSessionCheckPostMessageLogEntry(String? msg) =>
    msg != null &&
    msg.startsWith('OP iframe received postMessage request from RP iframe');

/// Polls the suite's own log for [instanceId] ([fetchTestLogs]) until an
/// entry satisfies [matches] or [timeout] elapses, returning whether one was
/// found.
///
/// Used instead of a blind `Future.delayed` to learn when
/// `monitorSessionStatus`'s periodic `check_session_iframe` postMessage has
/// actually landed (oidcc-client-test-session-management,
/// [requiresSessionManagementMonitoring], oidc#467): the monitor runs on its
/// own schedule (iframe load, then `sessionManagementSettings.interval`), so
/// a guessed sleep either races it (too short, logging out before the suite
/// observed the PRE-logout check) or wastes the run's time budget on every
/// other module (too long). Polling the suite's own confirmation is exact
/// either way, and fails closed: if nothing ever matches, this still returns
/// after [timeout] rather than hanging, and the caller proceeds to logout
/// regardless so [pollConformanceModuleVerdict]'s verdict names the real
/// suite-reported failure rather than the harness hanging silently.
Future<bool> waitForSuiteLogEntry({
  required Dio dio,
  required String instanceId,
  required bool Function(Map<String, dynamic> entry) matches,
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(seconds: 1),
}) async {
  final stopwatch = Stopwatch()..start();
  while (true) {
    // A failed read counts as "not seen yet": the module's own verdict poll
    // still decides pass/fail, so a network blip must not abort the plan.
    List<Map<String, dynamic>> logs;
    try {
      logs = await retryTransientConformancePollErrors(
        () => fetchTestLogs(dio: dio, instanceId: instanceId),
      );
    } on Object {
      logs = const [];
    }
    if (logs.any(matches)) {
      return true;
    }
    if (stopwatch.elapsed >= timeout) {
      return false;
    }
    await Future<void>.delayed(interval);
  }
}

/// The `since` value for the next `api/log/{id}` read, and the entries of
/// [batch] not already in [seenIds] (which it updates).
///
/// The suite returns only entries with `time > since` (LogApi.getTestResults),
/// and several entries routinely share one millisecond. Asking from the last
/// seen time itself would drop any entry written later in that same
/// millisecond -- e.g. `Setup Done` -- forever, so the next read starts one
/// millisecond earlier and already-seen entries are filtered out by `_id`.
({int? since, List<Map<String, dynamic>> fresh}) takeUnseenLogEntries(
  List<Map<String, dynamic>> batch,
  Set<Object> seenIds, {
  int? since,
}) {
  final fresh = <Map<String, dynamic>>[];
  var next = since;
  for (final entry in batch) {
    if (entry['_id'] case final Object id when !seenIds.add(id)) {
      continue;
    }
    fresh.add(entry);
    if (entry['time'] case final int time) {
      final overlapping = time - 1;
      if (next == null || overlapping > next) {
        next = overlapping;
      }
    }
  }
  return (since: next, fresh: fresh);
}

Stream<List<Map<String, dynamic>>> monitorTestLogs({
  required Dio dio,
  required String instanceId,
  Duration interval = const Duration(seconds: 1),
}) {
  late StreamController<List<Map<String, dynamic>>> controller;
  Timer? timer;
  int? since;
  final seenIds = <Object>{};

  Future<void> fetchLogs() async {
    try {
      final uri = Uri(
        path: 'api/log/$instanceId',
        queryParameters: {
          'public': 'false',
          if (since != null) 'since': since.toString(),
        },
      );

      final response = await dio.getUri<List<dynamic>>(uri);
      final batch = takeUnseenLogEntries(
        (response.data ?? []).cast<Map<String, dynamic>>(),
        seenIds,
        since: since,
      );
      since = batch.since;
      if (batch.fresh.isNotEmpty && !controller.isClosed) {
        controller.add(batch.fresh);
      }
    } catch (error, st) {
      if (!controller.isClosed) {
        controller.addError(error, st);
      }
    }
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: () {
      fetchLogs();
      timer = Timer.periodic(interval, (_) => fetchLogs());
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
      controller.close();
    },
    onPause: () {
      timer?.cancel();
      timer = null;
    },
    onResume: () {
      timer = Timer.periodic(interval, (_) => fetchLogs());
    },
  );

  return controller.stream;
}
