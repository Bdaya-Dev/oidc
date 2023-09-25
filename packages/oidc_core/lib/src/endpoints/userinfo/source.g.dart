// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcAggregatedClaimSource _$OidcAggregatedClaimSourceFromJson(
        Map<String, dynamic> json) =>
    OidcAggregatedClaimSource._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      jwt: json['JWT'] as String,
    );

OidcDistributedClaimSource _$OidcDistributedClaimSourceFromJson(
        Map<String, dynamic> json) =>
    OidcDistributedClaimSource._(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      endpoint: Uri.parse(json['endpoint'] as String),
      accessToken: json['access_token'] as String?,
    );
