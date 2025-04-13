// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcToken _$OidcTokenFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    disallowNullValues: const ['expiresInReferenceDate'],
  );
  return OidcToken(
    creationTime: OidcInternalUtilities.dateTimeFromJsonRequired(
        json['expiresInReferenceDate']),
    scope:
        OidcInternalUtilities.splitSpaceDelimitedStringNullable(json['scope']),
    accessToken: json['access_token'] as String?,
    tokenType: json['token_type'] as String?,
    idToken: json['id_token'] as String?,
    expiresIn: OidcInternalUtilities.durationFromJson(json['expires_in']),
    refreshToken: json['refresh_token'] as String?,
    extra: _readExtra(json, 'extra') as Map<String, dynamic>?,
    sessionState: json['session_state'] as String?,
  );
}

const _$OidcTokenFieldMap = <String, String>{
  'scope': 'scope',
  'accessToken': 'access_token',
  'tokenType': 'token_type',
  'idToken': 'id_token',
  'expiresIn': 'expires_in',
  'refreshToken': 'refresh_token',
  'creationTime': 'expiresInReferenceDate',
  'sessionState': 'session_state',
};

Map<String, dynamic> _$OidcTokenToJson(OidcToken instance) => <String, dynamic>{
      if (OidcInternalUtilities.joinSpaceDelimitedList(instance.scope)
          case final value?)
        'scope': value,
      if (instance.accessToken case final value?) 'access_token': value,
      if (instance.tokenType case final value?) 'token_type': value,
      if (instance.idToken case final value?) 'id_token': value,
      if (OidcInternalUtilities.durationToJson(instance.expiresIn)
          case final value?)
        'expires_in': value,
      if (instance.refreshToken case final value?) 'refresh_token': value,
      if (OidcInternalUtilities.dateTimeToJson(instance.creationTime)
          case final value?)
        'expiresInReferenceDate': value,
      if (instance.sessionState case final value?) 'session_state': value,
    };
