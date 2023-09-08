// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcUserMetadata _$OidcUserMetadataFromJson(Map<String, dynamic> json) =>
    OidcUserMetadata._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      scope: OidcInternalUtilities.splitSpaceDelimitedString(
          json['scope'] as String?),
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          OidcInternalUtilities.readDurationSeconds(json, 'expires_in'),
          const OidcDurationSecondsConverter().fromJson),
      expiresInReferenceDate: OidcInternalUtilities.dateTimeFromJson(
          json['expiresInReferenceDate']),
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
      'scope': OidcInternalUtilities.joinSpaceDelimitedList(instance.scope),
      'expires_in': _$JsonConverterToJson<int, Duration>(
          instance.expiresIn, const OidcDurationSecondsConverter().toJson),
      'expiresInReferenceDate':
          OidcInternalUtilities.dateTimeToJson(instance.expiresInReferenceDate),
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
