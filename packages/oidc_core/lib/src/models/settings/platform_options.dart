// coverage:ignore-file
// ignore_for_file: camel_case_types

import 'package:json_annotation/json_annotation.dart';

/// Represents flutter platform-specific options.
@JsonSerializable()
class OidcPlatformSpecificOptions {
  ///
  const OidcPlatformSpecificOptions({
    this.android = const OidcPlatformSpecificOptions_AppAuth_Android(),
    this.ios = const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
    this.macos = const OidcPlatformSpecificOptions_AppAuth_IosMacos(),
    this.web = const OidcPlatformSpecificOptions_Web(),
    this.windows = const OidcPlatformSpecificOptions_Native(),
    this.linux = const OidcPlatformSpecificOptions_Native(),
  });

  /// Android options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'android')
  final OidcPlatformSpecificOptions_AppAuth_Android android;

  /// IOs options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'ios')
  final OidcPlatformSpecificOptions_AppAuth_IosMacos ios;

  /// MacOs options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'macos')
  final OidcPlatformSpecificOptions_AppAuth_IosMacos macos;

  /// Web options.
  @JsonKey(name: 'web')
  final OidcPlatformSpecificOptions_Web web;

  /// Linux options.
  @JsonKey(name: 'linux')
  final OidcPlatformSpecificOptions_Native linux;

  /// Windows options.
  @JsonKey(name: 'windows')
  final OidcPlatformSpecificOptions_Native windows;
}

///
@JsonSerializable()
class OidcPlatformSpecificOptions_AppAuth_Android {
  ///
  const OidcPlatformSpecificOptions_AppAuth_Android({
    this.allowInsecureConnections = false,
  });

  ///
  final bool allowInsecureConnections;
}

///
@JsonSerializable()
class OidcPlatformSpecificOptions_AppAuth_IosMacos {
  ///
  const OidcPlatformSpecificOptions_AppAuth_IosMacos({
    this.preferEphemeralSession = false,
  });

  ///
  final bool preferEphemeralSession;
}

///
@JsonSerializable()
class OidcPlatformSpecificOptions_Native {
  ///
  const OidcPlatformSpecificOptions_Native({
    this.successfulPageResponse,
    this.methodMismatchResponse,
    this.notFoundResponse,
  });

  /// What to return if a URI is matched
  final String? successfulPageResponse;

  /// What to return if a method other than `GET` is requested.
  final String? methodMismatchResponse;

  /// What to return if a different path is used.
  final String? notFoundResponse;
}

/// The possible navigation modes to use for web.
@JsonEnum()
enum OidcPlatformSpecificOptions_Web_NavigationMode {
  /// NOT RECOMMENDED, since you have to reload your app and lose current ui state.
  ///
  /// 1. Navigate to the Uri on the same page
  /// 2. the redirect Uri should be /redirect.html
  /// 3. The page will read the stored state, knowing the navigation mode.
  /// 4. The page should store the query parameters or fragment (based on state)
  /// 5. the page should send you back to the original page uri (based on state)
  /// 6. in the init() function, check for unprocessed states.
  samePage,

  /// RECOMMENDED
  ///
  /// 1. Navigate to the Uri on a new page.
  /// 2. the redirect Uri should be /redirect.html
  /// 3. the page should call BroadcastChannel postMessage the original page with the query parameters
  /// 4. the page should close itself
  /// 5. the app receives the postMessage, and finishes the flow.
  newPage,

  /// NOT RECOMMENDED, since some browsers block popups.
  ///
  /// 1. Navigate to the Uri using a popup.
  /// 2. the redirect Uri should be /redirect.html
  /// 3. the page should call BroadcastChannel postMessage the original page with the query parameters
  /// 4. the page should close itself
  /// 5. the app receives the postMessage, and finishes the flow.
  popup,

  /// NOT RECOMMENDED for user interaction.
  hiddenIFrame,
}

///
@JsonSerializable()
class OidcPlatformSpecificOptions_Web {
  ///
  const OidcPlatformSpecificOptions_Web({
    this.navigationMode =
        OidcPlatformSpecificOptions_Web_NavigationMode.newPage,
    this.popupWidth = 700,
    this.popupHeight = 750,
    this.broadcastChannel = defaultBroadcastChannel,
    this.hiddenIframeTimeout = const Duration(seconds: 10),
  });

  /// The default broadcast channel to use.
  static const defaultBroadcastChannel = 'oidc_flutter_web/redirect';

  /// The navigation mode to use for web.
  final OidcPlatformSpecificOptions_Web_NavigationMode navigationMode;

  /// The width of the popup window if [navigationMode] is set to [OidcPlatformSpecificOptions_Web_NavigationMode.popup].
  final double popupWidth;

  /// The height of the popup window if [navigationMode] is set to [OidcPlatformSpecificOptions_Web_NavigationMode.popup].
  final double popupHeight;

  /// The broadcast channel to use when receiving messages from the browser.
  ///
  /// defaults to [defaultBroadcastChannel].
  final String broadcastChannel;

  /// the amount of time to wait before considering the request failed when using [OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame].
  ///
  /// default is 10 seconds
  final Duration hiddenIframeTimeout;
}
