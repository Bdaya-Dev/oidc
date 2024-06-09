import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';

class OidcJwksStoreLoader extends DefaultJsonWebKeySetLoader {
  OidcJwksStoreLoader({
    required this.store,
    super.cacheExpiry,
    super.httpClient,
  });

  /// The store to check first for the cached jws
  final OidcStore store;

  @override
  Future<String> readAsString(Uri uri) async {
    try {
      final result = await super.readAsString(uri);
      await store.set(
        OidcStoreNamespace.discoveryDocument,
        key: uri.toString(),
        value: result,
      );
      return result;
    } catch (e) {
      //
      final cached = await store.get(
        OidcStoreNamespace.discoveryDocument,
        key: uri.toString(),
      );
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
