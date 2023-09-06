enum OidcStoreNamespace {
  /// Stores ephermal information, such as the current state id and nonce.
  session('session'),

  /// Stores states.
  ///
  /// on web, this MUST be stored in localStorage, since the html page has no
  /// access to the `OidcStore` object.
  ///
  /// the key MUST be with the format:
  /// `oidc-state-{key}`
  ///
  /// since the html page has no access to the `OidcStore` object.
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
  Future<void> set(
    OidcStoreNamespace namespace, {
    required String key,
    required String value,
  });

  Future<String?> get(
    OidcStoreNamespace namespace, {
    required String key,
  });

  Future<String?> remove(
    OidcStoreNamespace namespace, {
    required String key,
  });

  Future<List<String>> getAllKeys(OidcStoreNamespace namespace);

  Future<Map<String, String>> setMany(
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
