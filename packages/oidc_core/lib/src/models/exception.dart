class OidcException implements Exception {
  const OidcException(
    this.message, {
    this.extra = const {},
  });

  final dynamic message;
  final Map<String, dynamic> extra;

  @override
  String toString() {
    final message = this.message;
    if (message == null) return 'OidcException';
    return 'OidcException: $message, extra: $extra';
  }
}
