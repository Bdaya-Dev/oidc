// coverage:ignore-file
// ignore_for_file: camel_case_types

import 'package:json_annotation/json_annotation.dart';

/// Represents flutter platform-specific options.
@JsonSerializable()
class OidcAuthorizePlatformSpecificOptions {
  ///
  const OidcAuthorizePlatformSpecificOptions({
    this.android = const OidcAuthorizePlatformOptions_AppAuth(),
    this.ios = const OidcAuthorizePlatformOptions_AppAuth_IosMacos(),
    this.macos = const OidcAuthorizePlatformOptions_AppAuth_IosMacos(),
    this.web = const OidcAuthorizePlatformOptions_Web(),
    this.windows = const OidcAuthorizePlatformOptions_Native(),
    this.linux = const OidcAuthorizePlatformOptions_Native(),
  });

  /// Android options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'android')
  final OidcAuthorizePlatformOptions_AppAuth android;

  /// IOs options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'ios')
  final OidcAuthorizePlatformOptions_AppAuth_IosMacos ios;

  /// MacOs options that will get passed to `package:flutter_appauth`
  @JsonKey(name: 'macos')
  final OidcAuthorizePlatformOptions_AppAuth_IosMacos macos;

  /// Web options.
  @JsonKey(name: 'web')
  final OidcAuthorizePlatformOptions_Web web;

  /// Linux options.
  @JsonKey(name: 'linux')
  final OidcAuthorizePlatformOptions_Native linux;

  /// Windows options.
  @JsonKey(name: 'windows')
  final OidcAuthorizePlatformOptions_Native windows;
}

///
@JsonSerializable()
class OidcAuthorizePlatformOptions_AppAuth {
  ///
  const OidcAuthorizePlatformOptions_AppAuth({
    this.allowInsecureConnections = false,
  });

  ///
  final bool allowInsecureConnections;
}

///
@JsonSerializable()
class OidcAuthorizePlatformOptions_AppAuth_IosMacos
    extends OidcAuthorizePlatformOptions_AppAuth {
  ///
  const OidcAuthorizePlatformOptions_AppAuth_IosMacos({
    this.preferEphemeralSession = false,
    super.allowInsecureConnections,
  });

  ///
  final bool preferEphemeralSession;
}

///
@JsonSerializable()
class OidcAuthorizePlatformOptions_Native {
  ///
  const OidcAuthorizePlatformOptions_Native({
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
enum OidcAuthorizePlatformOptions_Web_NavigationMode {
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

  /// RECOMMENDED
  ///
  /// 1. Navigate to the Uri using a popup.
  /// 2. the redirect Uri should be /redirect.html
  /// 3. the page should call BroadcastChannel postMessage the original page with the query parameters
  /// 4. the page should close itself
  /// 5. the app receives the postMessage, and finishes the flow.
  popup,
}

///
@JsonSerializable()
class OidcAuthorizePlatformOptions_Web {
  ///
  const OidcAuthorizePlatformOptions_Web({
    this.navigationMode =
        OidcAuthorizePlatformOptions_Web_NavigationMode.newPage,
    this.popupWidth = 700,
    this.popupHeight = 750,
  });

  /// The navigation mode to use for web.
  final OidcAuthorizePlatformOptions_Web_NavigationMode navigationMode;

  /// The width of the popup window if [navigationMode] is set to [OidcAuthorizePlatformOptions_Web_NavigationMode.popup].
  final double popupWidth;

  /// The height of the popup window if [navigationMode] is set to [OidcAuthorizePlatformOptions_Web_NavigationMode.popup].
  final double popupHeight;
}
