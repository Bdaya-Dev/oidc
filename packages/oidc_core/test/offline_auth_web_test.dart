import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// Cross-platform (VM **and** web) tests for [OidcOfflineAuthErrorHandler].
///
/// These intentionally avoid `dart:io` types so they compile and pass on web,
/// where `package:http` surfaces transport failures as [http.ClientException]
/// rather than a `dart:io` `SocketException`. The dart:io-specific
/// categorization (`SocketException`/`HandshakeException`/`TlsException`) is
/// covered by the VM-only `offline_auth_test.dart`.
void main() {
  group('OidcOfflineAuthErrorHandler (cross-platform)', () {
    group('network errors', () {
      test('http.ClientException is categorized as networkUnavailable', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeError(
            http.ClientException('Failed to connect'),
          ),
          equals(OfflineAuthErrorType.networkUnavailable),
        );
      });

      test('TimeoutException is categorized as networkTimeout', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeError(
            TimeoutException('timed out'),
          ),
          equals(OfflineAuthErrorType.networkTimeout),
        );
      });

      test(
        'continues in offline mode for a ClientException only when enabled',
        () {
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: http.ClientException('offline'),
              supportOfflineAuth: true,
            ),
            isTrue,
          );
          expect(
            OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
              error: http.ClientException('offline'),
              supportOfflineAuth: false,
            ),
            isFalse,
          );
        },
      );
    });

    group('HTTP response status codes', () {
      test('401 and 403 -> authenticationError', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeHttpResponse(
            http.Response('', 401),
          ),
          equals(OfflineAuthErrorType.authenticationError),
        );
        expect(
          OidcOfflineAuthErrorHandler.categorizeHttpResponse(
            http.Response('', 403),
          ),
          equals(OfflineAuthErrorType.authenticationError),
        );
      });

      test('5xx -> serverError and continues offline', () {
        for (final code in [500, 502, 503]) {
          expect(
            OidcOfflineAuthErrorHandler.categorizeHttpResponse(
              http.Response('', code),
            ),
            equals(OfflineAuthErrorType.serverError),
            reason: 'status $code',
          );
        }
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: http.Response('', 503),
            supportOfflineAuth: true,
          ),
          isTrue,
        );
      });

      test('other 4xx -> clientError and does NOT continue offline', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeHttpResponse(
            http.Response('', 400),
          ),
          equals(OfflineAuthErrorType.clientError),
        );
        expect(
          OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
            error: http.Response('', 400),
            supportOfflineAuth: true,
          ),
          isFalse,
        );
      });
    });

    group('OIDC error responses', () {
      test('invalid_grant -> authenticationError', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeOidcError(
            OidcErrorResponse.fromJson(const {'error': 'invalid_grant'}),
          ),
          equals(OfflineAuthErrorType.authenticationError),
        );
      });

      test('temporarily_unavailable -> serverError', () {
        expect(
          OidcOfflineAuthErrorHandler.categorizeOidcError(
            OidcErrorResponse.fromJson(
              const {'error': 'temporarily_unavailable'},
            ),
          ),
          equals(OfflineAuthErrorType.serverError),
        );
      });
    });

    group('helpers', () {
      test('getOfflineModeReason maps network/server types', () {
        expect(
          OidcOfflineAuthErrorHandler.getOfflineModeReason(
            OfflineAuthErrorType.networkUnavailable,
          ),
          equals(OfflineModeReason.networkUnavailable),
        );
        expect(
          OidcOfflineAuthErrorHandler.getOfflineModeReason(
            OfflineAuthErrorType.serverError,
          ),
          equals(OfflineModeReason.serverUnavailable),
        );
      });

      test('getErrorMessage returns a non-empty message for every type', () {
        for (final type in OfflineAuthErrorType.values) {
          expect(
            OidcOfflineAuthErrorHandler.getErrorMessage(type),
            isNotEmpty,
            reason: type.name,
          );
        }
      });
    });
  });
}
