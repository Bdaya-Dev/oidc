import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/models/managers/state_store.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/converters.dart';

part 'state.g.dart';

/// Base class for any state
@JsonSerializable(
  createFactory: true,
  createToJson: true,
  converters: [
    DateTimeEpochConverter(),
  ],
)
class OidcState {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Descripes the request that lead to the generation of this state
  /// E.g.:  "si:r" => signIn:redirect, "si:p" => signIn:popup
  @JsonKey(name: 'request_type')
  final String? requestType;

  /// custom "state", which can be used by a caller to have "data" round tripped
  ///
  /// it MUST be json encodable.
  @JsonKey(name: 'data')
  final dynamic data;

  const OidcState({
    required this.id,
    required this.createdAt,
    this.requestType,
    this.data,
  });

  /// if id is null, it will generate a UUID v4.
  ///
  /// if createdAt is null, it will default to [DateTime.now().toUtc()]
  factory OidcState.fromDefaults({
    String? id,
    DateTime? createdAt,
    String? requestType,
    dynamic data,
  }) {
    createdAt ??= DateTime.now().toUtc();
    id ??= const Uuid().v4();
    return OidcState(
      id: id,
      createdAt: createdAt,
      data: data,
      requestType: requestType,
    );
  }

  Map<String, dynamic> toJson() => _$OidcStateToJson(this);

  factory OidcState.fromJson(Map<String, dynamic> src) =>
      _$OidcStateFromJson(src);

  String toStorageString() => jsonEncode(toJson());

  factory OidcState.fromStorageString(String storageString) =>
      OidcState.fromJson(jsonDecode(storageString));

  static Future<void> clearStaleState(
    OidcStateStore store,
    Duration age,
  ) async {
    final cutoff = DateTime.now().toUtc().subtract(age);
    final keys = await store.getAllKeys();
    for (var key in keys) {
      final item = await store.get(key);
      bool remove = false;

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
        store.remove(key);
      }
    }
  }
}
