// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeResponse _$OidcAuthorizeResponseFromJson(
        Map<String, dynamic> json) =>
    OidcAuthorizeResponse(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      code: json['code'] as String?,
      sessionState: json['session_state'] as String?,
      state: json['state'] as String?,
      iss: json['iss'] == null ? null : Uri.parse(json['iss'] as String),
      scope: json['scope'] == null
          ? const []
          : splitSpaceDelimitedString(json['scope'] as String?),
      tokenType: json['token_type'] as String?,
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          json['expires_in'], const DurationSecondsConverter().fromJson),
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
