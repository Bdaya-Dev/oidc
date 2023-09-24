// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcUserInfoResponse _$OidcUserInfoResponseFromJson(
        Map<String, dynamic> json) =>
    OidcUserInfoResponse._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      sub: json['sub'] as String?,
      nbf: _$JsonConverterFromJson<int, DateTime>(
          json['nbf'], const OidcNumericDateConverter().fromJson),
      iat: _$JsonConverterFromJson<int, DateTime>(
          json['iat'], const OidcNumericDateConverter().fromJson),
      jti: json['jti'] as String?,
      iss: json['iss'] as String?,
      aud: json['aud'] == null
          ? const []
          : OidcInternalUtilities.splitSpaceDelimitedString(json['aud']),
      exp: _$JsonConverterFromJson<int, DateTime>(
          json['exp'], const OidcNumericDateConverter().fromJson),
      claimNames: (json['_claim_names'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      claimSources: (json['_claim_sources'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, OidcClaimSource.fromJson(e as Map<String, dynamic>)),
      ),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
