// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcClientAuthenticationToJson(
        OidcClientAuthentication instance) =>
    <String, dynamic>{
      'client_id': instance.clientId,
      if (instance.clientSecret case final value?) 'client_secret': value,
      if (instance.clientAssertionType case final value?)
        'client_assertion_type': value,
      if (instance.clientAssertion case final value?) 'client_assertion': value,
    };
