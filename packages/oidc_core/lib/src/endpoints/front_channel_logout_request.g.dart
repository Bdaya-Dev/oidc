// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'front_channel_logout_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcFrontChannelLogoutIncomingRequest
    _$OidcFrontChannelLogoutIncomingRequestFromJson(
            Map<String, dynamic> json) =>
        OidcFrontChannelLogoutIncomingRequest._(
          src: readSrcMap(json, '') as Map<String, dynamic>,
          iss: json['iss'] == null ? null : Uri.parse(json['iss'] as String),
          sid: json['sid'] as String?,
        );
