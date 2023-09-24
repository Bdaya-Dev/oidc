// coverage:ignore-file
import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

class OidcException implements Exception {
  const OidcException(
    this.message, {
    this.extra = const {},
    this.internalException,
    this.internalStackTrace,
    this.rawRequest,
    this.rawResponse,
  }) : errorResponse = null;

  const OidcException.serverError({
    required OidcErrorResponse this.errorResponse,
    this.extra = const {},
    this.rawRequest,
    this.rawResponse,
    String? message,
  })  : message = message ?? 'Server sent an error response',
        internalException = null,
        internalStackTrace = null;

  final String message;
  final Map<String, dynamic> extra;
  final OidcErrorResponse? errorResponse;
  final Object? internalException;
  final StackTrace? internalStackTrace;
  final http.Request? rawRequest;
  final http.Response? rawResponse;

  @override
  String toString() {
    final message = this.message;
    return 'OidcException: $message, '
        'extra: $extra, '
        'error: ${errorResponse?.error}';
  }
}
