// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeState _$OidcAuthorizeStateFromJson(Map<String, dynamic> json) =>
    OidcAuthorizeState(
      id: json['id'] as String,
      createdAt: const OidcDateTimeEpochConverter()
          .fromJson(json['created_at'] as int),
      requestType: json['request_type'] as String?,
      redirectUri: Uri.parse(json['redirect_uri'] as String),
      codeVerifier: json['code_verifier'] as String?,
      codeChallenge: json['code_challenge'] as String?,
      originalUri: json['original_uri'] == null
          ? null
          : Uri.parse(json['original_uri'] as String),
      nonce: json['nonce'] as String,
      clientId: json['client_id'] as String,
      extraTokenParams: json['extraTokenParams'] as Map<String, dynamic>?,
      webLaunchMode: json['webLaunchMode'] as String?,
      data: json['data'],
    );

Map<String, dynamic> _$OidcAuthorizeStateToJson(OidcAuthorizeState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at':
          const OidcDateTimeEpochConverter().toJson(instance.createdAt),
      'request_type': instance.requestType,
      'data': instance.data,
      'extraTokenParams': instance.extraTokenParams,
      'webLaunchMode': instance.webLaunchMode,
      'code_challenge': instance.codeChallenge,
      'code_verifier': instance.codeVerifier,
      'redirect_uri': instance.redirectUri.toString(),
      'client_id': instance.clientId,
      'original_uri': instance.originalUri?.toString(),
      'nonce': instance.nonce,
    };
