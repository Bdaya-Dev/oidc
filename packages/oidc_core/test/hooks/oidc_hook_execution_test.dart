import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Tests for OidcHook execution behavior
///
/// These tests define the expected behavior of the OidcHook.execute() method.
/// The tests verify that hooks properly transform requests and responses
/// according to their configured modification functions.
void main() {
  group('OidcHook Execution', () {
    test('should execute hook with modifyRequest correctly', () async {
      final hook = OidcHook<String, String>(
        modifyRequest: (request) async => '$request-modified',
      );

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      // The hook should modify the request before passing it to defaultExecution
      expect(result, equals('test-request-modified-executed'));
    });

    test('should execute hook with modifyResponse correctly', () async {
      final hook = OidcHook<String, String>(
        modifyResponse: (response) async => '$response-modified',
      );

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      // The hook should modify the response after defaultExecution
      expect(result, equals('test-request-executed-modified'));
    });

    test('should execute hook with modifyExecution correctly', () async {
      final hook = OidcHook<String, String>(
        modifyExecution: (request, defaultExecution) async {
          final result = await defaultExecution('$request-modified');
          return '$result-execution-modified';
        },
      );

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      // The hook should control the entire execution flow
      expect(
          result, equals('test-request-modified-executed-execution-modified'));
    });

    test('should execute hook with combined request and response modification',
        () async {
      final hook = OidcHook<String, String>(
        modifyRequest: (request) async => '$request-req-modified',
        modifyResponse: (response) async => '$response-resp-modified',
      );

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      // Both request and response modifications should be applied
      expect(
          result, equals('test-request-req-modified-executed-resp-modified'));
    });

    test('should handle null hook gracefully', () async {
      const OidcHook<String, String>? nullHook = null;

      final result = await nullHook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      // Null hook should just execute defaultExecution directly
      expect(result, equals('test-request-executed'));
    });

    group('Real-world usage scenarios', () {
      test('token hook should modify refresh token requests', () async {
        final tokenHook = OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
          modifyRequest: (request) async {
            // Remove scope for refresh token requests (common use case)
            if (request.request.grantType == 'refresh_token') {
              request.request.scope = null;
            }
            return request;
          },
        );

        final mockRequest = OidcTokenHookRequest(
          metadata: OidcProviderMetadata.fromJson({}),
          tokenEndpoint: Uri.parse('https://example.com/token'),
          request: OidcTokenRequest.refreshToken(
            refreshToken: 'mock-refresh-token',
            clientId: 'test-client',
            scope: ['openid', 'profile'], // Should be removed
          ),
          credentials:
              const OidcClientAuthentication.none(clientId: 'test-client'),
          headers: {},
          client: null,
          options: const OidcPlatformSpecificOptions(),
        );

        final result = await tokenHook.execute(
          request: mockRequest,
          defaultExecution: (request) async {
            // Verify that scope was removed
            expect(request.request.scope, isNull);
            return OidcTokenResponse.fromJson({'access_token': 'test-token'});
          },
        );

        expect(result.accessToken, equals('test-token'));
      });

      test('authorization hook should modify responses', () async {
        final authHook =
            OidcHook<OidcAuthorizationHookRequest, OidcAuthorizeResponse?>(
          modifyResponse: (response) async {
            // Example: add custom state to response
            if (response != null) {
              return OidcAuthorizeResponse.fromJson({
                ...response.src,
                'custom_field': 'added-by-hook',
              });
            }
            return response;
          },
        );

        final mockRequest = OidcAuthorizationHookRequest(
          metadata: OidcProviderMetadata.fromJson({}),
          request: OidcAuthorizeRequest(
            responseType: ['code'],
            clientId: 'test-client',
            redirectUri: Uri.parse('https://example.com/callback'),
            scope: ['openid'],
          ),
          options: const OidcPlatformSpecificOptions(),
          preparationResult: {},
        );

        final result = await authHook.execute(
          request: mockRequest,
          defaultExecution: (request) async => OidcAuthorizeResponse.fromJson({
            'code': 'test-code',
            'state': 'test-state',
          }),
        );

        expect(result?.code, equals('test-code'));
        expect(result?['custom_field'], equals('added-by-hook'));
      });

      test('execution hook should control entire token flow', () async {
        final tokenHook = OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
          modifyExecution: (request, defaultExecution) async {
            // Example: Add logging around token requests
            final startTime = DateTime.now();
            final response = await defaultExecution(request);
            final duration = DateTime.now().difference(startTime);

            // Add duration info to response
            return OidcTokenResponse.fromJson({
              ...response.src,
              'execution_duration_ms': duration.inMilliseconds,
            });
          },
        );

        final mockRequest = OidcTokenHookRequest(
          metadata: OidcProviderMetadata.fromJson({}),
          tokenEndpoint: Uri.parse('https://example.com/token'),
          request: OidcTokenRequest.authorizationCode(
            code: 'test-code',
            clientId: 'test-client',
          ),
          credentials:
              const OidcClientAuthentication.none(clientId: 'test-client'),
          headers: {},
          client: null,
          options: const OidcPlatformSpecificOptions(),
        );

        final result = await tokenHook.execute(
          request: mockRequest,
          defaultExecution: (request) async => OidcTokenResponse.fromJson({
            'access_token': 'test-token',
            'token_type': 'Bearer',
          }),
        );

        expect(result.accessToken, equals('test-token'));
        expect(result['execution_duration_ms'], isA<int>());
      });
    });
  });
}
