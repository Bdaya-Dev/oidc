// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcTokenResponse _$OidcTokenResponseFromJson(Map<String, dynamic> json) =>
    OidcTokenResponse._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      tokenType: json['token_type'] as String?,
      accessToken: json['access_token'] as String?,
      scope: json['scope'] == null
          ? const []
          : OidcInternalUtilities.splitSpaceDelimitedString(json['scope']),
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          OidcInternalUtilities.readDurationSeconds(json, 'expires_in'),
          const OidcDurationSecondsConverter().fromJson),
      expiresAt: OidcInternalUtilities.dateTimeFromJson(json['expires_at']),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
