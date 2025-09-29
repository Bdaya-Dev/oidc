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
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
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
        print('Starting OIDC Conformance Test');
        print('Token: $oidcConformanceToken');

        print('Executing app main function...');
        example.main();
        print('App main function executed');

        print('Pumping and settling widgets...');
        await tester.pumpAndSettle();
        print('Widgets settled');

        const baseUrl = 'https://www.certification.openid.net/';
        print('Base URL: $baseUrl');

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
        print('Dio client initialized');

        print('Fetching server info...');
        final serverInfo = await dio.get<Map<String, dynamic>>('api/server');
        print('Server info fetched: ${serverInfo.data}');
        expect(serverInfo.statusCode, 200);

        print('Fetching current user info...');
        final currentUser = await dio.get<Map<String, dynamic>>(
          'api/currentuser',
        );
        print('Current user info fetched: ${currentUser.data}');
        expect(currentUser.statusCode, 200);

        final platform = getPlatformName();
        print('Platform: $platform');

        const clientId = 'my_client';
        const clientSecret = 'my_client_secret';
        final redirectUri = getPlatformRedirectUri();
        print(
          'Client ID: $clientId, Client Secret: $clientSecret, Redirect URI: $redirectUri',
        );

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
        print('Test plan request prepared: Path: $path, Body: $body');

        print('Submitting test plan request...');
        final testPlanResponse = await dio.post<Map<String, dynamic>>(
          path,
          data: body,
        );
        print('Test plan response: ${testPlanResponse.data}');
        expect(testPlanResponse.data, isMap);

        final testPlanData = testPlanResponse.data as Map<String, dynamic>;
        final testPlanId = testPlanData['id'] as String;
        final testPlanName = testPlanData['name'] as String;
        final testPlanModules = testPlanData['modules'] as List<dynamic>? ?? [];
        print(
          'Test Plan ID: $testPlanId, Name: $testPlanName, Modules: $testPlanModules',
        );

        for (final testPlanModule in testPlanModules) {
          final moduleName = testPlanModule['testModule'] as String?;
          expect(moduleName, isNotNull);
          print('Processing Test Plan Module: $moduleName');

          final variant =
              testPlanModule['variant'] as Map<String, dynamic>? ??
              <String, dynamic>{};
          final clientAuthType = variant['client_auth_type'] as String?;
          final responseType = variant['response_type'] as String?;
          final responseMode = variant['response_mode'] as String?;
          print(
            'Module: $moduleName, Client Auth Type: $clientAuthType, Response Type: $responseType, Response Mode: $responseMode',
          );
        }
        final archive = Archive();

        for (final testPlanModule
            in testPlanModules.whereType<Map<String, dynamic>>()) {
          final moduleName = testPlanModule['testModule'] as String;

          print('Creating test instance for module: $moduleName');

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
          // final logFileName = 'client-logs/$moduleName.log';
          final logsToWrite = <String>[];
          final sub = Logger.root.onRecord.listen((record) {
            final message =
                '[${record.time} ${record.level.name}][${record.loggerName}]: ${record.message}';
            logsToWrite.add(message);
            print(message);
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
          monitorLogsLoop:
          await for (final logs in monitorTestLogs(
            dio: dio,
            instanceId: testInstanceId,
          )) {
            for (final log in logs) {
              logger.fine('Log: $log');
              if (log['msg'] == 'Setup Done') {
                logger.info('Test instance setup done: $testInstanceId');
                break monitorLogsLoop;
              }
            }
          }

          logger.info(
            'Initializing manager for test instance: $testInstanceId',
          );
          await manager.init();
          expect(manager.didInit, true);
          logger.info('Manager initialized');
          if (moduleName == 'oidcc-client-test-discovery-openid-config') {
            // that's it, do nothing else.
            app_state.currentManagerRx.$ = app_state.managersRx.$.first;
            app_state.managersRx.update(
              (managers) => managers..remove(manager),
            );
            continue;
          }
          try {
            logger.info('Starting login authorization code flow...');
            final authResult = await manager.loginAuthorizationCodeFlow();
            if (authResult == null) {
              logger.info('Login failed, authResult is null');
            } else {
              logger.info('Login successful: ${authResult.token.toJson()}');
            }
          } catch (e) {
            logger.info('Error during login: $e');
          }

          logger.info('Cleaning up manager for test instance: $testInstanceId');
          await sub.cancel();
          app_state.currentManagerRx.$ = app_state.managersRx.$.first;
          app_state.managersRx.update((managers) => managers..remove(manager));
          if (!kIsWeb && Platform.isLinux && !Platform.isAndroid) {
            final strToWrite = logsToWrite.join('\n');
            final data = utf8.encode(strToWrite);
            // var logFile = File(logFileName).absolute;
            // logFile = await logFile.create(recursive: true);
            // logFile = await logFile.writeAsString(logsToWrite.join('\n'));
            archive.addFile(ArchiveFile.bytes('$moduleName.log', data));
            // print('Log file added: ${logFile.path}');
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
          } catch (e) {
            print('failed to zip test logs: $e');
          }
        }
        print('OIDC Conformance Test completed');
      });
    }
  });
}
