import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

/// Utility class to categorize errors for offline authentication handling.
///
/// This helps distinguish between network errors (device offline),
/// server errors (server unavailable), and authentication errors
/// (invalid credentials, expired tokens).
class OidcOfflineAuthErrorHandler {
  /// Categorizes an error to determine how it should be handled in offline mode.
  static OfflineAuthErrorType categorizeError(Object error) {
    // Network connectivity issues
    if (error is SocketException) {
      return OfflineAuthErrorType.networkUnavailable;
    }

    if (error is TimeoutException) {
      return OfflineAuthErrorType.networkTimeout;
    }

    if (error is HandshakeException) {
      return OfflineAuthErrorType.sslError;
    }

    // HTTP response errors
    if (error is http.Response) {
      return categorizeHttpResponse(error);
    }

    // OIDC-specific errors
    if (error is OidcException) {
      final errorResponse = error.errorResponse;
      if (errorResponse != null) {
        return categorizeOidcError(errorResponse);
      }
    }

    // Unknown error - treat as network issue if offline auth is enabled
    return OfflineAuthErrorType.unknown;
  }

  /// Categorizes HTTP response errors.
  static OfflineAuthErrorType categorizeHttpResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Authentication errors - should not continue in offline mode
    if (statusCode == 401 || statusCode == 403) {
      return OfflineAuthErrorType.authenticationError;
    }

    // Client errors (except auth) - should not continue in offline mode
    if (statusCode >= 400 && statusCode < 500) {
      return OfflineAuthErrorType.clientError;
    }

    // Server errors - can continue in offline mode
    if (statusCode >= 500 && statusCode < 600) {
      return OfflineAuthErrorType.serverError;
    }

    return OfflineAuthErrorType.unknown;
  }

  /// Categorizes OIDC error responses.
  static OfflineAuthErrorType categorizeOidcError(
    OidcErrorResponse errorResponse,
  ) {
    final error = errorResponse.error;

    // Authentication/authorization errors - should not continue in offline mode
    if (error == 'invalid_grant' ||
        error == 'invalid_token' ||
        error == 'invalid_client' ||
        error == 'unauthorized_client' ||
        error == 'access_denied') {
      return OfflineAuthErrorType.authenticationError;
    }

    // Temporary errors - can continue in offline mode
    if (error == 'server_error' ||
        error == 'temporarily_unavailable' ||
        error == 'service_unavailable') {
      return OfflineAuthErrorType.serverError;
    }

    // Other errors - treat as client error
    return OfflineAuthErrorType.clientError;
  }

  /// Determines if an error should allow continuation in offline mode.
  ///
  /// Returns `true` if the error is network-related or a temporary server error,
  /// and [supportOfflineAuth] is enabled.
  static bool shouldContinueInOfflineMode({
    required Object error,
    required bool supportOfflineAuth,
  }) {
    if (!supportOfflineAuth) {
      return false;
    }

    final errorType = categorizeError(error);

    switch (errorType) {
      case OfflineAuthErrorType.networkUnavailable:
      case OfflineAuthErrorType.networkTimeout:
      case OfflineAuthErrorType.serverError:
      case OfflineAuthErrorType.sslError:
        return true;

      case OfflineAuthErrorType.authenticationError:
      case OfflineAuthErrorType.clientError:
        return false;

      case OfflineAuthErrorType.unknown:
        // For unknown errors, be conservative and allow offline mode
        // This prevents unnecessary logouts due to unexpected errors
        return true;
    }
  }

  /// Gets a user-friendly error message for the error type.
  static String getErrorMessage(OfflineAuthErrorType errorType) {
    switch (errorType) {
      case OfflineAuthErrorType.networkUnavailable:
        return 'Network connection unavailable. Using cached authentication.';
      case OfflineAuthErrorType.networkTimeout:
        return 'Connection timeout. Using cached authentication.';
      case OfflineAuthErrorType.serverError:
        return 'Authentication server unavailable. Using cached authentication.';
      case OfflineAuthErrorType.sslError:
        return 'SSL/TLS error. Using cached authentication.';
      case OfflineAuthErrorType.authenticationError:
        return 'Authentication failed. Please sign in again.';
      case OfflineAuthErrorType.clientError:
        return 'Client error occurred. Please check your configuration.';
      case OfflineAuthErrorType.unknown:
        return 'An unexpected error occurred. Using cached authentication.';
    }
  }

  /// Gets the appropriate [OfflineModeReason] for an error.
  static OfflineModeReason getOfflineModeReason(
    OfflineAuthErrorType errorType,
  ) {
    switch (errorType) {
      case OfflineAuthErrorType.networkUnavailable:
      case OfflineAuthErrorType.networkTimeout:
        return OfflineModeReason.networkUnavailable;

      case OfflineAuthErrorType.serverError:
      case OfflineAuthErrorType.sslError:
        return OfflineModeReason.serverUnavailable;

      case OfflineAuthErrorType.authenticationError:
      case OfflineAuthErrorType.clientError:
      case OfflineAuthErrorType.unknown:
        return OfflineModeReason.serverUnavailable;
    }
  }
}

/// Types of errors that can occur during authentication.
enum OfflineAuthErrorType {
  /// Network is unavailable (SocketException).
  networkUnavailable,

  /// Network request timed out.
  networkTimeout,

  /// SSL/TLS handshake error.
  sslError,

  /// Server error (5xx HTTP status codes).
  serverError,

  /// Authentication error (401, 403, invalid_grant, etc.).
  authenticationError,

  /// Client error (4xx HTTP status codes, except auth errors).
  clientError,

  /// Unknown or unclassified error.
  unknown,
}
