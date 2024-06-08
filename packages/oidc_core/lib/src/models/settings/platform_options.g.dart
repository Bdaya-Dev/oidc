// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcPlatformSpecificOptions _$OidcPlatformSpecificOptionsFromJson(
        Map<String, dynamic> json) =>
    OidcPlatformSpecificOptions(
      android: json['android'] == null
          ? const OidcPlatformSpecificOptions_AppAuth_Android()
          : OidcPlatformSpecificOptions_AppAuth_Android.fromJson(
              json['android'] as Map<String, dynamic>),
      ios: json['ios'] == null
          ? const OidcPlatformSpecificOptions_AppAuth_IosMacos()
          : OidcPlatformSpecificOptions_AppAuth_IosMacos.fromJson(
              json['ios'] as Map<String, dynamic>),
      macos: json['macos'] == null
          ? const OidcPlatformSpecificOptions_AppAuth_IosMacos()
          : OidcPlatformSpecificOptions_AppAuth_IosMacos.fromJson(
              json['macos'] as Map<String, dynamic>),
      web: json['web'] == null
          ? const OidcPlatformSpecificOptions_Web()
          : OidcPlatformSpecificOptions_Web.fromJson(
              json['web'] as Map<String, dynamic>),
      windows: json['windows'] == null
          ? const OidcPlatformSpecificOptions_Native()
          : OidcPlatformSpecificOptions_Native.fromJson(
              json['windows'] as Map<String, dynamic>),
      linux: json['linux'] == null
          ? const OidcPlatformSpecificOptions_Native()
          : OidcPlatformSpecificOptions_Native.fromJson(
              json['linux'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$OidcPlatformSpecificOptionsToJson(
        OidcPlatformSpecificOptions instance) =>
    <String, dynamic>{
      'android': instance.android,
      'ios': instance.ios,
      'macos': instance.macos,
      'web': instance.web,
      'linux': instance.linux,
      'windows': instance.windows,
    };

OidcPlatformSpecificOptions_AppAuth_Android
    _$OidcPlatformSpecificOptions_AppAuth_AndroidFromJson(
            Map<String, dynamic> json) =>
        OidcPlatformSpecificOptions_AppAuth_Android(
          allowInsecureConnections:
              json['allowInsecureConnections'] as bool? ?? false,
        );

Map<String, dynamic> _$OidcPlatformSpecificOptions_AppAuth_AndroidToJson(
        OidcPlatformSpecificOptions_AppAuth_Android instance) =>
    <String, dynamic>{
      'allowInsecureConnections': instance.allowInsecureConnections,
    };

OidcPlatformSpecificOptions_AppAuth_IosMacos
    _$OidcPlatformSpecificOptions_AppAuth_IosMacosFromJson(
            Map<String, dynamic> json) =>
        OidcPlatformSpecificOptions_AppAuth_IosMacos(
          preferEphemeralSession:
              json['preferEphemeralSession'] as bool? ?? false,
        );

Map<String, dynamic> _$OidcPlatformSpecificOptions_AppAuth_IosMacosToJson(
        OidcPlatformSpecificOptions_AppAuth_IosMacos instance) =>
    <String, dynamic>{
      'preferEphemeralSession': instance.preferEphemeralSession,
    };

OidcPlatformSpecificOptions_Native _$OidcPlatformSpecificOptions_NativeFromJson(
        Map<String, dynamic> json) =>
    OidcPlatformSpecificOptions_Native(
      successfulPageResponse: json['successfulPageResponse'] as String?,
      methodMismatchResponse: json['methodMismatchResponse'] as String?,
      notFoundResponse: json['notFoundResponse'] as String?,
    );

Map<String, dynamic> _$OidcPlatformSpecificOptions_NativeToJson(
        OidcPlatformSpecificOptions_Native instance) =>
    <String, dynamic>{
      'successfulPageResponse': instance.successfulPageResponse,
      'methodMismatchResponse': instance.methodMismatchResponse,
      'notFoundResponse': instance.notFoundResponse,
    };

OidcPlatformSpecificOptions_Web _$OidcPlatformSpecificOptions_WebFromJson(
        Map<String, dynamic> json) =>
    OidcPlatformSpecificOptions_Web(
      navigationMode: $enumDecodeNullable(
              _$OidcPlatformSpecificOptions_Web_NavigationModeEnumMap,
              json['navigationMode']) ??
          OidcPlatformSpecificOptions_Web_NavigationMode.newPage,
      popupWidth: (json['popupWidth'] as num?)?.toDouble() ?? 700,
      popupHeight: (json['popupHeight'] as num?)?.toDouble() ?? 750,
      broadcastChannel: json['broadcastChannel'] as String? ??
          OidcPlatformSpecificOptions_Web.defaultBroadcastChannel,
      hiddenIframeTimeout: json['hiddenIframeTimeout'] == null
          ? const Duration(seconds: 10)
          : Duration(
              microseconds: (json['hiddenIframeTimeout'] as num).toInt()),
    );

Map<String, dynamic> _$OidcPlatformSpecificOptions_WebToJson(
        OidcPlatformSpecificOptions_Web instance) =>
    <String, dynamic>{
      'navigationMode': _$OidcPlatformSpecificOptions_Web_NavigationModeEnumMap[
          instance.navigationMode],
      'popupWidth': instance.popupWidth,
      'popupHeight': instance.popupHeight,
      'broadcastChannel': instance.broadcastChannel,
      'hiddenIframeTimeout': instance.hiddenIframeTimeout.inMicroseconds,
    };

const _$OidcPlatformSpecificOptions_Web_NavigationModeEnumMap = {
  OidcPlatformSpecificOptions_Web_NavigationMode.samePage: 'samePage',
  OidcPlatformSpecificOptions_Web_NavigationMode.newPage: 'newPage',
  OidcPlatformSpecificOptions_Web_NavigationMode.popup: 'popup',
  OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame: 'hiddenIFrame',
};
