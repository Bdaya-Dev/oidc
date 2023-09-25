// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:uuid/uuid.dart';

part 'state.g.dart';

/// Base class for any state
@JsonSerializable(
  createFactory: false,
  createToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcState {
  ///
  OidcState({
    required this.operationDiscriminator,
    String? id,
    DateTime? createdAt,
    this.data,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? clock.now();

  ///
  factory OidcState.fromStorageString(String storageString) {
    final src = jsonDecode(storageString) as Map<String, dynamic>;
    switch (src[OidcConstants_Store.operationDiscriminator]) {
      case OidcConstants_OperationDiscriminators.authorize:
        return OidcAuthorizeState.fromJson(src);
      case OidcConstants_OperationDiscriminators.endSession:
        return OidcEndSessionState.fromJson(src);
      default:
        throw const OidcException('unknown state type.');
    }
  }

  ///
  @JsonKey(name: 'id')
  final String id;

  ///
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  ///
  @JsonKey(
    name: OidcConstants_Store.operationDiscriminator,
    includeToJson: true,
    includeFromJson: true,
  )
  final String operationDiscriminator;

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
    final cutoff = clock.now().toUtc().subtract(age);
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
        unawaited(store.remove(OidcStoreNamespace.stateResponse, key: key));
      }
    }
  }
}
