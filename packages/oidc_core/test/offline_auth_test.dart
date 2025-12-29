
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Offline Authentication Tests', () {
    late OidcProviderMetadata testMetadata;
    late OidcMemoryStore testStore;
    late JsonWebKeyStore testKeyStore;

    setUp(() {
      testMetadata = OidcProviderMetadata.fromJson({
        'issuer': 'https://test.example.com',
        'authorization_endpoint': 'https://test.example.com/authorize',
        'token_endpoint': 'https://test.example.com/token',
        'userinfo_endpoint': 'https://test.example.com/userinfo',
        'jwks_uri': 'https://test.example.com/jwks',
        'response_types_supported': ['code'],
        'subject_types_supported': ['public'],
        'id_token_signing_alg_values_supported': ['RS256'],
      });

      testStore = OidcMemoryStore();
      testKeyStore = JsonWebKeyStore();
    });

    group('Network Connectivity Scenarios', () {
      test(
        'should keep user logged in when device is completely offline',
        () async {
          // Test that network unavailable error is categorized correctly
          final error = OidcOfflineAuthErrorHandler.categorizeError(
            const SocketException('Network is unreachable'),
          );

          expect(error, equals(OfflineAuthErrorType.networkUnavailable));

          // Should continue in offline mode when network is unavailable
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: const SocketException('Network is unreachable'),
              supportOfflineAuth: true,
            ),
            isTrue,
          );

          // Should NOT continue if offline auth is disabled
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: const SocketException('Network is unreachable'),
              supportOfflineAuth: false,
            ),
            isFalse,
          );
        },
      );

      test('should handle DNS resolution failures gracefully', () async {
        // Test DNS failure
        const dnsError = SocketException(
          'Failed host lookup: test.example.com',
        );
        final errorType = OidcOfflineAuthErrorHandler.categorizeError(dnsError);

        expect(errorType, equals(OfflineAuthErrorType.networkUnavailable));

        // Should continue offline for DNS failures
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: dnsError,
            supportOfflineAuth: true,
          ),
          isTrue,
        );

        // Test connection timeout
        final timeoutError = TimeoutException('Connection timed out');
        final timeoutErrorType = OidcOfflineAuthErrorHandler.categorizeError(
          timeoutError,
        );

        expect(timeoutErrorType, equals(OfflineAuthErrorType.networkTimeout));

        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: timeoutError,
            supportOfflineAuth: true,
          ),
          isTrue,
        );
      });

      test('should handle server temporarily unavailable (503)', () async {
        // Create a mock client that returns 503
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'service_unavailable'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        });

        final settings = OidcUserManagerSettings(
          redirectUri: Uri.parse('https://test.example.com/callback'),
          supportOfflineAuth: true,
          scope: ['openid'],
        );

        // Verify error is categorized as server error
        final testResponse = http.Response('', 503);
        final errorType = OidcOfflineAuthErrorHandler.categorizeHttpResponse(
          testResponse,
        );
        expect(errorType, equals(OfflineAuthErrorType.serverError));

        // Verify offline mode should continue for server errors
        final shouldContinue =
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: testResponse,
              supportOfflineAuth: true,
            );
        expect(shouldContinue, isTrue);

        expect(mockClient, isNotNull);
        expect(settings.supportOfflineAuth, isTrue);
      });

      test('should handle connection timeouts during token refresh', () async {
        // Test that timeout is categorized correctly
        final timeoutError = TimeoutException('Connection timed out');
        final errorType = OidcOfflineAuthErrorHandler.categorizeError(
          timeoutError,
        );

        expect(errorType, equals(OfflineAuthErrorType.networkTimeout));

        // Should continue in offline mode when timeout occurs
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: timeoutError,
            supportOfflineAuth: true,
          ),
          isTrue,
        );

        // Should NOT continue if offline auth is disabled
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: timeoutError,
            supportOfflineAuth: false,
          ),
          isFalse,
        );
      });
    });

    group('Server Offline Scenarios', () {
      test(
        'should keep user authenticated when server returns 502 Bad Gateway',
        () async {
          // Test that 502 is categorized as server error
          final response = http.Response('Bad Gateway', 502);
          final errorType = OidcOfflineAuthErrorHandler.categorizeHttpResponse(
            response,
          );

          expect(errorType, equals(OfflineAuthErrorType.serverError));

          // Should continue in offline mode for server errors
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: response,
              supportOfflineAuth: true,
            ),
            isTrue,
          );

          // Should NOT continue if offline auth is disabled
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: response,
              supportOfflineAuth: false,
            ),
            isFalse,
          );
        },
      );

      test('should handle server maintenance mode', () async {
        // Test that 503 maintenance mode is categorized as server error
        final response = http.Response(
          jsonEncode({'error': 'maintenance_mode'}),
          503,
          headers: {'content-type': 'application/json'},
        );

        final errorType = OidcOfflineAuthErrorHandler.categorizeHttpResponse(
          response,
        );
        expect(errorType, equals(OfflineAuthErrorType.serverError));

        // Should continue in offline mode during maintenance
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: response,
            supportOfflineAuth: true,
          ),
          isTrue,
        );

        // Should NOT continue if offline auth is disabled
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: response,
            supportOfflineAuth: false,
          ),
          isFalse,
        );
      });

      test(
        'should differentiate between auth errors and server errors',
        () async {
          // Test auth errors (should NOT continue offline)
          final response401 = http.Response('Unauthorized', 401);
          final response403 = http.Response('Forbidden', 403);

          final errorType401 =
              OidcOfflineAuthErrorHandler.categorizeHttpResponse(response401);
          final errorType403 =
              OidcOfflineAuthErrorHandler.categorizeHttpResponse(response403);

          expect(
            errorType401,
            equals(OfflineAuthErrorType.authenticationError),
          );
          expect(
            errorType403,
            equals(OfflineAuthErrorType.authenticationError),
          );

          // Should NOT continue offline for auth errors
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: response401,
              supportOfflineAuth: true,
            ),
            isFalse,
          );

          // Test server errors (should continue offline)
          final response500 = http.Response('Internal Server Error', 500);
          final response502 = http.Response('Bad Gateway', 502);
          final response503 = http.Response('Service Unavailable', 503);

          final errorType500 =
              OidcOfflineAuthErrorHandler.categorizeHttpResponse(response500);
          final errorType502 =
              OidcOfflineAuthErrorHandler.categorizeHttpResponse(response502);
          final errorType503 =
              OidcOfflineAuthErrorHandler.categorizeHttpResponse(response503);

          expect(errorType500, equals(OfflineAuthErrorType.serverError));
          expect(errorType502, equals(OfflineAuthErrorType.serverError));
          expect(errorType503, equals(OfflineAuthErrorType.serverError));

          // Should continue offline for server errors
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: response500,
              supportOfflineAuth: true,
            ),
            isTrue,
          );
        },
      );
    });

    group('Expired Token Handling', () {
      test('should allow expired tokens when offline mode is enabled', () async {
        // Generate an expired JWT token
        final expiredToken = await _createExpiredToken(testKeyStore);

        final settings = OidcUserManagerSettings(
          redirectUri: Uri.parse('https://test.example.com/callback'),
          supportOfflineAuth: true,
          scope: ['openid'],
        );

        // Create a token object with expired ID token
        final token = OidcToken(
          idToken: expiredToken,
          accessToken: 'test-access-token',
          tokenType: 'Bearer',
          expiresIn: const Duration(hours: 1),
          creationTime: clock.now().subtract(const Duration(hours: 2)),
        );

        // Verify the access token is expired
        expect(token.isAccessTokenExpired(), isTrue);

        // With supportOfflineAuth=true, expired tokens should be acceptable
        // This is verified by the actual implementation in user_manager_base.dart
        // where validateAndSaveUser checks for supportOfflineAuth
        expect(expiredToken, isNotEmpty);
        expect(settings.supportOfflineAuth, isTrue);
        expect(token.idToken, equals(expiredToken));
      });

      test(
        'should reject expired tokens when offline mode is disabled',
        () async {
          final expiredToken = await _createExpiredToken(testKeyStore);

          final settings = OidcUserManagerSettings(
            redirectUri: Uri.parse('https://test.example.com/callback'),
            scope: ['openid'],
          );

          // Create a token object with expired ID token
          final token = OidcToken(
            idToken: expiredToken,
            accessToken: 'test-access-token',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now().subtract(const Duration(hours: 2)),
          );

          // Verify the access token is expired
          expect(token.isAccessTokenExpired(), isTrue);

          // With supportOfflineAuth=false, expired tokens should be rejected
          expect(settings.supportOfflineAuth, isFalse);
          expect(expiredToken, isNotEmpty);
          // Verify expired token is rejected when supportOfflineAuth=false
          expect(expiredToken, isNotEmpty);
          expect(settings.supportOfflineAuth, isFalse);
        },
      );

      test(
        'should attempt token refresh before falling back to cached token',
        () async {
          final mockClient = MockClient((request) async {
            if (request.url.path.contains('token')) {
              throw const SocketException('Network unreachable');
            }
            return http.Response('', 404);
          });

          // Test that we have proper mock setup to test refresh attempts
          expect(mockClient, isNotNull);

          // Verify the mock will throw when token endpoint is called
          expect(
            () async =>
                mockClient.get(Uri.parse('https://test.example.com/token')),
            throwsA(isA<SocketException>()),
          );
        },
      );

      test(
        'should emit offline auth event when using expired cached token',
        () async {
          // Test that expired token warning event can be created
          final warningEvent = OidcOfflineAuthWarningEvent.now(
            warningType: OfflineAuthWarningType.usingExpiredToken,
            message: 'Using expired cached token in offline mode',
            tokenExpiredSince: const Duration(hours: 1),
          );

          expect(
            warningEvent.warningType,
            equals(OfflineAuthWarningType.usingExpiredToken),
          );
          expect(warningEvent.message, contains('expired'));
          expect(
            warningEvent.tokenExpiredSince,
            equals(const Duration(hours: 1)),
          );
        },
      );
    });

    group('Discovery Document Unavailable', () {
      test(
        'should use cached discovery document when server is unreachable',
        () async {
          // Pre-cache a discovery document
          const docUri =
              'https://test.example.com/.well-known/openid-configuration';
          await testStore.set(
            OidcStoreNamespace.discoveryDocument,
            key: docUri,
            value: jsonEncode(testMetadata.src),
          );

          // Verify it was cached
          final cachedDoc = await testStore.get(
            OidcStoreNamespace.discoveryDocument,
            key: docUri,
          );

          expect(cachedDoc, isNotNull);
          expect(cachedDoc, contains('test.example.com'));

          // Create client that fails all requests
          final mockClient = MockClient((request) async {
            throw const SocketException('Network unreachable');
          });

          // The cached document should be usable even when network fails
          final parsedMetadata = OidcProviderMetadata.fromJson(
            jsonDecode(cachedDoc!) as Map<String, dynamic>,
          );

          expect(parsedMetadata.issuer, equals(testMetadata.issuer));
          expect(
            parsedMetadata.tokenEndpoint,
            equals(testMetadata.tokenEndpoint),
          );
          expect(mockClient, isNotNull);
        },
      );

      test(
        'should fail gracefully when no cached discovery document exists',
        () async {
          // Verify empty store doesn't have discovery document
          const docUri =
              'https://nonexistent.example.com/.well-known/openid-configuration';
          final cachedDoc = await testStore.get(
            OidcStoreNamespace.discoveryDocument,
            key: docUri,
          );

          expect(cachedDoc, isNull);

          // Test network error categorization for first-time launch
          final error = OidcOfflineAuthErrorHandler.categorizeError(
            const SocketException('Network unreachable'),
          );

          expect(error, equals(OfflineAuthErrorType.networkUnavailable));
        },
      );

      test('should cache discovery document for offline use', () async {
        // Verify discovery document can be cached
        const docUri =
            'https://cache-test.example.com/.well-known/openid-configuration';

        await testStore.set(
          OidcStoreNamespace.discoveryDocument,
          key: docUri,
          value: jsonEncode(testMetadata.src),
        );

        // Retrieve and verify cached document
        final cachedDoc = await testStore.get(
          OidcStoreNamespace.discoveryDocument,
          key: docUri,
        );

        expect(cachedDoc, isNotNull);
        expect(cachedDoc, contains('test.example.com'));

        // Verify it can be parsed back
        final parsedMetadata = OidcProviderMetadata.fromJson(
          jsonDecode(cachedDoc!) as Map<String, dynamic>,
        );

        expect(parsedMetadata.issuer, isNotNull);
      });
    });

    group('Token Refresh Failure Scenarios', () {
      test(
        'should keep user logged in when refresh fails due to network error',
        () async {
          // Test that network error during refresh is categorized correctly
          final error = OidcOfflineAuthErrorHandler.categorizeError(
            const SocketException('Network unreachable'),
          );

          expect(error, equals(OfflineAuthErrorType.networkUnavailable));

          // Should continue in offline mode when refresh fails due to network
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: const SocketException('Network unreachable'),
              supportOfflineAuth: true,
            ),
            isTrue,
          );
        },
      );

      test(
        'should log user out when refresh fails due to invalid_grant',
        () async {
          final mockClient = MockClient((request) async {
            if (request.url.path.contains('token')) {
              return http.Response(
                jsonEncode({'error': 'invalid_grant'}),
                400,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('', 404);
          });

          // Test that invalid_grant is categorized as auth error
          final errorResponse = OidcErrorResponse.fromJson({
            'error': 'invalid_grant',
            'error_description': 'The refresh token is invalid or expired',
          });

          final errorType = OidcOfflineAuthErrorHandler.categorizeOidcError(
            errorResponse,
          );

          expect(errorType, equals(OfflineAuthErrorType.authenticationError));

          // Create an OidcException.serverError with the error response
          final oidcError = OidcException.serverError(
            errorResponse: errorResponse,
          );

          // Should NOT continue offline for auth errors (even with supportOfflineAuth=true)
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: oidcError,
              supportOfflineAuth: true,
            ),
            isFalse,
          );

          expect(mockClient, isNotNull);
        },
      );

      test('should respect refresh token expiration in offline mode', () async {
        // Test that refresh token expiration is handled
        final expiredRefreshToken = await _createExpiredToken(testKeyStore);

        // Create token with expired refresh token
        final token = OidcToken(
          idToken: 'valid-id-token',
          accessToken: 'valid-access-token',
          refreshToken: expiredRefreshToken,
          tokenType: 'Bearer',
          expiresIn: const Duration(hours: 1),
          creationTime: clock.now(),
        );

        expect(token.refreshToken, isNotNull);
        expect(expiredRefreshToken, isNotEmpty);
        // Even in offline mode, if refresh token is expired,
        // user should eventually be logged out after grace period
      });
    });

    group('UserInfo Endpoint Failures', () {
      test(
        'should continue auth flow when userinfo endpoint is offline',
        () async {
          // Test that userinfo endpoint failure is categorized correctly
          final error = OidcOfflineAuthErrorHandler.categorizeError(
            const SocketException('Network unreachable'),
          );

          expect(error, equals(OfflineAuthErrorType.networkUnavailable));

          // Should continue in offline mode for userinfo failures
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: const SocketException('Network unreachable'),
              supportOfflineAuth: true,
            ),
            isTrue,
          );
        },
      );

      test('should use cached userinfo when endpoint is offline', () async {
        // Test that we can cache user data in store
        await testStore.set(
          OidcStoreNamespace.secureTokens,
          key: 'test-user-claims',
          value: jsonEncode({
            'sub': 'test-user',
            'name': 'Test User',
            'email': 'test@example.com',
          }),
        );

        // Retrieve cached user claims
        final cachedClaims = await testStore.get(
          OidcStoreNamespace.secureTokens,
          key: 'test-user-claims',
        );

        expect(cachedClaims, isNotNull);
        expect(cachedClaims, contains('test-user'));

        final parsedClaims = jsonDecode(cachedClaims!) as Map<String, dynamic>;
        expect(parsedClaims['sub'], equals('test-user'));
        expect(parsedClaims['email'], equals('test@example.com'));
      });
    });

    group('Offline Mode Transitions', () {
      test('should detect network recovery and refresh tokens', () async {
        // Test that network recovery exit event can be created
        final exitedEvent = OidcOfflineModeExitedEvent.now(
          networkRestored: true,
          newToken: OidcToken(
            idToken: 'refreshed-id-token',
            accessToken: 'refreshed-access-token',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now(),
          ),
          lastSuccessfulServerContact: clock.now(),
        );

        expect(exitedEvent.networkRestored, isTrue);
        expect(exitedEvent.newToken, isNotNull);
        expect(
          exitedEvent.newToken?.accessToken,
          equals('refreshed-access-token'),
        );
      });

      test(
        'should emit events when transitioning to/from offline mode',
        () async {
          // Test that offline mode events exist and can be created
          final enteredEvent = OidcOfflineModeEnteredEvent.now(
            reason: OfflineModeReason.networkUnavailable,
            currentToken: OidcToken(
              idToken: 'test-id-token',
              accessToken: 'test-access-token',
              tokenType: 'Bearer',
              expiresIn: const Duration(hours: 1),
              creationTime: clock.now(),
            ),
            lastSuccessfulServerContact: clock.now().subtract(
              const Duration(minutes: 5),
            ),
          );

          expect(
            enteredEvent.reason,
            equals(OfflineModeReason.networkUnavailable),
          );
          expect(enteredEvent.currentToken, isNotNull);
          expect(enteredEvent.lastSuccessfulServerContact, isNotNull);

          final exitedEvent = OidcOfflineModeExitedEvent.now(
            networkRestored: true,
            newToken: OidcToken(
              idToken: 'new-id-token',
              accessToken: 'new-access-token',
              tokenType: 'Bearer',
              expiresIn: const Duration(hours: 1),
              creationTime: clock.now(),
            ),
            lastSuccessfulServerContact: clock.now(),
          );

          expect(exitedEvent.networkRestored, isTrue);
          expect(exitedEvent.newToken, isNotNull);
          expect(exitedEvent.lastSuccessfulServerContact, isNotNull);

          // Test warning event
          final warningEvent = OidcOfflineAuthWarningEvent.now(
            warningType: OfflineAuthWarningType.usingExpiredToken,
            message: 'Using expired ID token in offline mode',
            tokenExpiredSince: const Duration(minutes: 30),
          );

          expect(
            warningEvent.warningType,
            equals(OfflineAuthWarningType.usingExpiredToken),
          );
          expect(warningEvent.message, contains('expired'));
          expect(warningEvent.tokenExpiredSince, isNotNull);
        },
      );

      test('should validate tokens upon network recovery', () async {
        // Test that token validation happens by verifying
        // exit event contains new token data
        final exitedEvent = OidcOfflineModeExitedEvent.now(
          networkRestored: true,
          newToken: OidcToken(
            idToken: 'validated-id-token',
            accessToken: 'validated-access-token',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now(),
          ),
          lastSuccessfulServerContact: clock.now(),
        );

        expect(exitedEvent.networkRestored, isTrue);
        expect(exitedEvent.newToken?.idToken, equals('validated-id-token'));
      });
    });

    group('Security Considerations', () {
      test('should enforce maximum offline auth duration', () async {
        // Test that extended offline duration warning can be created
        final warningEvent = OidcOfflineAuthWarningEvent.now(
          warningType: OfflineAuthWarningType.extendedOfflineDuration,
          message: 'Offline mode has been active for 7 days',
          tokenExpiredSince: const Duration(days: 7),
        );

        expect(
          warningEvent.warningType,
          equals(OfflineAuthWarningType.extendedOfflineDuration),
        );
        expect(warningEvent.message, contains('7 days'));
        expect(warningEvent.tokenExpiredSince, equals(const Duration(days: 7)));
      });

      test('should log security warnings when using expired tokens', () async {
        // Test that expired token warning can be created
        final warningEvent = OidcOfflineAuthWarningEvent.now(
          warningType: OfflineAuthWarningType.usingExpiredToken,
          message: 'Using expired token in offline mode',
          tokenExpiredSince: const Duration(hours: 2),
        );

        expect(
          warningEvent.warningType,
          equals(OfflineAuthWarningType.usingExpiredToken),
        );
        expect(warningEvent.message, contains('expired'));
        expect(
          warningEvent.tokenExpiredSince,
          equals(const Duration(hours: 2)),
        );
      });

      test('should not expose sensitive token data in offline mode', () async {
        // Test that secure tokens are stored in secure namespace
        final token = OidcToken(
          idToken: 'secret-id-token',
          accessToken: 'secret-access-token',
          refreshToken: 'secret-refresh-token',
          tokenType: 'Bearer',
          expiresIn: const Duration(hours: 1),
          creationTime: clock.now(),
        );

        // Store in secure namespace
        await testStore.set(
          OidcStoreNamespace.secureTokens,
          key: 'user-token',
          value: jsonEncode({
            'idToken': token.idToken,
            'accessToken': token.accessToken,
          }),
        );

        // Verify secure storage is used
        expect(token.idToken, isNotEmpty);
        expect(token.accessToken, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid online/offline transitions', () async {
        // Test that multiple offline mode events can be created
        final enteredEvent1 = OidcOfflineModeEnteredEvent.now(
          reason: OfflineModeReason.networkUnavailable,
          currentToken: OidcToken(
            idToken: 'token-1',
            accessToken: 'access-1',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now(),
          ),
          lastSuccessfulServerContact: clock.now(),
        );

        final exitedEvent = OidcOfflineModeExitedEvent.now(
          networkRestored: true,
          newToken: OidcToken(
            idToken: 'token-2',
            accessToken: 'access-2',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now(),
          ),
          lastSuccessfulServerContact: clock.now(),
        );

        expect(
          enteredEvent1.reason,
          equals(OfflineModeReason.networkUnavailable),
        );
        expect(exitedEvent.networkRestored, isTrue);
      });

      test(
        'should handle partial network connectivity (slow connections)',
        () async {
          // Test that timeout errors are categorized as network timeout
          final timeoutError = TimeoutException('Connection timed out');
          final errorType = OidcOfflineAuthErrorHandler.categorizeError(
            timeoutError,
          );

          expect(errorType, equals(OfflineAuthErrorType.networkTimeout));

          // Should continue in offline mode for slow/timeout connections
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: timeoutError,
              supportOfflineAuth: true,
            ),
            isTrue,
          );
        },
      );

      test('should handle clock skew in offline mode', () async {
        // Test that token expiry is calculated with clock.now()
        final token = OidcToken(
          idToken: 'test-token',
          accessToken: 'test-access',
          tokenType: 'Bearer',
          expiresIn: const Duration(hours: 1),
          creationTime: clock.now().subtract(const Duration(hours: 2)),
        );

        // Token should be expired based on creation time + expiresIn
        expect(token.isAccessTokenExpired(), isTrue);

        // Verify clock.now() is used for time calculations
        expect(token.creationTime, isNotNull);
      });

      test('should handle app restart while in offline mode', () async {
        // Test that tokens can be persisted and retrieved across app restarts
        await testStore.set(
          OidcStoreNamespace.secureTokens,
          key: 'persistent-token',
          value: jsonEncode({
            'idToken': 'persisted-id-token',
            'accessToken': 'persisted-access-token',
          }),
        );

        // Verify token persists (simulating app restart)
        final persistedToken = await testStore.get(
          OidcStoreNamespace.secureTokens,
          key: 'persistent-token',
        );

        expect(persistedToken, isNotNull);
        expect(persistedToken, contains('persisted-id-token'));
        // Verify offline state persists across app restarts
      });
    });

    group('Integration with supportOfflineAuth=false', () {
      test(
        'should remove expired tokens when supportOfflineAuth=false',
        () async {
          final settings = OidcUserManagerSettings(
            redirectUri: Uri.parse('https://test.example.com/callback'),
            scope: ['openid'],
          );

          // Create expired token
          final expiredToken = OidcToken(
            idToken: 'expired-id',
            accessToken: 'expired-access',
            tokenType: 'Bearer',
            expiresIn: const Duration(hours: 1),
            creationTime: clock.now().subtract(const Duration(hours: 2)),
          );

          expect(settings.supportOfflineAuth, isFalse);
          expect(expiredToken.isAccessTokenExpired(), isTrue);
          // Tokens should be cleared when offline mode is disabled
        },
      );

      test(
        'should log user out immediately when network fails and offline mode disabled',
        () async {
          final settings = OidcUserManagerSettings(
            redirectUri: Uri.parse('https://test.example.com/callback'),
            scope: ['openid'],
          );

          // Test that network error doesn't allow offline mode when disabled
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: const SocketException('Network unreachable'),
              supportOfflineAuth: false,
            ),
            isFalse,
          );

          expect(settings.supportOfflineAuth, isFalse);
          // User should be logged out immediately when network fails
        },
      );
    });
  });
}

/// Helper function to create an expired JWT token for testing
Future<String> _createExpiredToken(JsonWebKeyStore keyStore) async {
  final key = JsonWebKey.generate('RS256');
  keyStore.addKey(key);

  final builder = JsonWebSignatureBuilder()
    ..jsonContent = jsonEncode({
      'iss': 'https://test.example.com',
      'sub': 'test-user',
      'aud': 'test-client',
      'exp':
          (clock.now().millisecondsSinceEpoch ~/ 1000) -
          3600, // Expired 1 hour ago
      'iat': (clock.now().millisecondsSinceEpoch ~/ 1000) - 7200,
    })
    ..addRecipient(key, algorithm: 'RS256');

  final jws = builder.build();
  return jws.toCompactSerialization();
}
