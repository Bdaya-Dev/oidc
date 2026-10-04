import 'package:oidc_core/src/managers/user_manager_base.dart'
    show OidcUserManagerBase;

/// Where the id_token being validated came from.
///
/// The OpenID Connect Core 1.0 rules for the `at_hash` and `c_hash` claims
/// depend on which response issued the id_token, so
/// [OidcUserManagerBase.validateUser] needs to know it. See
/// [OidcIdTokenValidationContext].
enum OidcIdTokenSource {
  /// Issued by the authorization endpoint, in the front channel: the implicit
  /// flow (`id_token`, `id_token token`) or the front-channel id_token of the
  /// hybrid flow (`code id_token`, `code id_token token`).
  ///
  /// This is the only source for which the hashes are REQUIRED:
  ///
  /// * `at_hash` is REQUIRED when an access_token was returned with the
  ///   id_token (§3.2.2.10 for implicit, §3.3.2.11 for hybrid). For an
  ///   implicit `id_token` response there is no access_token, so it is not
  ///   used.
  /// * `c_hash` is REQUIRED when an authorization code was returned with the
  ///   id_token (§3.3.2.11).
  authorizationEndpoint,

  /// Issued by the token endpoint for a code exchange or another direct grant
  /// (password, device code). Both hashes are OPTIONAL and checked only when
  /// present (§3.1.3.8, §3.3.3.6).
  tokenEndpoint,

  /// Issued by the token endpoint for a `refresh_token` grant (§12.2).
  ///
  /// The hashes follow the [tokenEndpoint] rule when the refresh response
  /// returned a NEW id_token. When it returned none, the previous id_token is
  /// kept (see `OidcToken.idTokenRetainedFromPriorResponse`) and its hashes
  /// are not compared with the new tokens, because they were computed for the
  /// tokens of the earlier response.
  refresh,

  /// Read back from the store, for example by `init()` revalidating the
  /// session it restored.
  ///
  /// The stored id_token was issued with the stored access_token unless it
  /// was retained across a refresh, which the stored token records. So the
  /// [refresh] rule applies, using that persisted marker.
  storedSession,
}

/// Inputs to id_token validation that depend on the flow that produced the
/// token, rather than on the token itself.
///
/// Passed to [OidcUserManagerBase.validateUser],
/// [OidcUserManagerBase.validateAndSaveUser] and
/// [OidcUserManagerBase.createUserFromToken].
final class OidcIdTokenValidationContext {
  /// Creates a validation context.
  ///
  /// The default ([OidcIdTokenSource.tokenEndpoint], no code, no `max_age`)
  /// applies only the checks that hold for any id_token, and checks a hash
  /// only when the claim is present.
  const OidcIdTokenValidationContext({
    this.source = OidcIdTokenSource.tokenEndpoint,
    this.authorizationCode,
    this.maxAge,
  });

  /// Which response issued the id_token. Decides whether `at_hash` and
  /// `c_hash` are required or only checked when present.
  final OidcIdTokenSource source;

  /// The authorization code returned with the id_token, if any.
  ///
  /// When set, a `c_hash` claim must match it (§3.3.2.11). When it is set and
  /// [source] is [OidcIdTokenSource.authorizationEndpoint], `c_hash` must also
  /// be present.
  final String? authorizationCode;

  /// The `max_age` sent in the authorization request, if any.
  ///
  /// When set, the id_token must carry `auth_time`, and the authentication it
  /// records must be no older than [maxAge] (plus the configured expiry
  /// tolerance), per §3.1.2.1.
  final Duration? maxAge;

  @override
  String toString() =>
      'OidcIdTokenValidationContext(source: ${source.name}, '
      'authorizationCode: ${authorizationCode == null ? null : '<redacted>'}, '
      'maxAge: $maxAge)';
}
