/// The one place a web redirect URI is derived.
///
/// The app under test and the conformance harness both need the redirect URI
/// the app will actually send. They used to build it separately -- the app
/// resolved against [Uri.base], the harness returned a hardcoded
/// `http://localhost:22433/redirect.html` -- and agreed only because CI served
/// the app at exactly that origin. A registered redirect_uri that does not
/// match the one the app sends is rejected by the OP as unregistered, so the
/// two must be one derivation, not two that happen to coincide.
library;

/// The redirect page, overridable at build time.
///
/// Read by both derivations below so a `--dart-define` cannot move one without
/// the other.
const webRedirectUriSetting = String.fromEnvironment(
  'OIDC_REDIRECT_URI',
  defaultValue: 'redirect.html',
);

/// The post-logout redirect page, overridable at build time.
const webPostLogoutRedirectUriSetting = String.fromEnvironment(
  'OIDC_POST_LOGOUT_REDIRECT_URI',
  defaultValue: 'redirect.html',
);

/// Resolves [configuredUri] against the origin the app is served from.
///
/// [base] is the page URL -- pass [Uri.base] in the app and the harness; tests
/// pass a synthetic origin. Taking it as a parameter rather than reading the
/// global is what makes the resolution assertable at all.
///
/// A relative [configuredUri] resolves against the current *directory*, so a
/// deep SPA route (`/app/secret-route`) still points at `/app/redirect.html`
/// rather than `/app/secret-route/redirect.html`. A leading `/` resolves
/// against the origin, and an absolute URI is returned as given.
Uri resolveWebRedirectUri(
  String configuredUri, {
  required Uri base,
  Map<String, String>? queryParameters,
}) {
  final trimmed = configuredUri.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(
      configuredUri,
      'configuredUri',
      'must not be empty',
    );
  }

  if (!base.isScheme('http') && !base.isScheme('https')) {
    // Uri.origin throws a bare StateError here, naming neither this function
    // nor the caller. Every non-web platform has a file:// Uri.base, so the
    // wrong caller is a realistic mistake and its failure has to be readable.
    throw ArgumentError.value(
      base,
      'base',
      'must be an http or https origin; a web redirect URI cannot be resolved '
          'against a ${base.scheme}: base. On non-web platforms use the '
          'platform redirect URI instead of deriving one from Uri.base',
    );
  }

  final origin = Uri.parse(base.origin);

  // Example:
  // - /oidc-example/secret-route -> /oidc-example/
  // - /oidc-example/             -> /oidc-example/
  final basePath = base.path;
  final directoryPath = basePath.endsWith('/')
      ? basePath
      : basePath.substring(0, basePath.lastIndexOf('/') + 1);

  final parsed = Uri.parse(trimmed);

  final Uri result;
  if (parsed.hasScheme) {
    result = parsed;
  } else if (trimmed.startsWith('/')) {
    result = origin.replace(path: parsed.path);
  } else {
    result = origin.replace(path: '$directoryPath${parsed.path}');
  }

  final mergedQueryParameters = <String, String>{
    ...result.queryParameters,
    ...parsed.queryParameters,
    if (queryParameters != null) ...queryParameters,
  };

  return result.replace(
    queryParameters: mergedQueryParameters.isEmpty
        ? null
        : mergedQueryParameters,
  );
}

/// The redirect URI the app under test registers and sends on web.
Uri appWebRedirectUri({required Uri base}) =>
    resolveWebRedirectUri(webRedirectUriSetting, base: base);

/// The redirect URI the conformance harness registers with the test plan.
///
/// Identical to [appWebRedirectUri] by construction. It exists as its own name
/// so the intent -- these two must never diverge -- is visible at both call
/// sites and lockable by a test.
Uri harnessWebRedirectUri({required Uri base}) => appWebRedirectUri(base: base);

/// The front-channel logout URI: the redirect page with the marker query the
/// example's `redirect.html` dispatches on.
Uri webFrontChannelLogoutUri({required Uri base}) => resolveWebRedirectUri(
  webRedirectUriSetting,
  base: base,
  queryParameters: const {'requestType': 'front-channel-logout'},
);
