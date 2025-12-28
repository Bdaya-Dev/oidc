// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcToken _$OidcTokenFromJson(Map<String, dynamic> json) {
  $checkKeys(json, disallowNullValues: const ['expiresInReferenceDate']);
  return OidcToken(
    creationTime: OidcInternalUtilities.dateTimeFromJsonRequired(
      json['expiresInReferenceDate'],
    ),
    scope: OidcInternalUtilities.splitSpaceDelimitedStringNullable(
      json['scope'],
    ),
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
  'scope': ?OidcInternalUtilities.joinSpaceDelimitedList(instance.scope),
  'access_token': ?instance.accessToken,
  'token_type': ?instance.tokenType,
  'id_token': ?instance.idToken,
  'expires_in': ?OidcInternalUtilities.durationToJson(instance.expiresIn),
  'refresh_token': ?instance.refreshToken,
  'expiresInReferenceDate': ?OidcInternalUtilities.dateTimeToJson(
    instance.creationTime,
  ),
  'session_state': ?instance.sessionState,
};
