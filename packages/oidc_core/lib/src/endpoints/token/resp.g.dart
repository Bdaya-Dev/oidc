// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcTokenResponse _$OidcTokenResponseFromJson(Map<String, dynamic> json) =>
    OidcTokenResponse(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String,
      scope: json['scope'] == null
          ? const []
          : OidcInternalUtilities.splitSpaceDelimitedString(
              json['scope'] as String?),
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          json['expires_in'], const OidcDurationSecondsConverter().fromJson),
      expiresAt: _$JsonConverterFromJson<int, DateTime>(
          OidcInternalUtilities.readDateTime(json, 'expires_at'),
          const OidcDateTimeEpochConverter().fromJson),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
