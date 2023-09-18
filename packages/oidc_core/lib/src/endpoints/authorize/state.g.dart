// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAuthorizeState _$OidcAuthorizeStateFromJson(Map<String, dynamic> json) =>
    OidcAuthorizeState(
      redirectUri: Uri.parse(json['redirect_uri'] as String),
      codeVerifier: json['code_verifier'] as String?,
      codeChallenge: json['code_challenge'] as String?,
      originalUri: json['original_uri'] == null
          ? null
          : Uri.parse(json['original_uri'] as String),
      nonce: json['nonce'] as String,
      clientId: json['client_id'] as String,
      extraTokenParams: json['extraTokenParams'] as Map<String, dynamic>?,
      extraTokenHeaders:
          (json['extraTokenHeaders'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      options: json['options'] as Map<String, dynamic>?,
      id: json['id'] as String?,
      createdAt: _$JsonConverterFromJson<int, DateTime>(
          json['created_at'], const OidcNumericDateConverter().fromJson),
      data: json['data'],
    );

Map<String, dynamic> _$OidcAuthorizeStateToJson(OidcAuthorizeState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': const OidcNumericDateConverter().toJson(instance.createdAt),
      'operationDiscriminator': instance.operationDiscriminator,
      'data': instance.data,
      'extraTokenHeaders': instance.extraTokenHeaders,
      'extraTokenParams': instance.extraTokenParams,
      'options': instance.options,
      'code_challenge': instance.codeChallenge,
      'code_verifier': instance.codeVerifier,
      'redirect_uri': instance.redirectUri.toString(),
      'client_id': instance.clientId,
      'original_uri': instance.originalUri?.toString(),
      'nonce': instance.nonce,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
