// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeState _$OidcAuthorizeStateFromJson(Map<String, dynamic> json) =>
    OidcAuthorizeState(
      skipUserInfo: json['skipUserInfo'] as bool?,
      id: json['id'] as String,
      createdAt:
          const DateTimeEpochConverter().fromJson(json['created_at'] as int),
      requestType: json['request_type'] as String?,
      data: json['data'],
      codeVerifier: json['code_verifier'] as String?,
      codeChallenge: json['code_challenge'] as String?,
      authority: Uri.parse(json['authority'] as String),
      clientId: json['client_id'] as String,
      redirectUri: Uri.parse(json['redirect_uri'] as String),
      scope: json['scope'] as String,
      clientSecret: json['client_secret'] as String?,
      extraTokenParams: json['extraTokenParams'] as Map<String, dynamic>?,
      responseMode: json['response_mode'] as String?,
    );

Map<String, dynamic> _$OidcAuthorizeStateToJson(OidcAuthorizeState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': const DateTimeEpochConverter().toJson(instance.createdAt),
      'request_type': instance.requestType,
      'data': instance.data,
      'code_verifier': instance.codeVerifier,
      'code_challenge': instance.codeChallenge,
      'authority': instance.authority.toString(),
      'client_id': instance.clientId,
      'redirect_uri': instance.redirectUri.toString(),
      'scope': instance.scope,
      'client_secret': instance.clientSecret,
      'extraTokenParams': instance.extraTokenParams,
      'response_mode': instance.responseMode,
      'skipUserInfo': instance.skipUserInfo,
    };
