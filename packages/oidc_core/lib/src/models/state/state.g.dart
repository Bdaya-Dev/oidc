// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcState _$OidcStateFromJson(Map<String, dynamic> json) => OidcState(
      id: json['id'] as String,
      createdAt: const OidcDateTimeEpochConverter()
          .fromJson(json['created_at'] as int),
      requestType: json['request_type'] as String?,
      data: json['data'],
    );

Map<String, dynamic> _$OidcStateToJson(OidcState instance) => <String, dynamic>{
      'id': instance.id,
      'created_at':
          const OidcDateTimeEpochConverter().toJson(instance.createdAt),
      'request_type': instance.requestType,
      'data': instance.data,
    };
