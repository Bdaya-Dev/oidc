// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcAuthorizeRequestToJson(
    OidcAuthorizeRequest instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull(
      'scope', OidcInternalUtilities.joinSpaceDelimitedList(instance.scope));
  writeNotNull('response_type',
      OidcInternalUtilities.joinSpaceDelimitedList(instance.responseType));
  val['client_id'] = instance.clientId;
  val['redirect_uri'] = instance.redirectUri.toString();
  writeNotNull('state', instance.state);
  writeNotNull('response_mode', instance.responseMode);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('display', instance.display);
  writeNotNull(
      'prompt', OidcInternalUtilities.joinSpaceDelimitedList(instance.prompt));
  writeNotNull(
      'max_age',
      _$JsonConverterToJson<int, Duration>(
          instance.maxAge, const OidcDurationSecondsConverter().toJson));
  writeNotNull('ui_locales',
      OidcInternalUtilities.joinSpaceDelimitedList(instance.uiLocales));
  writeNotNull('id_token_hint', instance.idTokenHint);
  writeNotNull('login_hint', instance.loginHint);
  writeNotNull('acr_values',
      OidcInternalUtilities.joinSpaceDelimitedList(instance.acrValues));
  writeNotNull('code_challenge', instance.codeChallenge);
  writeNotNull('code_challenge_method', instance.codeChallengeMethod);
  return val;
}

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
