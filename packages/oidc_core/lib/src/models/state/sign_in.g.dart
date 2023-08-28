// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_in.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcSignInState _$OidcSignInStateFromJson(Map<String, dynamic> json) =>
    OidcSignInState(
      skipUserInfo: json['skipUserInfo'] as bool?,
      id: json['id'] as String,
      createdAt:
          const DateTimeEpochConverter().fromJson(json['created_at'] as int),
      requestType: json['request_type'] as String?,
      data: json['data'],
      codeVerifier: json['code_verifier'] as String?,
      codeChallenge: json['code_challenge'] as String?,
      authority: const UriJsonConverter().fromJson(json['authority'] as String),
      clientId: json['client_id'] as String,
      redirectUri:
          const UriJsonConverter().fromJson(json['redirect_uri'] as String),
      scope: json['scope'] as String,
      clientSecret: json['client_secret'] as String?,
      extraTokenParams: json['extraTokenParams'] as Map<String, dynamic>?,
      responseMode:
          $enumDecodeNullable(_$OidcResponseModeEnumMap, json['response_mode']),
    );

Map<String, dynamic> _$OidcSignInStateToJson(OidcSignInState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': const DateTimeEpochConverter().toJson(instance.createdAt),
      'request_type': instance.requestType,
      'data': instance.data,
      'code_verifier': instance.codeVerifier,
      'code_challenge': instance.codeChallenge,
      'authority': const UriJsonConverter().toJson(instance.authority),
      'client_id': instance.clientId,
      'redirect_uri': const UriJsonConverter().toJson(instance.redirectUri),
      'scope': instance.scope,
      'client_secret': instance.clientSecret,
      'extraTokenParams': instance.extraTokenParams,
      'response_mode': _$OidcResponseModeEnumMap[instance.responseMode],
      'skipUserInfo': instance.skipUserInfo,
    };

const _$OidcResponseModeEnumMap = {
  OidcResponseMode.query: 'query',
  OidcResponseMode.fragment: 'fragment',
};
