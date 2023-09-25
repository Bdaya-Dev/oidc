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
      scope: OidcInternalUtilities.splitSpaceDelimitedStringNullable(
          json['scope']),
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: OidcInternalUtilities.durationFromJson(json['expires_in']),
      sessionState: json['session_state'] as String?,
    );
