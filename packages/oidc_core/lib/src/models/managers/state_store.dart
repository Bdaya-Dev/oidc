// ignore_for_file: lines_longer_than_80_chars

enum OidcStoreNamespace {
  /// Stores ephermal information, such as the current state id and nonce.
  session('session'),

  /// Stores states.
  ///
  /// on web, this MUST be stored in localStorage for the `samePage` navigation mode to work,
  /// since the html page has no access to the `OidcStore` object.
  ///
  /// the key MUST be in the format:
  /// `oidc-state-{key}`
  state('state'),

  /// Stores discovery documents as json
  discoveryDocument('discoveryDocument'),

  /// Identity Tokens, Access tokens, or any other tokens that require
  /// secure storage.
  secureTokens('secureTokens');

  const OidcStoreNamespace(this.value);

  final String value;
}

abstract interface class OidcStore {
  Future<void> init();
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace);

  Future<void> set(
    OidcStoreNamespace namespace, {
    required String key,
    required String value,
  });

  Future<String?> get(
    OidcStoreNamespace namespace, {
    required String key,
  });

  Future<void> remove(
    OidcStoreNamespace namespace, {
    required String key,
  });

  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
  });
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  });
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  });
}
