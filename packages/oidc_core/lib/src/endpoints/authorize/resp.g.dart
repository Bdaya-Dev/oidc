// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeResponse _$OidcAuthorizeResponseFromJson(
        Map<String, dynamic> json) =>
    OidcAuthorizeResponse._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      codeVerifier: json['code_verifier'] as String?,
      redirectUri: json['redirect_uri'] == null
          ? null
          : Uri.parse(json['redirect_uri'] as String),
      code: json['code'] as String?,
      sessionState: json['session_state'] as String?,
      state: json['state'] as String?,
      iss: json['iss'] == null ? null : Uri.parse(json['iss'] as String),
      nonce: json['nonce'] as String?,
      scope: json['scope'] == null
          ? const []
          : OidcInternalUtilities.splitSpaceDelimitedString(json['scope']),
      tokenType: json['token_type'] as String?,
      expiresIn: _$JsonConverterFromJson<int, Duration>(
          OidcInternalUtilities.readDurationSeconds(json, 'expires_in'),
          const OidcDurationSecondsConverter().fromJson),
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
