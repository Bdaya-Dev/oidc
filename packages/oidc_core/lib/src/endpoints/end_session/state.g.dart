// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcEndSessionState _$OidcEndSessionStateFromJson(Map<String, dynamic> json) =>
    OidcEndSessionState(
      postLogoutRedirectUri:
          Uri.parse(json['post_logout_redirect_uri'] as String),
      originalUri: json['original_uri'] == null
          ? null
          : Uri.parse(json['original_uri'] as String),
      options: json['options'] as Map<String, dynamic>?,
      createdAt: _$JsonConverterFromJson<int, DateTime>(
          json['created_at'], const OidcNumericDateConverter().fromJson),
      data: json['data'],
      id: json['id'] as String?,
    );

Map<String, dynamic> _$OidcEndSessionStateToJson(
        OidcEndSessionState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': const OidcNumericDateConverter().toJson(instance.createdAt),
      'operationDiscriminator': instance.operationDiscriminator,
      'data': instance.data,
      'options': instance.options,
      'post_logout_redirect_uri': instance.postLogoutRedirectUri.toString(),
      'original_uri': instance.originalUri?.toString(),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
