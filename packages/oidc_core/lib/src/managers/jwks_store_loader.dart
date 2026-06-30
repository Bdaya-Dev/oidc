import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';

class OidcJwksStoreLoader extends DefaultJsonWebKeySetLoader {
  OidcJwksStoreLoader({
    required this.store,
    this.staleCacheMaxAge = const Duration(days: 1),
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

  /// Sidecar key suffix that holds the epoch-millis fetched-at timestamp next
  /// to a persisted JWKS value. The suffix cannot collide with a real
  /// `jwks_uri` / discovery-URL key.
  static const _fetchedAtSuffix = '::oidc_jwks_fetched_at';

  @override
  Future<String> readAsString(Uri uri) async {
    final key = uri.toString();
    final sidecarKey = '$key$_fetchedAtSuffix';
    try {
      final result = await super.readAsString(uri);
      // Persist the JWKS alongside a fetched-at timestamp in one write so the
      // value and its age are co-stored.
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
