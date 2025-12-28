// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcTokenRequestToJson(OidcTokenRequest instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'code': ?instance.code,
      'client_id': ?instance.clientId,
      'client_secret': ?instance.clientSecret,
      'code_verifier': ?instance.codeVerifier,
      'username': ?instance.username,
      'password': ?instance.password,
      'assertion': ?instance.assertion,
      'audience': ?instance.audience,
      'subject_token_type': ?instance.subjectTokenType,
      'subject_token': ?instance.subjectToken,
      'actor_token_type': ?instance.actorTokenType,
      'actor_token': ?instance.actorToken,
      'device_code': ?instance.deviceCode,
      'redirect_uri': ?instance.redirectUri?.toString(),
      'refresh_token': ?instance.refreshToken,
      'scope': ?OidcInternalUtilities.joinSpaceDelimitedList(instance.scope),
    };
