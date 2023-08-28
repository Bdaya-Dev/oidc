class OidcException implements Exception {
  final dynamic message;
  final Map<String, dynamic> extra;

  const OidcException(
    this.message, {
    this.extra = const {},
  });

  @override
  String toString() {
    final message = this.message;
    if (message == null) return "OidcException";
    return "OidcException: $message, extra: $extra";
  }
}
