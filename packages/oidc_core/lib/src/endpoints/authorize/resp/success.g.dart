// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'success.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeResponseSuccess _$OidcAuthorizeResponseSuccessFromJson(
        Map<String, dynamic> json) =>
    OidcAuthorizeResponseSuccess(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      code: json['code'] as String?,
      sessionState: json['session_state'] as String?,
      state: json['state'] as String?,
      tokenType: json['token_type'] as String?,
      scope: json['scope'] == null
          ? const []
          : splitSpaceDelimitedString(json['scope'] as String?),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      expiresIn: json['expires_in'] == null
          ? null
          : Duration(microseconds: json['expires_in'] as int),
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
    );
