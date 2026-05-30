/// A parsed OAuth 2.0 `WWW-Authenticate` challenge from a protected-resource
/// `401` response, with first-class support for the RFC 9470 step-up
/// authentication challenge (`error="insufficient_user_authentication"`).
///
/// When a resource server requires a higher authentication level (a specific
/// `acr` and/or a fresher `max_age`), it answers with such a challenge; the
/// client then re-runs authorization carrying [acrValues] / [maxAge] so the
/// OP can step the user up.
class OidcStepUpChallenge {
  ///
  const OidcStepUpChallenge({
    required this.parameters,
    this.scheme,
    this.error,
    this.errorDescription,
    this.acrValues,
    this.maxAge,
  });

  /// The RFC 9470 step-up error code.
  static const insufficientUserAuthenticationError =
      'insufficient_user_authentication';

  /// The authentication scheme of the challenge (e.g. `Bearer`, `DPoP`).
  final String? scheme;

  /// The `error` auth-param, if present.
  final String? error;

  /// The `error_description` auth-param, if present.
  final String? errorDescription;

  /// The requested `acr_values` (space-delimited in the header), if present.
  final List<String>? acrValues;

  /// The requested `max_age`, if present.
  final Duration? maxAge;

  /// All parsed auth-params (raw string values), including any not surfaced as
  /// typed members above.
  final Map<String, String> parameters;

  /// Whether this is an RFC 9470 step-up challenge
  /// (`error == "insufficient_user_authentication"`).
  bool get isInsufficientUserAuthentication =>
      error == insufficientUserAuthenticationError;

  static final _authParamPattern = RegExp(
    r'([a-zA-Z0-9_-]+)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^,\s]+))',
  );

  /// Parses a `WWW-Authenticate` header value into an [OidcStepUpChallenge].
  ///
  /// Returns `null` when [header] is null/blank or carries no auth-params.
  /// Handles a leading auth scheme followed by comma-separated `key=value` or
  /// `key="quoted value"` params.
  static OidcStepUpChallenge? parse(String? header) {
    if (header == null) {
      return null;
    }
    final value = header.trim();
    if (value.isEmpty) {
      return null;
    }

    String? scheme;
    String paramsPart;
    final firstSpace = value.indexOf(' ');
    if (firstSpace == -1) {
      // No space: either a bare scheme (no params) or only params.
      if (value.contains('=')) {
        paramsPart = value;
      } else {
        return null;
      }
    } else {
      final head = value.substring(0, firstSpace);
      // A scheme token never contains '='; if it does, there is no scheme.
      if (head.contains('=')) {
        paramsPart = value;
      } else {
        scheme = head;
        paramsPart = value.substring(firstSpace + 1);
      }
    }

    final params = <String, String>{};
    for (final match in _authParamPattern.allMatches(paramsPart)) {
      final key = match.group(1)!.toLowerCase();
      final quoted = match.group(2);
      final unquoted = match.group(3);
      params[key] = (quoted != null
          ? quoted.replaceAll(r'\"', '"')
          : unquoted)!;
    }
    if (params.isEmpty) {
      return null;
    }

    final maxAgeRaw = params['max_age'];
    final maxAgeSeconds = maxAgeRaw == null ? null : int.tryParse(maxAgeRaw);
    final acrRaw = params['acr_values'];

    return OidcStepUpChallenge(
      scheme: scheme,
      error: params['error'],
      errorDescription: params['error_description'],
      acrValues: acrRaw?.split(' ').where((e) => e.isNotEmpty).toList(),
      maxAge: maxAgeSeconds == null ? null : Duration(seconds: maxAgeSeconds),
      parameters: params,
    );
  }

  @override
  String toString() =>
      'OidcStepUpChallenge(scheme: $scheme, error: $error, '
      'acrValues: $acrValues, maxAge: $maxAge)';
}
