// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcAuthorizeRequestToJson(
  OidcAuthorizeRequest instance,
) => <String, dynamic>{
  'scope': ?OidcInternalUtilities.joinSpaceDelimitedList(instance.scope),
  'response_type': ?OidcInternalUtilities.joinSpaceDelimitedList(
    instance.responseType,
  ),
  'client_id': instance.clientId,
  'redirect_uri': instance.redirectUri.toString(),
  'state': ?instance.state,
  'response_mode': ?instance.responseMode,
  'nonce': ?instance.nonce,
  'display': ?instance.display,
  'prompt': ?OidcInternalUtilities.joinSpaceDelimitedList(instance.prompt),
  'max_age': ?_$JsonConverterToJson<int, Duration>(
    instance.maxAge,
    const OidcDurationSecondsConverter().toJson,
  ),
  'ui_locales': ?OidcInternalUtilities.joinSpaceDelimitedList(
    instance.uiLocales,
  ),
  'id_token_hint': ?instance.idTokenHint,
  'login_hint': ?instance.loginHint,
  'acr_values': ?OidcInternalUtilities.joinSpaceDelimitedList(
    instance.acrValues,
  ),
  'code_challenge': ?instance.codeChallenge,
  'code_challenge_method': ?instance.codeChallengeMethod,
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
