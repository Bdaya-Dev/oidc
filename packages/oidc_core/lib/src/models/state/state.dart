// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/converters.dart';
import 'package:oidc_core/src/state_store.dart';
import 'package:oidc_core/src/utils.dart';

part 'state.g.dart';

/// Base class for any state
@JsonSerializable(
  createFactory: true,
  createToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcState {
  ///
  const OidcState({
    required this.id,
    required this.createdAt,
    this.data,
  });

  ///
  factory OidcState.fromJson(Map<String, dynamic> src) =>
      _$OidcStateFromJson(src);

  ///
  factory OidcState.fromStorageString(String storageString) =>
      OidcState.fromJson(jsonDecode(storageString) as Map<String, dynamic>);

  ///
  @JsonKey(name: 'id')
  final String id;

  ///
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  
  /// custom "state", which can be used by a caller to have "data" round tripped
  ///
  /// it MUST be json encodable.
  @JsonKey(name: 'data')
  final dynamic data;

  ///
  Map<String, dynamic> toJson() => _$OidcStateToJson(this);

  ///
  String toStorageString() => jsonEncode(toJson());

  ///
  static Future<void> clearStaleState({
    required OidcStore store,
    required Duration age,
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(age);
    final keys = await store.getAllKeys(OidcStoreNamespace.state);
    for (final key in keys) {
      final item = await store.get(OidcStoreNamespace.state, key: key);
      var remove = false;
      if (item != null) {
        try {
          final state = OidcState.fromStorageString(item);
          if (state.createdAt.isBefore(cutoff)) {
            remove = true;
          }
        } catch (err) {
          remove = true;
        }
      } else {
        remove = true;
      }

      if (remove) {
        //no need to await
        unawaited(store.remove(OidcStoreNamespace.state, key: key));
      }
    }
  }
}
