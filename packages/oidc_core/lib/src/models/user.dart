import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';

final _logger = Logger('Oidc.User');

/// Minimum time between forced cache-busting JWKS refetches triggered by an
/// id_token verification failure, per issuer. Prevents a forged/garbage `kid`
/// from being used to flood the JWKS endpoint (DoS) while still self-healing
/// a genuine key rotation quickly.
///
/// 5 minutes matches Microsoft Entra's key-rollover guidance and the
/// panva/WorkOS JWKS guide (OpenID Connect Core 1.0 §10.1.1).
const _jwksForceRefetchCooldown = Duration(minutes: 5);

/// Tracks, per issuer, the last time a verification failure triggered a
/// forced JWKS refetch. Process-lifetime only (deliberately not persisted):
/// the goal is rate-limiting a hot loop within a running process, not
/// surviving restarts.
@visibleForTesting
final Map<String, DateTime> jwksForceRefetchTimestamps = {};

bool _shouldForceJwksRefetch(String idToken) {
  final issuerKey = _tryGetUnverifiedIssuer(idToken) ?? '<unknown-issuer>';
  final now = clock.now();
  final last = jwksForceRefetchTimestamps[issuerKey];
  if (last != null && now.difference(last) < _jwksForceRefetchCooldown) {
    return false;
  }
  jwksForceRefetchTimestamps[issuerKey] = now;
  return true;
}

String? _tryGetUnverifiedIssuer(String idToken) {
  try {
    return JsonWebToken.unverified(idToken).claims.issuer?.toString();
  } on Object catch (_) {
    return null;
  }
}

/// A user is a verified JWT id_token, with an optional access_token.
class OidcUser {
  ///
  OidcUser._({
    required this.idToken,
    required this.parsedIdToken,
    required this.token,
    required this.attributes,
    required this.keystore,
    required this.allowedAlgorithms,
    required this.userInfo,
  }) : aggregatedClaims = {
         ...parsedIdToken.claims.toJson(),
         ...userInfo,
       };

  /// Creates a OidcUser from an encoded id_token passed via [token].
  ///
  /// You can verify the idToken by passing the [keystore] parameter.
  ///
  /// You can also pass optional [attributes] that will get stored
  /// with the user.
  static Future<OidcUser> fromIdToken({
    required OidcToken token,
    bool strictVerification = true,
    JsonWebKeyStore? keystore,
    OidcStore? cacheStore,
    List<String>? allowedAlgorithms,
    Map<String, dynamic>? attributes,
    Map<String, dynamic>? userInfo,
    String? idTokenOverride,
    Duration jwksCacheMaxAge = const Duration(days: 1),
    http.Client? httpClient,
  }) async {
    final idToken = idTokenOverride ?? token.idToken;
    if (idToken == null) {
      throw const OidcException(
        "Server didn't return the id_token.",
      );
    }
    final webToken = await _getWebToken(
      keystore,
      idToken,
      allowedAlgorithms,
      cacheStore,
      strictVerification,
      jwksCacheMaxAge,
      httpClient,
    );

    return OidcUser._(
      idToken: idToken,
      parsedIdToken: webToken,
      token: token,
      attributes: attributes ?? const {},
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo ?? const {},
    );
  }

  static Future<JsonWebToken> _getWebToken(
    JsonWebKeyStore? keystore,
    String idToken,
    List<String>? allowedAlgorithms,
    OidcStore? cacheStore,
    bool strictVerification,
    Duration jwksCacheMaxAge,
    http.Client? httpClient,
  ) async {
    JsonWebToken webToken;

    if (keystore == null) {
      webToken = JsonWebToken.unverified(idToken);
    } else {
      // An ID token MUST NOT be unsigned. `jose_plus` only auto-rejects
      // `alg:none` when the allowed-algorithm list is null, so strip it
      // explicitly: an OP MAY list `none` in
      // `id_token_signing_alg_values_supported`, which would otherwise let an
      // attacker forge an unsigned id_token — most dangerously on the
      // front-channel implicit/hybrid path where the signature is the sole
      // protection. (Mirrors the JARM `alg:none` strip in `facade.dart`.)
      final algs = allowedAlgorithms
          ?.where((a) => a.toLowerCase() != 'none')
          .toList();

      Future<JsonWebToken> attemptVerify({required bool forceFreshJwks}) {
        return JsonWebKeySetLoader.runZoned(
          () => JsonWebToken.decodeAndVerify(
            idToken,
            keystore,
            allowedArguments: algs,
          ),
          loader: cacheStore == null
              ? (forceFreshJwks
                    // No OidcStore to persist an offline fallback to: force a
                    // brand-new, cache-busted loader instance so the retry
                    // bypasses BOTH this call's own cache AND the long-lived
                    // process-wide default loader's TTL cache (which can
                    // otherwise mask a just-rotated key for its full TTL).
                    ? OidcForceFreshJwksLoader(httpClient: httpClient)
                    // First attempt: preserve existing behavior (the
                    // process-wide default loader) unless a caller supplied
                    // an explicit httpClient (e.g. for testing).
                    : (httpClient == null
                          ? null
                          : DefaultJsonWebKeySetLoader(httpClient: httpClient)))
              : OidcJwksStoreLoader(
                  store: cacheStore,
                  staleCacheMaxAge: jwksCacheMaxAge,
                  forceFresh: forceFreshJwks,
                  httpClient: httpClient,
                ),
        );
      }

      try {
        try {
          webToken = await attemptVerify(forceFreshJwks: false);
        } catch (e) {
          // The id_token's `kid` may reference a signing key that rotated in
          // after our (possibly cached/CDN-served) JWKS view was read. Per
          // OIDC Core §10.1.1 and the Entra/Cognito/panva key-rotation
          // guidance: force exactly ONE fresh, cache-busting JWKS refetch and
          // retry before giving up — rate-limited per issuer
          // ([_shouldForceJwksRefetch]) so a forged/garbage `kid` can't be
          // used to flood the JWKS endpoint.
          if (!_shouldForceJwksRefetch(idToken)) {
            rethrow;
          }
          webToken = await attemptVerify(forceFreshJwks: true);
        }
      } catch (e, st) {
        if (strictVerification) {
          rethrow;
        }
        _logger.warning(
          'Failed to verify id_token, using unverified instead.',
          e,
          st,
        );
        webToken = JsonWebToken.unverified(idToken);
      }
    }
    return webToken;
  }

  /// The jwt token this user was verified from.
  final String idToken;

  /// The parsed jwt token
  final JsonWebToken parsedIdToken;

  /// The claims that were decoded from the idToken
  JsonWebTokenClaims get claims => parsedIdToken.claims;

  /// The user Id
  String? get uid => claims.subject;

  /// The user Id, but if it's null, it will throw.
  String get uidRequired => uid!;

  /// The current token the user is holding.
  final OidcToken token;

  /// The keystore that was passed from [fromIdToken] (if any).
  final JsonWebKeyStore? keystore;

  /// The allowedAlgorithms that were passed from [fromIdToken] (if any).
  final List<String>? allowedAlgorithms;

  /// immutable custom attributes that are user-defined.
  ///
  /// these MUST be json encodable.
  final Map<String, dynamic> attributes;

  /// The userInfo response.
  final Map<String, dynamic> userInfo;

  /// Combines claims from id_token and userinfo response.
  final Map<String, dynamic> aggregatedClaims;

  OidcUser withUserInfo(Map<String, dynamic> userInfo) {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      token: token,
      attributes: attributes,
      keystore: keystore,
      allowedAlgorithms: allowedAlgorithms,
      userInfo: userInfo,
    );
  }

  /// if an id_token exists in the [newToken], it will be re-verified.
  Future<OidcUser> replaceToken(
    OidcToken newToken, {
    String? idTokenOverride,
    bool strictVerification = true,
    OidcStore? cacheStore,
    bool allowExpiredIdToken = false,
    Duration jwksCacheMaxAge = const Duration(days: 1),
    http.Client? httpClient,
  }) async {
    final idToken = idTokenOverride ?? newToken.idToken ?? this.idToken;

    JsonWebToken webToken;
    if (idToken != this.idToken) {
      webToken = await _getWebToken(
        keystore,
        idToken,
        allowedAlgorithms,
        cacheStore,
        strictVerification,
        jwksCacheMaxAge,
        httpClient,
      );
    } else {
      webToken = parsedIdToken;
    }

    final mergedTokenJson = {
      // keep old data and override the new data.
      ...token.toJson(),
      ...newToken.toJson(),
    };
    if (allowExpiredIdToken) {
      mergedTokenJson[OidcConstants_Store.allowExpiredIdToken] = true;
    } else {
      mergedTokenJson.remove(OidcConstants_Store.allowExpiredIdToken);
    }

    return OidcUser._(
      idToken: idToken,
      parsedIdToken: webToken,
      token: OidcToken.fromJson(mergedTokenJson),
      attributes: attributes,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }

  OidcUser setAttributes(Map<String, dynamic> attributes) {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      attributes: {
        ...this.attributes,
        ...attributes,
      },
      token: token,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }

  OidcUser clearAttributes() {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      attributes: const {},
      token: token,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }
}
