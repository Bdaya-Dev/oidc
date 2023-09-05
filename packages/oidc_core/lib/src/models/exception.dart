import 'package:oidc_core/oidc_core.dart';

class OidcException implements Exception {
  const OidcException(
    this.message, {
    this.extra = const {},
    this.errorResponse,
  });

  final String message;
  final Map<String, dynamic> extra;
  final OidcErrorResponse? errorResponse;

  @override
  String toString() {
    final message = this.message;
    return 'OidcException: $message, '
        'extra: $extra, '
        'error: ${errorResponse?.error}';
  }
}
