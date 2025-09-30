// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;
import 'package:archive/archive.dart';
import 'conformance/api.dart';
import 'conformance/manager.dart';
import 'helpers.dart';

const String oidcConformanceToken = String.fromEnvironment(
  'OIDC_CONFORMANCE_TOKEN',
);
final Logger _testLogger = Logger('oidc.conformance');

bool _loggingConfigured = false;

void _ensureLoggingConfigured() {
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
    print(buffer.toString());
  });
  _loggingConfigured = true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  _ensureLoggingConfigured();
  _testLogger.info(
    'Starting integration test suite; token provided: ${oidcConformanceToken.isNotEmpty}',
  );
  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
        _testLogger.info('Running smoke test path (no OIDC token supplied).');
        print('Starting test: Simple manager initializes correctly');
        example.main();
        print('App main function executed');

        expect(app_state.currentManagerRx.$.didInit, false);
        print('Verified that manager is not initialized');

        print('Initializing manager...');
        await app_state.currentManagerRx.$.init();
        print('Manager initialization complete');

        print('Pumping and settling widgets...');
        await tester.pumpAndSettle();
        print('Widgets settled');

        expect(app_state.currentManagerRx.$.didInit, true);
        print('Verified that manager is initialized');
      });
    } else {
      testWidgets('OIDC Conformance Test', (tester) async {
        _testLogger.info('Running full OIDC conformance flow.');
        example.main();
        _testLogger.info(
          'Example app launched; waiting for first frame to settle.',
        );
        await tester.pumpAndSettle();
        _testLogger.info('Initial pumpAndSettle complete.');

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
        _testLogger.info('Dio client configured for conformance API.');

        _testLogger.info('Fetching server diagnostics (api/server)...');
        final serverInfo = await dio.get<Map<String, dynamic>>('api/server');
        _testLogger.info('Server info OK (status ${serverInfo.statusCode}).');
        expect(serverInfo.statusCode, 200);

        _testLogger.info('Fetching current user (api/currentuser)...');
        final currentUser = await dio.get<Map<String, dynamic>>(
          'api/currentuser',
        );
        _testLogger.info('Current user OK (status ${currentUser.statusCode}).');
        expect(currentUser.statusCode, 200);

        final platform = getPlatformName();
        _testLogger.info('Detected platform: $platform');

        const clientId = 'my_client';
        const clientSecret = 'my_client_secret';
        final redirectUri = getPlatformRedirectUri();
        _testLogger.fine('Client ID: $clientId, redirectUri: $redirectUri');

        final (path, body) = prepareTestPlanRequest(
          clientId: clientId,
          clientSecret: clientSecret,
          planName: 'oidcc-client-basic-certification-test-plan',
          description: 'package:oidc Conformance testing on $platform',
          redirectUri: redirectUri.toString(),
          requestType: 'plain_http_request',
          clientRegistration: 'static_client',
          postLogoutRedirectUri: redirectUri.toString(),
          frontChannelLogoutUri:
              'http://localhost:22433/redirect.html?requestType=front-channel-logout',
        );
        _testLogger.info('Submitting test plan request to $path...');

        final testPlanResponse = await dio.post<Map<String, dynamic>>(
          path,
          data: body,
        );
        _testLogger.info(
          'Test plan response status ${testPlanResponse.statusCode}.',
        );
        expect(testPlanResponse.data, isMap);

        final testPlanData = testPlanResponse.data as Map<String, dynamic>;
        final testPlanId = testPlanData['id'] as String;
        final testPlanModules = testPlanData['modules'] as List<dynamic>? ?? [];
        _testLogger.info(
          'Test plan created: id=$testPlanId, modules=${testPlanModules.length}.',
        );

        final archive = Archive();

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
          logger.info('Module starting. Variant: $variant');
          final logsToWrite = <String>[];
          final sub = Logger.root.onRecord.listen((record) {
            final message =
                '[${record.time} ${record.level.name}][${record.loggerName}]: ${record.message}';
            logsToWrite.add(message);
          });
          logger.info('Test instance created: $testInstance');
          final url = testInstance['url'] as String;
          logger.info('Test Instance ID: $testInstanceId, URL: $url');

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
          logger.info(
            'Setup completed after ${setupStopwatch.elapsed} (polls=$pollCount).',
          );

          logger.info(
            'Initializing manager for test instance: $testInstanceId',
          );
          await manager.init();
          expect(manager.didInit, true);
          logger.info('Manager initialized');
          if (moduleName == 'oidcc-client-test-discovery-openid-config') {
            app_state.currentManagerRx.$ = app_state.managersRx.$.first;
            app_state.managersRx.update(
              (managers) => managers..remove(manager),
            );
            await sub.cancel();
            continue;
          }
          try {
            logger.info('Starting login authorization code flow...');
            final authResult = await manager.loginAuthorizationCodeFlow();
            if (authResult == null) {
              logger.warning('Login failed, authResult is null');
            } else {
              logger.info('Login successful: ${authResult.token.toJson()}');
            }
          } catch (e, stackTrace) {
            logger.severe('Error during login flow', e, stackTrace);
          }

          logger.info('Cleaning up manager for test instance: $testInstanceId');
          await sub.cancel();
          app_state.currentManagerRx.$ = app_state.managersRx.$.first;
          app_state.managersRx.update((managers) => managers..remove(manager));
          if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
            final strToWrite = logsToWrite.join('\n');
            final data = utf8.encode(strToWrite);
            archive.addFile(ArchiveFile.bytes('$moduleName.log', data));
          }
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
      });
    }
  });
}
