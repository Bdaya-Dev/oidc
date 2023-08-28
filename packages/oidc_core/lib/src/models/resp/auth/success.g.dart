// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'success.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcSuccessAuthResponse _$OidcSuccessAuthResponseFromJson(
        Map<String, dynamic> json) =>
    OidcSuccessAuthResponse(
      code: json['code'] as String?,
      sessionState: json['session_state'] as String?,
      state: json['state'] as String?,
      tokenType: json['token_type'] as String?,
      refreshToken: json['refresh_token'] as String?,
      scope: json['scope'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      expiresIn: json['expires_in'] == null
          ? null
          : Duration(microseconds: json['expires_in'] as int),
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
    );
