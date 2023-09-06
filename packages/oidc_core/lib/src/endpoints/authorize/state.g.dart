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
      authorizationRequest: json['authRequest'] as Map<String, dynamic>,
      codeVerifier: json['code_verifier'] as String?,
      originalUri: json['original_uri'] == null
          ? null
          : Uri.parse(json['original_uri'] as String),
      data: json['data'],
    );

Map<String, dynamic> _$OidcAuthorizeStateToJson(OidcAuthorizeState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at':
          const OidcDateTimeEpochConverter().toJson(instance.createdAt),
      'request_type': instance.requestType,
      'data': instance.data,
      'authRequest': instance.authorizationRequest,
      'code_verifier': instance.codeVerifier,
      'original_uri': instance.originalUri?.toString(),
    };
