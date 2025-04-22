import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_core/oidc_core.dart' as oidc_core;
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    testWidgets('authorization code flow login works', (tester) async {
      app_state.currentManager = app_state.hydraManager;
      final ogClient = http.Client();
      app_state.currentManager.httpClient = http.MockClient(
        (baseRequest) async {
          final request = http.Request(baseRequest.method, baseRequest.url)
            ..persistentConnection = baseRequest.persistentConnection
            ..followRedirects = baseRequest.followRedirects
            ..maxRedirects = baseRequest.maxRedirects
            ..headers.addAll(baseRequest.headers)
            ..bodyBytes = baseRequest.bodyBytes;
          final originalResponse = await ogClient.send(request);
          print('host: ${request.url.host}');
          if (request.url.host == '10.0.2.2' &&
              request.url.path == '/.well-known/openid-configuration') {
            // parse the originalResponse
            final body = await originalResponse.stream.bytesToString();
            var parsed = oidc_core.OidcProviderMetadata.fromJson(
              jsonDecode(body) as Map<String, dynamic>,
            );
            final issuer = Uri.parse('http://10.0.2.2:4444');
            parsed = parsed.copyWith(
              issuer: issuer,
              authorizationEndpoint: parsed.authorizationEndpoint?.replace(
                host: issuer.host,
              ),
              tokenEndpoint: parsed.tokenEndpoint?.replace(
                host: issuer.host,
              ),
              jwksUri: parsed.jwksUri?.replace(
                host: issuer.host,
              ),
              userinfoEndpoint: parsed.userinfoEndpoint?.replace(
                host: issuer.host,
              ),
              endSessionEndpoint: parsed.endSessionEndpoint?.replace(
                host: issuer.host,
              ),
              revocationEndpoint: parsed.revocationEndpoint?.replace(
                host: issuer.host,
              ),
            );
            return http.Response(
              jsonEncode(parsed.toJson()),
              originalResponse.statusCode,
              headers: originalResponse.headers,
            );
          }
          return http.Response.fromStream(originalResponse);
        },
      );
      example.main();
      await app_state.initApp();

      await tester.pumpAndSettle();
      final user = await app_state.currentManager.loginAuthorizationCodeFlow();
      expect(user, isNotNull);
      expect(user!.token.accessToken, isNotEmpty);
    });

    // testWidgets(
    //   'login works',
    //   (tester) async {
    //     example.main();
    //     await tester.pumpAndSettle();
    //     // final loginFuture =
    //     //     app_state.currentManager.loginAuthorizationCodeFlow();
    //     // print('waiting for login future...');

    //     // await loginFuture;
    //   },
    // );
  });
}
