// ignore_for_file: lines_longer_than_80_chars

import 'package:oidc_core/oidc_core.dart';

enum OidcStoreNamespace {
  /// Stores ephemeral information, such as the current state id.
  session('session'),

  /// Stores states.
  ///
  /// on web, this MUST be stored in localStorage for the `samePage` navigation mode to work,
  /// since the html page has no access to the `OidcStore` object.
  ///
  /// the key MUST be in the format:
  /// `oidc.state.{key}`
  state('state'),

  /// Stores state responses.
  ///
  /// on web, the key MUST be in the format:
  /// `oidc.response.state.{key}`
  stateResponse('response.state'),

  /// Stores requests (mainly frontchannel logout).
  request('request'),

  /// Stores discovery documents and jwks as json
  discoveryDocument('discoveryDocument'),

  /// Identity Tokens, Access tokens, or any other token that requires
  /// secure storage.
  secureTokens('secureTokens');

  const OidcStoreNamespace(this.value);

  final String value;
}

/// An abstract interface for fetching data.
///
/// you can use [package:oidc_default_store](https://pub.dev/packages/oidc_default_store) for a persistent store (for production apps).
///
/// or `OidcMemoryStore` for a memory-only store (for CI/CD or CLI apps).
abstract interface class OidcReadOnlyStore {
  Future<void> init();
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace);

  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  });
}

/// An abstract interface for storing/fetching data.
///
/// you can use [package:oidc_default_store](https://pub.dev/packages/oidc_default_store) for a persistent store (for production apps).
///
/// or `OidcMemoryStore` for a memory-only store (for CI/CD or CLI apps).
abstract interface class OidcStore extends OidcReadOnlyStore {
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
  });
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
  });
}

extension OidcReadOnlyStoreExt on OidcReadOnlyStore {
  /// gets a single key from a namespace.
  Future<String?> get(
    OidcStoreNamespace namespace, {
    required String key,
  }) {
    return getMany(namespace, keys: {key})
        .then((value) => value.values.firstOrNull);
  }

  /// Gets the current state from the session namespace.
  // Future<String?> getCurrentState() => get(
  //       OidcStoreNamespace.session,
  //       key: OidcConstants_AuthParameters.state,
  //     );

  /// Gets the current nonce from the session namespace.
  Future<String?> getCurrentNonce() => get(
        OidcStoreNamespace.secureTokens,
        key: OidcConstants_AuthParameters.nonce,
      );

  /// Gets the stateData (value) of a [state] (key).
  Future<String?> getStateData(String state) => get(
        OidcStoreNamespace.state,
        key: state,
      );

  /// Gets the stateData (value) of a [state] (key).
  Future<String?> getStateResponseData(String state) => get(
        OidcStoreNamespace.stateResponse,
        key: state,
      );

  /// Gets the current
  Future<String?> getCurrentFrontChannelLogoutRequest() => get(
        OidcStoreNamespace.request,
        key: OidcConstants_Store.frontChannelLogout,
      );

  Future<Map<String, ({String stateData, String stateResponse})>>
      getStatesWithResponses() async {
    final responseKeys = await getAllKeys(OidcStoreNamespace.stateResponse);
    if (responseKeys.isEmpty) {
      return {};
    }
    final allResponses =
        await getMany(OidcStoreNamespace.stateResponse, keys: responseKeys);
    if (allResponses.isEmpty) {
      return {};
    }
    final allData = await getMany(
      OidcStoreNamespace.state,
      keys: allResponses.keys.toSet(),
    );
    allResponses.removeWhere((key, value) => !allData.containsKey(key));
    return allResponses.map(
      (key, value) => MapEntry(
        key,
        (stateData: allData[key]!, stateResponse: value),
      ),
    );
  }
}

extension OidcStoreExt on OidcStore {
  /// Sets a single key to the store.
  Future<void> set(
    OidcStoreNamespace namespace, {
    required String key,
    required String value,
  }) {
    return setMany(namespace, values: {key: value});
  }

  /// Removes a single key from the store.
  Future<void> remove(
    OidcStoreNamespace namespace, {
    required String key,
  }) {
    return removeMany(namespace, keys: {key});
  }

  /// Sets the current state from the session namespace.
  ///
  /// Sending null will remove the key.
  // Future<void> setCurrentState(String? state) => state == null
  //     ? remove(
  //         OidcStoreNamespace.session,
  //         key: OidcConstants_AuthParameters.state,
  //       )
  //     : set(
  //         OidcStoreNamespace.session,
  //         key: OidcConstants_AuthParameters.state,
  //         value: state,
  //       );

  /// Sets the current state from the session namespace.
  ///
  /// Sending null will remove the key.
  Future<void> setCurrentNonce(String? nonce) => nonce == null
      ? remove(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_AuthParameters.nonce,
        )
      : set(
          OidcStoreNamespace.secureTokens,
          key: OidcConstants_AuthParameters.nonce,
          value: nonce,
        );

  /// Sets the [stateData] (value) of a [state] (key).
  ///
  /// if [stateData] (value) is null, the [state] (key) will be removed.
  Future<void> setStateData({
    required String state,
    required String? stateData,
  }) =>
      stateData == null
          ? remove(
              OidcStoreNamespace.state,
              key: state,
            )
          : set(
              OidcStoreNamespace.state,
              key: state,
              value: stateData,
            );

  /// Sets the [stateData] (value) of a [state] (key).
  ///
  /// if [stateData] (value) is null, the [state] (key) will be removed.
  Future<void> setStateResponseData({
    required String state,
    required String? stateData,
  }) =>
      stateData == null
          ? remove(
              OidcStoreNamespace.stateResponse,
              key: state,
            )
          : set(
              OidcStoreNamespace.stateResponse,
              key: state,
              value: stateData,
            );

  /// Gets the stateData (value) of a [state] (key).
  Future<void> removeStateResponseData(String state) => setStateData(
        state: state,
        stateData: null,
      );

  /// Gets the current
  Future<void> setCurrentFrontChannelLogoutRequest(String? value) =>
      value == null
          ? remove(
              OidcStoreNamespace.request,
              key: OidcConstants_Store.frontChannelLogout,
            )
          : set(
              OidcStoreNamespace.request,
              key: OidcConstants_Store.frontChannelLogout,
              value: value,
            );
}
