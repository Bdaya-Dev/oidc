// ignore_for_file: avoid_print
//
// Harness-agnostic OIDC e2e logic, shared by both runners:
//   * `integration_test` (testWidgets) — used by the linux/windows CI jobs
//   * Patrol (patrolTest)               — used by android/iOS/macOS/web
//
// The ONLY coupling to the test harness is a `pumpAndSettle` callback, so the
// exact same conformance flow runs everywhere.

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
/// The logout profiles are NOT here: openid.net documents the four profiles
/// but not their plan ids, and guessing one costs an HTTP 400 per attempt.
/// `_logAvailableClientPlanIds` above asks the suite to list them instead;
/// read the ids out of a CI log and wire them from that.
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
  String clientRegistration = 'static_client',
  String? requestType = 'plain_http_request',
  String? clientAuthType,
}) async {
  _testLogger.info('Running OIDC conformance plan: $planName');
  await launchApp();
  _testLogger.info('Example app launched and settled.');

  const baseUrl = 'https://www.certification.openid.net/';
  _testLogger.fine('Conformance base URL: $baseUrl');

  final dio = Dio(
    BaseOptions(
      baseUrl: kIsWeb
          ? Uri.parse(
              'https://cors-proxy.bdaya-dev.workers.dev/corsproxy/',
            ).replace(queryParameters: {'apiurl': baseUrl}).toString()
          : baseUrl,
      headers: {
        'Authorization': 'Bearer $oidcConformanceToken',
        'Accept': 'application/json',
      },
    ),
  );
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

  const clientId = 'my_client';
  const clientSecret = 'my_client_secret';
  final redirectUri = getPlatformRedirectUri();
  _testLogger.fine('Client ID: $clientId, redirectUri: $redirectUri');

  final (path, body) = prepareTestPlanRequest(
    clientId: clientId,
    clientSecret: clientSecret,
    planName: planName,
    description: 'package:oidc $planName on $platform',
    redirectUri: redirectUri.toString(),
    requestType: requestType,
    clientRegistration: clientRegistration,
    extraVariant: {
      if (clientAuthType != null) 'client_auth_type': clientAuthType,
    },
    postLogoutRedirectUri: redirectUri.toString(),
    frontChannelLogoutUri:
        'http://localhost:22433/redirect.html?requestType=front-channel-logout',
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
      'If this names a variant dimension, the plan does not accept the '
      'variant this test sends; pass the right one via `clientRegistration` '
      'or `requestType`.',
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

  // The plan mixes positive modules with negative ones such as
  // oidcc-client-test-invalid-iss, where the OP returns a deliberately broken
  // response and a null result is the correct outcome. No single module can be
  // required to succeed, so the aggregate is asserted after the loop instead.
  var successfulLogins = 0;

  for (final testPlanModule
      in testPlanModules.whereType<Map<String, dynamic>>()) {
    final moduleName = testPlanModule['testModule'] as String;
    final variant =
        testPlanModule['variant'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    final testInstance = await createTestModuleInstance(
      dio: dio,
      planId: testPlanId,
      moduleName: moduleName,
      clientAuthType:
          variant['client_auth_type'] as String? ?? 'client_secret_basic',
      responseType: variant['response_type'] as String? ?? 'code',
      responseMode: variant['response_mode'] as String? ?? 'default',
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
      ..info('Test Instance ID: $testInstanceId, URL: $url');

    final manager = conformanceManager(
      url,
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUri: redirectUri,
      postLogoutRedirectUri: redirectUri,
      frontChannelLogoutUri: Uri(path: 'redirect.html'),
    );
    app_state.managersRx.update((managers) => managers..add(manager));
    app_state.currentManagerRx.$ = manager;

    logger.info(
      'Monitoring logs for test instance to wait for ready state: $testInstanceId',
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
    logger
      ..info(
        'Setup completed after ${setupStopwatch.elapsed} (polls=$pollCount).',
      )
      ..info('Initializing manager for test instance: $testInstanceId');
    await manager.init();
    expect(manager.didInit, true);
    logger.info('Manager initialized');
    if (moduleName == 'oidcc-client-test-discovery-openid-config') {
      app_state.currentManagerRx.$ = app_state.managersRx.$.first;
      app_state.managersRx.update((managers) => managers..remove(manager));
      await sub.cancel();
      continue;
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
    final authResult = await () async {
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
        return null;
      }
    }();
    if (authResult != null) {
      successfulLogins++;
    }
    // print(), not logger: logger output goes into the certification archive
    // rather than CI stdout. patrol also drops test stdout unless --verbose.
    print(
      '[e2e] $moduleName -> authResult ${authResult == null ? 'NULL' : 'ok'}',
    );
    logger
      ..info(
        authResult == null
            ? 'No user returned (expected for a negative module).'
            : 'Login successful: ${_describeToken(authResult.token)}',
      )
      ..info('Cleaning up manager for test instance: $testInstanceId');
    await sub.cancel();
    app_state.currentManagerRx.$ = app_state.managersRx.$.first;
    app_state.managersRx.update((managers) => managers..remove(manager));
    if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
      final strToWrite = logsToWrite.join('\n');
      final data = utf8.encode(strToWrite);
      archive.addFile(ArchiveFile.bytes('$moduleName.log', data));
    }
  }

  // Individual modules may legitimately end with no user, but a platform that
  // cannot capture the browser redirect at all scores zero here.
  print(
    '[e2e] successful logins: $successfulLogins / ${testPlanModules.length}',
  );
  expect(
    successfulLogins,
    greaterThan(0),
    reason:
        'no module of $planName completed a login on ${getPlatformName()}, so '
        'the browser redirect is not reaching the app. On Android, check that '
        "the OidcRedirectActivity intent-filter is registered for the app's "
        'redirect scheme.',
  );

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
