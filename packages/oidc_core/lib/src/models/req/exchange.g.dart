// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcExchangeCodeRequestToJson(
        OidcExchangeCodeRequest instance) =>
    <String, dynamic>{
      'redirect_uri': instance.redirectUri?.toString(),
      'grant_type': instance.grantType,
      'code': instance.code,
      'code_verifier': instance.codeVerifier,
    };

Map<String, dynamic> _$OidcExchangeCredentialsRequestToJson(
        OidcExchangeCredentialsRequest instance) =>
    <String, dynamic>{};

Map<String, dynamic> _$OidcExchangeRefreshTokenRequestToJson(
        OidcExchangeRefreshTokenRequest instance) =>
    <String, dynamic>{};

Map<String, dynamic> _$OidcRevokeTokenRequestToJson(
        OidcRevokeTokenRequest instance) =>
    <String, dynamic>{};
