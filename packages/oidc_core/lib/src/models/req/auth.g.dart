// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcAuthRequestArgsToJson(OidcAuthRequestArgs instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('scope', spaceDelimitedToJson(instance.scope));
  writeNotNull('response_type', spaceDelimitedToJson(instance.responseType));
  val['client_id'] = instance.clientId;
  val['redirect_uri'] = const UriJsonConverter().toJson(instance.redirectUri);
  val['state'] = _stateToJson(instance.state);
  writeNotNull(
      'response_mode', _$OidcResponseModeEnumMap[instance.responseMode]);
  writeNotNull('nonce', instance.nonce);
  writeNotNull('display', instance.display);
  writeNotNull('prompt', spaceDelimitedToJson(instance.prompt));
  writeNotNull(
      'max_age',
      _$JsonConverterToJson<int, Duration>(
          instance.maxAge, const DurationSecondsConverter().toJson));
  writeNotNull('ui_locales', spaceDelimitedToJson(instance.uiLocales));
  writeNotNull('id_token_hint', instance.idTokenHint);
  writeNotNull('login_hint', instance.loginHint);
  writeNotNull('acr_values', spaceDelimitedToJson(instance.acrValues));
  val['resource'] = instance.resource;
  writeNotNull('request', instance.request);
  writeNotNull(
      'request_uri',
      _$JsonConverterToJson<String, Uri>(
          instance.requestUri, const UriJsonConverter().toJson));
  return val;
}

const _$OidcResponseModeEnumMap = {
  OidcResponseMode.query: 'query',
  OidcResponseMode.fragment: 'fragment',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
