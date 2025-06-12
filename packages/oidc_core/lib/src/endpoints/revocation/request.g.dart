// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcRevocationRequestToJson(
        OidcRevocationRequest instance) =>
    <String, dynamic>{
      'token': instance.token,
      if (instance.tokenTypeHint case final value?) 'token_type_hint': value,
      if (instance.clientId case final value?) 'client_id': value,
      if (instance.clientSecret case final value?) 'client_secret': value,
    };
