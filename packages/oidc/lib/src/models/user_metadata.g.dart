// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcUserMetadata _$OidcUserMetadataFromJson(Map<String, dynamic> json) =>
    OidcUserMetadata._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      scope:
          (json['scope'] as List<dynamic>?)?.map((e) => e as String).toList(),
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          json['expires_in'], const OidcDurationSecondsConverter().fromJson),
      expiresInReferenceDate: _$JsonConverterFromJson<int, DateTime>(
          json['expiresInReferenceDate'],
          const OidcDateTimeEpochConverter().fromJson),
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String?,
    );

const _$OidcUserMetadataFieldMap = <String, String>{
  'accessToken': 'access_token',
  'refreshToken': 'refresh_token',
  'tokenType': 'token_type',
  'scope': 'scope',
  'expiresIn': 'expires_in',
  'expiresInReferenceDate': 'expiresInReferenceDate',
};

Map<String, dynamic> _$OidcUserMetadataToJson(OidcUserMetadata instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'scope': instance.scope,
      'expires_in': _$JsonConverterToJson<int, Duration>(
          instance.expiresIn, const OidcDurationSecondsConverter().toJson),
      'expiresInReferenceDate': _$JsonConverterToJson<int, DateTime>(
          instance.expiresInReferenceDate,
          const OidcDateTimeEpochConverter().toJson),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
