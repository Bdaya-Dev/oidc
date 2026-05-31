// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcPlatformSpecificOptions _$OidcPlatformSpecificOptionsFromJson(
  Map<String, dynamic> json,
) => OidcPlatformSpecificOptions(
  android: json['android'] == null
      ? const OidcNativeOptionsAndroid()
      : OidcNativeOptionsAndroid.fromJson(
          json['android'] as Map<String, dynamic>,
        ),
  ios: json['ios'] == null
      ? const OidcNativeOptionsApple()
      : OidcNativeOptionsApple.fromJson(json['ios'] as Map<String, dynamic>),
  macos: json['macos'] == null
      ? const OidcNativeOptionsApple()
      : OidcNativeOptionsApple.fromJson(json['macos'] as Map<String, dynamic>),
  web: json['web'] == null
      ? const OidcPlatformSpecificOptions_Web()
      : OidcPlatformSpecificOptions_Web.fromJson(
          json['web'] as Map<String, dynamic>,
        ),
  windows: json['windows'] == null
      ? const OidcPlatformSpecificOptions_Native()
      : OidcPlatformSpecificOptions_Native.fromJson(
          json['windows'] as Map<String, dynamic>,
        ),
  linux: json['linux'] == null
      ? const OidcPlatformSpecificOptions_Native()
      : OidcPlatformSpecificOptions_Native.fromJson(
          json['linux'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$OidcPlatformSpecificOptionsToJson(
  OidcPlatformSpecificOptions instance,
) => <String, dynamic>{
  'android': instance.android.toJson(),
  'ios': instance.ios.toJson(),
  'macos': instance.macos.toJson(),
  'web': instance.web.toJson(),
  'linux': instance.linux.toJson(),
  'windows': instance.windows.toJson(),
};

OidcColorSchemeParams _$OidcColorSchemeParamsFromJson(
  Map<String, dynamic> json,
) => OidcColorSchemeParams(
  toolbarColor: (json['toolbarColor'] as num?)?.toInt(),
  secondaryToolbarColor: (json['secondaryToolbarColor'] as num?)?.toInt(),
  navigationBarColor: (json['navigationBarColor'] as num?)?.toInt(),
  navigationBarDividerColor: (json['navigationBarDividerColor'] as num?)
      ?.toInt(),
);

Map<String, dynamic> _$OidcColorSchemeParamsToJson(
  OidcColorSchemeParams instance,
) => <String, dynamic>{
  'toolbarColor': instance.toolbarColor,
  'secondaryToolbarColor': instance.secondaryToolbarColor,
  'navigationBarColor': instance.navigationBarColor,
  'navigationBarDividerColor': instance.navigationBarDividerColor,
};

OidcCustomTabsColorSchemes _$OidcCustomTabsColorSchemesFromJson(
  Map<String, dynamic> json,
) => OidcCustomTabsColorSchemes(
  colorScheme:
      $enumDecodeNullable(_$OidcColorSchemeEnumMap, json['colorScheme']) ??
      OidcColorScheme.system,
  lightParams: json['lightParams'] == null
      ? null
      : OidcColorSchemeParams.fromJson(
          json['lightParams'] as Map<String, dynamic>,
        ),
  darkParams: json['darkParams'] == null
      ? null
      : OidcColorSchemeParams.fromJson(
          json['darkParams'] as Map<String, dynamic>,
        ),
  defaultParams: json['defaultParams'] == null
      ? null
      : OidcColorSchemeParams.fromJson(
          json['defaultParams'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$OidcCustomTabsColorSchemesToJson(
  OidcCustomTabsColorSchemes instance,
) => <String, dynamic>{
  'colorScheme': _$OidcColorSchemeEnumMap[instance.colorScheme]!,
  'lightParams': instance.lightParams?.toJson(),
  'darkParams': instance.darkParams?.toJson(),
  'defaultParams': instance.defaultParams?.toJson(),
};

const _$OidcColorSchemeEnumMap = {
  OidcColorScheme.system: 'system',
  OidcColorScheme.light: 'light',
  OidcColorScheme.dark: 'dark',
};

OidcPartialCustomTabs _$OidcPartialCustomTabsFromJson(
  Map<String, dynamic> json,
) => OidcPartialCustomTabs(
  initialHeightPx: (json['initialHeightPx'] as num?)?.toInt(),
  resizeBehavior:
      $enumDecodeNullable(
        _$OidcPartialTabResizeBehaviorEnumMap,
        json['resizeBehavior'],
      ) ??
      OidcPartialTabResizeBehavior.defaultBehavior,
  toolbarCornerRadiusDp: (json['toolbarCornerRadiusDp'] as num?)?.toInt(),
  backgroundInteractionEnabled:
      json['backgroundInteractionEnabled'] as bool? ?? true,
);

Map<String, dynamic> _$OidcPartialCustomTabsToJson(
  OidcPartialCustomTabs instance,
) => <String, dynamic>{
  'initialHeightPx': instance.initialHeightPx,
  'resizeBehavior':
      _$OidcPartialTabResizeBehaviorEnumMap[instance.resizeBehavior]!,
  'toolbarCornerRadiusDp': instance.toolbarCornerRadiusDp,
  'backgroundInteractionEnabled': instance.backgroundInteractionEnabled,
};

const _$OidcPartialTabResizeBehaviorEnumMap = {
  OidcPartialTabResizeBehavior.defaultBehavior: 'defaultBehavior',
  OidcPartialTabResizeBehavior.adjustable: 'adjustable',
  OidcPartialTabResizeBehavior.fixed: 'fixed',
};

OidcNativeOptionsAndroid _$OidcNativeOptionsAndroidFromJson(
  Map<String, dynamic> json,
) => OidcNativeOptionsAndroid(
  colorSchemes: json['colorSchemes'] == null
      ? null
      : OidcCustomTabsColorSchemes.fromJson(
          json['colorSchemes'] as Map<String, dynamic>,
        ),
  shareState:
      $enumDecodeNullable(
        _$OidcCustomTabsShareStateEnumMap,
        json['shareState'],
      ) ??
      OidcCustomTabsShareState.browserDefault,
  showTitle: json['showTitle'] as bool? ?? true,
  urlBarHidingEnabled: json['urlBarHidingEnabled'] as bool? ?? false,
  ephemeralBrowsing: json['ephemeralBrowsing'] as bool? ?? false,
  closeButtonPosition: $enumDecodeNullable(
    _$OidcCustomTabsCloseButtonPositionEnumMap,
    json['closeButtonPosition'],
  ),
  preferredBrowserPackages:
      (json['preferredBrowserPackages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  useAuthTab:
      $enumDecodeNullable(_$OidcAuthTabModeEnumMap, json['useAuthTab']) ??
      OidcAuthTabMode.auto,
  partialCustomTabs: json['partialCustomTabs'] == null
      ? null
      : OidcPartialCustomTabs.fromJson(
          json['partialCustomTabs'] as Map<String, dynamic>,
        ),
  warmup:
      $enumDecodeNullable(_$OidcCustomTabsWarmupEnumMap, json['warmup']) ??
      OidcCustomTabsWarmup.none,
  rawIntentExtras: json['rawIntentExtras'] as Map<String, dynamic>? ?? const {},
  allowInsecureConnections: json['allowInsecureConnections'] as bool? ?? false,
  flowTimeoutSeconds: (json['flowTimeoutSeconds'] as num?)?.toInt(),
);

Map<String, dynamic> _$OidcNativeOptionsAndroidToJson(
  OidcNativeOptionsAndroid instance,
) => <String, dynamic>{
  'colorSchemes': instance.colorSchemes?.toJson(),
  'shareState': _$OidcCustomTabsShareStateEnumMap[instance.shareState]!,
  'showTitle': instance.showTitle,
  'urlBarHidingEnabled': instance.urlBarHidingEnabled,
  'ephemeralBrowsing': instance.ephemeralBrowsing,
  'closeButtonPosition':
      _$OidcCustomTabsCloseButtonPositionEnumMap[instance.closeButtonPosition],
  'preferredBrowserPackages': instance.preferredBrowserPackages,
  'useAuthTab': _$OidcAuthTabModeEnumMap[instance.useAuthTab]!,
  'partialCustomTabs': instance.partialCustomTabs?.toJson(),
  'warmup': _$OidcCustomTabsWarmupEnumMap[instance.warmup]!,
  'rawIntentExtras': instance.rawIntentExtras,
  'allowInsecureConnections': instance.allowInsecureConnections,
  'flowTimeoutSeconds': instance.flowTimeoutSeconds,
};

const _$OidcCustomTabsShareStateEnumMap = {
  OidcCustomTabsShareState.browserDefault: 'browserDefault',
  OidcCustomTabsShareState.on: 'on',
  OidcCustomTabsShareState.off: 'off',
};

const _$OidcCustomTabsCloseButtonPositionEnumMap = {
  OidcCustomTabsCloseButtonPosition.defaultPosition: 'defaultPosition',
  OidcCustomTabsCloseButtonPosition.start: 'start',
  OidcCustomTabsCloseButtonPosition.end: 'end',
};

const _$OidcAuthTabModeEnumMap = {
  OidcAuthTabMode.auto: 'auto',
  OidcAuthTabMode.force: 'force',
  OidcAuthTabMode.never: 'never',
};

const _$OidcCustomTabsWarmupEnumMap = {
  OidcCustomTabsWarmup.none: 'none',
  OidcCustomTabsWarmup.warmup: 'warmup',
  OidcCustomTabsWarmup.mayLaunch: 'mayLaunch',
};

OidcNativeOptionsApple _$OidcNativeOptionsAppleFromJson(
  Map<String, dynamic> json,
) => OidcNativeOptionsApple(
  prefersEphemeralWebBrowserSession:
      json['prefersEphemeralWebBrowserSession'] as bool? ?? false,
  additionalHeaderFields:
      (json['additionalHeaderFields'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
  callbackMode:
      $enumDecodeNullable(
        _$OidcAppleCallbackModeEnumMap,
        json['callbackMode'],
      ) ??
      OidcAppleCallbackMode.auto,
  rawSessionOptions:
      json['rawSessionOptions'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$OidcNativeOptionsAppleToJson(
  OidcNativeOptionsApple instance,
) => <String, dynamic>{
  'prefersEphemeralWebBrowserSession':
      instance.prefersEphemeralWebBrowserSession,
  'additionalHeaderFields': instance.additionalHeaderFields,
  'callbackMode': _$OidcAppleCallbackModeEnumMap[instance.callbackMode]!,
  'rawSessionOptions': instance.rawSessionOptions,
};

const _$OidcAppleCallbackModeEnumMap = {
  OidcAppleCallbackMode.auto: 'auto',
  OidcAppleCallbackMode.customScheme: 'customScheme',
  OidcAppleCallbackMode.https: 'https',
};

OidcPlatformSpecificOptions_Native _$OidcPlatformSpecificOptions_NativeFromJson(
  Map<String, dynamic> json,
) => OidcPlatformSpecificOptions_Native(
  successfulPageResponse: json['successfulPageResponse'] as String?,
  methodMismatchResponse: json['methodMismatchResponse'] as String?,
  notFoundResponse: json['notFoundResponse'] as String?,
);

Map<String, dynamic> _$OidcPlatformSpecificOptions_NativeToJson(
  OidcPlatformSpecificOptions_Native instance,
) => <String, dynamic>{
  'successfulPageResponse': instance.successfulPageResponse,
  'methodMismatchResponse': instance.methodMismatchResponse,
  'notFoundResponse': instance.notFoundResponse,
};

OidcPlatformSpecificOptions_Web _$OidcPlatformSpecificOptions_WebFromJson(
  Map<String, dynamic> json,
) => OidcPlatformSpecificOptions_Web(
  navigationMode:
      $enumDecodeNullable(
        _$OidcPlatformSpecificOptions_Web_NavigationModeEnumMap,
        json['navigationMode'],
      ) ??
      OidcPlatformSpecificOptions_Web_NavigationMode.newPage,
  popupWidth: (json['popupWidth'] as num?)?.toDouble() ?? 700,
  popupHeight: (json['popupHeight'] as num?)?.toDouble() ?? 750,
  broadcastChannel:
      json['broadcastChannel'] as String? ??
      OidcPlatformSpecificOptions_Web.defaultBroadcastChannel,
  hiddenIframeTimeout: json['hiddenIframeTimeout'] == null
      ? const Duration(seconds: 10)
      : Duration(microseconds: (json['hiddenIframeTimeout'] as num).toInt()),
);

Map<String, dynamic> _$OidcPlatformSpecificOptions_WebToJson(
  OidcPlatformSpecificOptions_Web instance,
) => <String, dynamic>{
  'navigationMode':
      _$OidcPlatformSpecificOptions_Web_NavigationModeEnumMap[instance
          .navigationMode]!,
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
