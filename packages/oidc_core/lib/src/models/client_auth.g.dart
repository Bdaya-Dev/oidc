// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcClientAuthenticationToJson(
    OidcClientAuthentication instance) {
  final val = <String, dynamic>{
    'client_id': instance.clientId,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('client_secret', instance.clientSecret);
  writeNotNull('client_assertion_type', instance.clientAssertionType);
  writeNotNull('client_assertion', instance.clientAssertion);
  return val;
}
