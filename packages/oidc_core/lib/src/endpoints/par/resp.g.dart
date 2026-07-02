// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcPushedAuthorizationResponse _$OidcPushedAuthorizationResponseFromJson(
  Map<String, dynamic> json,
) => OidcPushedAuthorizationResponse._(
  src: readSrcMap(json, '') as Map<String, dynamic>,
  requestUri: Uri.parse(json['request_uri'] as String),
  expiresIn: const OidcDurationSecondsConverter().fromJson(
    (json['expires_in'] as num).toInt(),
  ),
);
