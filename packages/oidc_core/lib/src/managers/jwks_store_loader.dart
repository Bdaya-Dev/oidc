import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';

/// Appends a unique query parameter to [uri] so a request through it defeats
/// any HTTP/CDN-level response caching sitting in front of the JWKS
/// endpoint.
///
/// Used when forcing a live JWKS refetch after an id_token signature
/// verification failure whose `kid` could not be resolved against the
/// just-loaded key set — a possible in-flight key rotation (OpenID Connect
/// Core 1.0 §10.1.1 Rotation of Asymmetric Signing Keys). A plain repeated GET
/// to the same URL could otherwise be served from an edge cache that hasn't
/// picked up the rotated key yet.
Uri cacheBustJwksUri(Uri uri) => uri.replace(
  queryParameters: {
    ...uri.queryParameters,
    '_oidc_jwks_refresh': clock.now().toUtc().microsecondsSinceEpoch
        .toString(),
  },
);

class OidcJwksStoreLoader extends DefaultJsonWebKeySetLoader {
  OidcJwksStoreLoader({
    required this.store,
    this.staleCacheMaxAge = const Duration(days: 1),
    this.forceFresh = false,
    super.cacheExpiry,
    super.httpClient,
  });

  /// The store to check first for the cached jws
  final OidcStore store;

  /// Maximum age a persisted JWKS fallback may reach before it is treated as
  /// stale and refused.
  ///
  /// The persisted copy under [OidcStoreNamespace.discoveryDocument] is
  /// consulted ONLY when the live `jwks_uri` fetch fails; if its stored
  /// fetched-at timestamp is older than this, the cached key set is NOT served
  /// and the fetch error is rethrown (fail-closed). This bounds how long a
  /// rotated/compromised signing key can be trusted offline (OpenID Connect
  /// Core 1.0 §10.1.1 Rotation of Asymmetric Signing Keys).
  ///
  /// [Duration.zero]/negative disables the offline fallback entirely (any
  /// cached value is refused); a very large value reproduces the pre-fix
  /// unbounded behavior.
  final Duration staleCacheMaxAge;

  /// When `true`, the live fetch is issued against a [cacheBustJwksUri]
  /// variant of the requested uri (bypassing any HTTP/CDN cache in front of
  /// `jwks_uri`), while the persisted offline-fallback copy is still
  /// read/written under the canonical (non-busted) uri key.
  ///
  /// Set this for the ONE retry attempt after a signature verification
  /// failure whose id_token `kid` was absent from the just-loaded JWKS (see
  /// `OidcUser.fromIdToken`) — never for routine reads.
  final bool forceFresh;

  /// Sidecar key suffix that holds the epoch-millis fetched-at timestamp next
  /// to a persisted JWKS value. The suffix cannot collide with a real
  /// `jwks_uri` / discovery-URL key.
  static const _fetchedAtSuffix = '::oidc_jwks_fetched_at';

  @override
  Future<String> readAsString(Uri uri) async {
    final key = uri.toString();
    final sidecarKey = '$key$_fetchedAtSuffix';
    try {
      final result = await super.readAsString(
        forceFresh ? cacheBustJwksUri(uri) : uri,
      );
      // Persist the JWKS alongside a fetched-at timestamp in one write so the
      // value and its age are co-stored. Always keyed by the CANONICAL uri
      // (not the cache-busted one), so a forced refetch refreshes the same
      // offline-fallback entry a normal read would use.
      await store.setMany(
        OidcStoreNamespace.discoveryDocument,
        values: {
          key: result,
          sidecarKey: clock.now().toUtc().millisecondsSinceEpoch.toString(),
        },
      );
      return result;
    } catch (e) {
      // The persisted copy is an OFFLINE fallback only. Refuse to serve it past
      // [staleCacheMaxAge] so a rotated/compromised key is not trusted forever
      // when the live fetch keeps failing (OIDC Core §10.1.1).
      final cachedValues = await store.getMany(
        OidcStoreNamespace.discoveryDocument,
        keys: {key, sidecarKey},
      );
      final cached = cachedValues[key];
      if (cached == null) {
        rethrow;
      }
      final fetchedAtStr = cachedValues[sidecarKey];
      final fetchedAtMs = fetchedAtStr == null
          ? null
          : int.tryParse(fetchedAtStr);
      if (fetchedAtMs == null) {
        // Missing/unparseable timestamp (legacy or corrupt entry): fail-closed.
        rethrow;
      }
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        fetchedAtMs,
        isUtc: true,
      );
      final age = clock.now().toUtc().difference(fetchedAt);
      if (staleCacheMaxAge <= Duration.zero || age > staleCacheMaxAge) {
        // Fallback disabled (zero/negative max-age) or stale beyond the allowed
        // window: do NOT serve the cached key set.
        rethrow;
      }
      return cached;
    }
  }
}

/// A one-shot [JsonWebKeySetLoader] used to force a live, cache-busted JWKS
/// refetch when no [OidcStore] is available to persist an offline fallback
/// copy — the `cacheStore`-less `OidcUser.fromIdToken` path.
///
/// A fresh instance's own (per-instance) HTTP response cache starts empty, so
/// pairing it with [cacheBustJwksUri] guarantees the request bypasses BOTH
/// this loader's cache and any HTTP/CDN cache in front of the `jwks_uri` —
/// unlike the long-lived, process-wide default loader
/// ([JsonWebKeySetLoader.current]'s fallback when no loader is zoned in),
/// whose in-memory TTL cache (default 5 minutes, longer when the OP sends a
/// generous `Cache-Control`/`Expires`) can otherwise mask a just-rotated
/// signing key for its full cache lifetime.
class OidcForceFreshJwksLoader extends DefaultJsonWebKeySetLoader {
  OidcForceFreshJwksLoader({super.httpClient});

  @override
  Future<String> readAsString(Uri uri) =>
      super.readAsString(cacheBustJwksUri(uri));
}
