import 'package:oidc_core/oidc_core.dart';

class OidcException implements Exception {
  const OidcException(
    this.message, {
    this.extra = const {},
    this.errorResponse,
    this.internalException,
    this.internalStackTrace,
  });

  final String message;
  final Map<String, dynamic> extra;
  final OidcErrorResponse? errorResponse;
  final Object? internalException;
  final StackTrace? internalStackTrace;

  @override
  String toString() {
    final message = this.message;
    return 'OidcException: $message, '
        'extra: $extra, '
        'error: ${errorResponse?.error}';
  }
}
