// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcDeviceAuthorizationResponse _$OidcDeviceAuthorizationResponseFromJson(
        Map<String, dynamic> json) =>
    OidcDeviceAuthorizationResponse._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: Uri.parse(json['verification_uri'] as String),
      verificationUriComplete: json['verification_uri_complete'] == null
          ? null
          : Uri.parse(json['verification_uri_complete'] as String),
      expiresIn: const OidcDurationSecondsConverter()
          .fromJson((json['expires_in'] as num).toInt()),
      interval: _$JsonConverterFromJson<int, Duration>(
          json['interval'], const OidcDurationSecondsConverter().fromJson),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
