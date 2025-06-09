import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;

import 'conformance/api.dart';
import 'conformance/manager.dart';
import 'helpers.dart';

const String oidcConformanceToken =
    String.fromEnvironment('OIDC_CONFORMANCE_TOKEN');
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
        example.main();
        expect(app_state.currentManagerRx.$.didInit, false);
        await app_state.currentManagerRx.$.init();
        await tester.pumpAndSettle();

        expect(app_state.currentManagerRx.$.didInit, true);
      });
    } else {
      testWidgets('OIDC Conformance Test', (tester) async {
        print(
          'Running OIDC Conformance Test with token: $oidcConformanceToken',
        );
        // prepare the conformance manager
        example.main();
        await tester.pumpAndSettle();
        const baseUrl = 'https://www.certification.openid.net/';
        final dio = Dio(
          BaseOptions(
            // we use a CORS proxy for web testing
            // since the conformance server does not support CORS.
            baseUrl: kIsWeb
                ? Uri.parse(
                        'https://cors-proxy.bdaya-dev.workers.dev/corsproxy/')
                    .replace(
                    queryParameters: {
                      'apiurl': baseUrl,
                    },
                  ).toString()
                : baseUrl,
            headers: {
              'Authorization': 'Bearer $oidcConformanceToken',
              'Accept': 'application/json',
            },
          ),
        );
        final serverInfo = await dio.get<Map<String, dynamic>>('api/server');
        expect(serverInfo.statusCode, 200);
        final currentUser =
            await dio.get<Map<String, dynamic>>('api/currentuser');
        expect(currentUser.statusCode, 200);
        final platform = getPlatformName();

        const clientId = 'my_client';
        const clientSecret = 'my_client_secret';
        final redirectUri = getPlatformRedirectUri();
        // final timestamp = DateTime.timestamp().millisecondsSinceEpoch;
        // final alias = 'package_oidc_${platform}_$timestamp';
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
          // alias: alias,
        );
        //https://www.certification.openid.net/test/a/alias/

        final testPlanResponse =
            await dio.post<Map<String, dynamic>>(path, data: body);
        expect(testPlanResponse.data, isMap);
        final testPlanData = testPlanResponse.data as Map<String, dynamic>;
        expect(testPlanData['id'], isNotNull);
        final testPlanId = testPlanData['id'] as String;
        final testPlanName = testPlanData['name'] as String;
        final testPlanModules = testPlanData['modules'] as List<dynamic>? ?? [];
        print('Test Plan ID: $testPlanId');
        print('Test Plan Name: $testPlanName');
        for (final testPlanModule in testPlanModules) {
          //
          final moduleName = testPlanModule['testModule'] as String?;
          expect(moduleName, isNotNull);
          final variant = testPlanModule['variant'] as Map<String, dynamic>? ??
              <String, dynamic>{};
          final clientAuthType = variant['client_auth_type'] as String?;
          final responseType = variant['response_type'] as String?;
          final responseMode = variant['response_mode'] as String?;
          print(
            'Test Plan Module: $moduleName, '
            'Client Auth Type: $clientAuthType, '
            'Response Type: $responseType, '
            'Response Mode: $responseMode',
          );
        }

        for (final testPlanModule
            in testPlanModules.whereType<Map<String, dynamic>>()) {
          final variant = testPlanModule['variant'] as Map<String, dynamic>? ??
              <String, dynamic>{};
          final moduleName = testPlanModule['testModule'] as String;
          // if (moduleName != 'oidcc-client-test') {
          //   continue;
          // }
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
          final url = testInstance['url'] as String;
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
          // final receivedLogs = <Map<String, dynamic>>[];
          monitorLogsLoop:
          await for (final logs
              in monitorTestLogs(dio: dio, instanceId: testInstanceId)) {
            // receivedLogs.addAll(logs);
            for (final log in logs) {
              if (log['msg'] == 'Setup Done') {
                print('Test instance setup done: $testInstanceId');
                break monitorLogsLoop;
              }
            }
          }

          // now we can run the test.
          // Init the manager to fetch the discovery document and other settings.
          await manager.init();
          expect(manager.didInit, true);
          try {
            final authResult = await manager.loginAuthorizationCodeFlow();
            if (authResult == null) {
              print('Login failed, authResult is null');
            } else {
              print('Login successful: ${authResult.token.toJson()}');
            }
            // expect(authResult, isNotNull);
          } catch (e) {
            print('Error during login: $e');
          }
          //cleanup
          app_state.currentManagerRx.$ = app_state.managersRx.$.first;
          app_state.managersRx.update((managers) => managers..remove(manager));
        }
        // Assign the conformance manager to the app state
        // for each module we run an auth process.
      });
    }
  });
}
