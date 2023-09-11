import 'state_store.dart';

/// A simple OidcStore implementation that relies on memory and doesn't actually
/// store anything.
///
/// for a persistent store, consider using (oidc_default_store)[https://pub.dev/packages/oidc_default_store]
class OidcMemoryStore implements OidcStore {
  final _namespaces = <OidcStoreNamespace, Map<String, String>>{};

  Map<String, String> _perNamespaceMap(OidcStoreNamespace namespace) {
    return _namespaces[namespace] ??= {};
  }

  @override
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace) {
    return Future.value(_perNamespaceMap(namespace).keys.toSet());
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  }) {
    return Future.value(
      Map.fromEntries(
        keys
            .map((k) => MapEntry(k, _perNamespaceMap(namespace)[k]))
            .where((element) => element.value != null),
      ).cast<String, String>(),
    );
  }

  @override
  Future<void> init() {
    return Future.value();
  }

  @override
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  }) {
    _perNamespaceMap(namespace).removeWhere((key, value) => keys.contains(key));
    return Future.value();
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
  }) {
    _perNamespaceMap(namespace).addAll(values);
    return Future.value();
  }
}
