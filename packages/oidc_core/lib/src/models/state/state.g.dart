// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcState _$OidcStateFromJson(Map<String, dynamic> json) => OidcState(
      id: json['id'] as String,
      createdAt:
          const OidcNumericDateConverter().fromJson(json['created_at'] as int),
      data: json['data'],
    );

Map<String, dynamic> _$OidcStateToJson(OidcState instance) => <String, dynamic>{
      'id': instance.id,
      'created_at': const OidcNumericDateConverter().toJson(instance.createdAt),
      'data': instance.data,
    };
