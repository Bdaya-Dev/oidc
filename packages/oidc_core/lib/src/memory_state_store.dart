import 'state_store.dart';

/// A simple OidcStore implementation that relies on memory and doesn't actually
/// store anything.
///
/// for a persistent store, consider using (oidc_default_store)[https://pub.dev/packages/oidc_default_store]
class OidcMemoryStore implements OidcStore {
  static const Object nullToken = Object();
  final _namespaces = <OidcStoreNamespace, Map<Object, Map<String, String>>>{};

  Map<String, String> _perNamespaceMap(
    OidcStoreNamespace namespace, {
    required String? managerId,
  }) {
    final namespaceMap = _namespaces[namespace] ??= {};
    return namespaceMap[managerId ?? nullToken] ??= <String, String>{};
  }

  @override
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace,
      {String? managerId}) {
    return Future.value(_perNamespaceMap(
      namespace,
      managerId: managerId,
    ).keys.toSet());
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) {
    return Future.value(
      Map.fromEntries(
        keys
            .map(
              (k) => MapEntry(
                k,
                _perNamespaceMap(
                  namespace,
                  managerId: managerId,
                )[k],
              ),
            )
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
    String? managerId,
  }) {
    _perNamespaceMap(namespace, managerId: managerId)
        .removeWhere((key, value) => keys.contains(key));
    return Future.value();
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
    String? managerId,
  }) {
    _perNamespaceMap(namespace, managerId: managerId).addAll(values);
    return Future.value();
  }
}
