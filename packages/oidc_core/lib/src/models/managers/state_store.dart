abstract interface class OidcStateStore {
  Future<void> set(String key, String value);
  Future<String?> get(String key);
  Future<String?> remove(String key);
  Future<List<String>> getAllKeys();
}
