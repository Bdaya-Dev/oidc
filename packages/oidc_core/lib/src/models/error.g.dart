// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcErrorResponse _$OidcErrorResponseFromJson(Map<String, dynamic> json) =>
    OidcErrorResponse(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      error: json['error'] as String,
      errorDescription: json['error_description'] as String?,
      errorUri: json['error_uri'] == null
          ? null
          : Uri.parse(json['error_uri'] as String),
      iss: json['iss'] == null ? null : Uri.parse(json['iss'] as String),
      sessionState: json['session_state'] as String?,
      state: json['state'] as String?,
    );
