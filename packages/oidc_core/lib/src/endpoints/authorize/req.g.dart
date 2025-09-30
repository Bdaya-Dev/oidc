// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcAuthorizeRequestToJson(
  OidcAuthorizeRequest instance,
) => <String, dynamic>{
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.scope)
      case final value?)
    'scope': value,
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.responseType)
      case final value?)
    'response_type': value,
  'client_id': instance.clientId,
  'redirect_uri': instance.redirectUri.toString(),
  if (instance.state case final value?) 'state': value,
  if (instance.responseMode case final value?) 'response_mode': value,
  if (instance.nonce case final value?) 'nonce': value,
  if (instance.display case final value?) 'display': value,
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.prompt)
      case final value?)
    'prompt': value,
  if (_$JsonConverterToJson<int, Duration>(
        instance.maxAge,
        const OidcDurationSecondsConverter().toJson,
      )
      case final value?)
    'max_age': value,
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.uiLocales)
      case final value?)
    'ui_locales': value,
  if (instance.idTokenHint case final value?) 'id_token_hint': value,
  if (instance.loginHint case final value?) 'login_hint': value,
  if (OidcInternalUtilities.joinSpaceDelimitedList(instance.acrValues)
      case final value?)
    'acr_values': value,
  if (instance.codeChallenge case final value?) 'code_challenge': value,
  if (instance.codeChallengeMethod case final value?)
    'code_challenge_method': value,
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
