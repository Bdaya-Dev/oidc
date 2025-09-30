// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcTokenRequestToJson(
  OidcTokenRequest instance,
) => <String, dynamic>{
  'grant_type': instance.grantType,
  if (instance.code case final value?) 'code': value,
  if (instance.clientId case final value?) 'client_id': value,
  if (instance.clientSecret case final value?) 'client_secret': value,
  if (instance.codeVerifier case final value?) 'code_verifier': value,
  if (instance.username case final value?) 'username': value,
  if (instance.password case final value?) 'password': value,
  if (instance.assertion case final value?) 'assertion': value,
  if (instance.audience case final value?) 'audience': value,
  if (instance.subjectTokenType case final value?) 'subject_token_type': value,
  if (instance.subjectToken case final value?) 'subject_token': value,
  if (instance.actorTokenType case final value?) 'actor_token_type': value,
  if (instance.actorToken case final value?) 'actor_token': value,
  if (instance.deviceCode case final value?) 'device_code': value,
  if (instance.redirectUri?.toString() case final value?) 'redirect_uri': value,
  if (instance.refreshToken case final value?) 'refresh_token': value,
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.scope)
      case final value?)
    'scope': value,
};
