// coverage:ignore-file
// ignore_for_file: camel_case_types, sort_constructors_first

import 'package:json_annotation/json_annotation.dart';

part 'platform_options.g.dart';

/// Marker interface implemented by every per-platform native-options object.
///
/// The launch path stays type-erased; each platform package owns its fully
/// typed object so platform-specific types never leak across packages
/// (the `flutter_custom_tabs` `PlatformOptions` pattern).
abstract interface class OidcPlatformOptionsMarker {}

/// Represents flutter platform-specific options.
@JsonSerializable(explicitToJson: true)
class OidcPlatformSpecificOptions {
  ///
  const OidcPlatformSpecificOptions({
    this.android = const OidcNativeOptionsAndroid(),
    this.ios = const OidcNativeOptionsApple(),
    this.macos = const OidcNativeOptionsApple(),
    this.web = const OidcPlatformSpecificOptions_Web(),
    this.windows = const OidcPlatformSpecificOptions_Native(),
    this.linux = const OidcPlatformSpecificOptions_Native(),
  });

  /// Android options for the first-party Chrome Custom Tabs flow.
  @JsonKey(name: 'android')
  final OidcNativeOptionsAndroid android;

  /// iOS options for the first-party `ASWebAuthenticationSession` flow.
  @JsonKey(name: 'ios')
  final OidcNativeOptionsApple ios;

  /// macOS options for the first-party `ASWebAuthenticationSession` flow.
  @JsonKey(name: 'macos')
  final OidcNativeOptionsApple macos;

  /// Web options.
  @JsonKey(name: 'web')
  final OidcPlatformSpecificOptions_Web web;

  /// Linux options.
  @JsonKey(name: 'linux')
  final OidcPlatformSpecificOptions_Native linux;

  /// Windows options.
  @JsonKey(name: 'windows')
  final OidcPlatformSpecificOptions_Native windows;

  Map<String, dynamic> toJson() {
    return _$OidcPlatformSpecificOptionsToJson(this);
  }

  factory OidcPlatformSpecificOptions.fromJson(
    Map<String, dynamic> src,
  ) => _$OidcPlatformSpecificOptionsFromJson(src);
}

// =============================================================================
// Android — Chrome Custom Tabs
// =============================================================================

/// Color scheme for the Custom Tab (maps to `setColorScheme`).
@JsonEnum()
enum OidcColorScheme {
  /// Follow the system setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Whether the Custom Tab shows a default share action
/// (maps to `setShareState`).
@JsonEnum()
enum OidcCustomTabsShareState {
  /// Let the browser decide.
  browserDefault,

  /// Force the share action on.
  on,

  /// Force the share action off.
  off,
}

/// Where the close button sits (maps to `setCloseButtonPosition`).
@JsonEnum()
enum OidcCustomTabsCloseButtonPosition {
  /// Browser default.
  defaultPosition,

  /// At the start of the toolbar.
  start,

  /// At the end of the toolbar.
  end,
}

/// Resize behavior of a partial (bottom-sheet) Custom Tab.
@JsonEnum()
enum OidcPartialTabResizeBehavior {
  /// Browser default.
  defaultBehavior,

  /// User can drag to resize.
  adjustable,

  /// Fixed at the initial height.
  fixed,
}

/// Selects the redirect-capture model on Android.
@JsonEnum()
enum OidcAuthTabMode {
  /// Use the Auth Tab API when available (Chrome 137+), else fall back to the
  /// plugin-owned `OidcRedirectActivity` + Custom Tabs path.
  auto,

  /// Always use the Auth Tab API (fails if unsupported).
  force,

  /// Always use the Custom Tabs + `OidcRedirectActivity` path.
  never,
}

/// Optional pre-warming of the Custom Tabs service.
///
/// NOTE: auth URLs are frequently single-use / nonce-bound, so prefetch benefit
/// can be marginal, and `mayLaunch` must receive the actual authorize URL to
/// help. Defaults to [none].
@JsonEnum()
enum OidcCustomTabsWarmup {
  /// No pre-warming.
  none,

  /// Bind + warm up the Custom Tabs service (`CustomTabsClient.warmup`).
  warmup,

  /// Warm up and hint the upcoming URL (`CustomTabsSession.mayLaunchUrl`).
  mayLaunch,
}

/// `CustomTabColorSchemeParams` for one color scheme.
///
/// Colors are 32-bit ARGB ints (e.g. `0xFF2196F3`); the native side reads them
/// as 64-bit and applies opaque alpha where required.
@JsonSerializable()
class OidcColorSchemeParams {
  ///
  const OidcColorSchemeParams({
    this.toolbarColor,
    this.secondaryToolbarColor,
    this.navigationBarColor,
    this.navigationBarDividerColor,
  });

  /// ARGB toolbar color.
  final int? toolbarColor;

  /// ARGB secondary toolbar color.
  final int? secondaryToolbarColor;

  /// ARGB navigation-bar color.
  final int? navigationBarColor;

  /// ARGB navigation-bar divider color.
  final int? navigationBarDividerColor;

  Map<String, dynamic> toJson() => _$OidcColorSchemeParamsToJson(this);

  factory OidcColorSchemeParams.fromJson(Map<String, dynamic> src) =>
      _$OidcColorSchemeParamsFromJson(src);
}

/// Color configuration for the Custom Tab (maps to `setColorScheme` +
/// `setColorSchemeParams` / `setDefaultColorSchemeParams`).
@JsonSerializable(explicitToJson: true)
class OidcCustomTabsColorSchemes {
  ///
  const OidcCustomTabsColorSchemes({
    this.colorScheme = OidcColorScheme.system,
    this.lightParams,
    this.darkParams,
    this.defaultParams,
  });

  /// The active color scheme.
  final OidcColorScheme colorScheme;

  /// Params applied to the light scheme.
  final OidcColorSchemeParams? lightParams;

  /// Params applied to the dark scheme.
  final OidcColorSchemeParams? darkParams;

  /// Params applied as the default scheme.
  final OidcColorSchemeParams? defaultParams;

  Map<String, dynamic> toJson() => _$OidcCustomTabsColorSchemesToJson(this);

  factory OidcCustomTabsColorSchemes.fromJson(Map<String, dynamic> src) =>
      _$OidcCustomTabsColorSchemesFromJson(src);
}

/// Partial (bottom-sheet) Custom Tab configuration.
@JsonSerializable()
class OidcPartialCustomTabs {
  ///
  const OidcPartialCustomTabs({
    this.initialHeightPx,
    this.resizeBehavior = OidcPartialTabResizeBehavior.defaultBehavior,
    this.toolbarCornerRadiusDp,
    this.backgroundInteractionEnabled = true,
  });

  /// Initial sheet height in px (`setInitialActivityHeightPx`).
  final int? initialHeightPx;

  /// How the user may resize the sheet.
  final OidcPartialTabResizeBehavior resizeBehavior;

  /// Toolbar corner radius in dp (`setToolbarCornerRadiusDp`).
  final int? toolbarCornerRadiusDp;

  /// Whether the background app remains interactive
  /// (`setBackgroundInteractionEnabled`).
  final bool backgroundInteractionEnabled;

  Map<String, dynamic> toJson() => _$OidcPartialCustomTabsToJson(this);

  factory OidcPartialCustomTabs.fromJson(Map<String, dynamic> src) =>
      _$OidcPartialCustomTabsFromJson(src);
}

/// Android options for the first-party Chrome Custom Tabs flow.
@JsonSerializable(explicitToJson: true)
class OidcNativeOptionsAndroid implements OidcPlatformOptionsMarker {
  ///
  const OidcNativeOptionsAndroid({
    this.colorSchemes,
    this.shareState = OidcCustomTabsShareState.browserDefault,
    this.showTitle = true,
    this.urlBarHidingEnabled = false,
    this.ephemeralBrowsing = false,
    this.closeButtonPosition,
    this.preferredBrowserPackages = const [],
    this.useAuthTab = OidcAuthTabMode.auto,
    this.partialCustomTabs,
    this.warmup = OidcCustomTabsWarmup.none,
    this.rawIntentExtras = const {},
    this.allowInsecureConnections = false,
  });

  /// Toolbar / nav-bar colors.
  final OidcCustomTabsColorSchemes? colorSchemes;

  /// Whether the default share action is shown.
  final OidcCustomTabsShareState shareState;

  /// Whether the page title is shown in the toolbar.
  final bool showTitle;

  /// Whether the url bar hides on scroll.
  final bool urlBarHidingEnabled;

  /// Whether to request an ephemeral (incognito) browsing session.
  ///
  /// Cross-platform concept (mirrors iOS/macOS
  /// [OidcNativeOptionsApple.prefersEphemeralWebBrowserSession]). Silently
  /// ignored where the browser/`androidx.browser` version does not support it.
  final bool ephemeralBrowsing;

  /// Close-button placement.
  final OidcCustomTabsCloseButtonPosition? closeButtonPosition;

  /// Ordered list of preferred browser packages to resolve a Custom Tabs
  /// provider from (`CustomTabsClient.getPackageName`).
  final List<String> preferredBrowserPackages;

  /// Redirect-capture model selector (Auth Tab vs Custom Tabs +
  /// `OidcRedirectActivity`).
  final OidcAuthTabMode useAuthTab;

  /// Partial (bottom-sheet) Custom Tab configuration.
  final OidcPartialCustomTabs? partialCustomTabs;

  /// Optional Custom Tabs service pre-warming.
  final OidcCustomTabsWarmup warmup;

  /// Escape hatch: arbitrary **serializable** intent extras forwarded verbatim
  /// to the Custom Tabs `Intent` (primitives / `List` / `Map` only).
  ///
  /// Non-serializable config (`RemoteViews`, `Bitmap`, `PendingIntent`,
  /// animation resources) is NOT expressible here — use the native
  /// `OidcPlugin` builder-mutator hook instead.
  final Map<String, dynamic> rawIntentExtras;

  /// Whether to allow insecure (http / self-signed) connections in the flow.
  final bool allowInsecureConnections;

  Map<String, dynamic> toJson() => _$OidcNativeOptionsAndroidToJson(this);

  factory OidcNativeOptionsAndroid.fromJson(Map<String, dynamic> src) =>
      _$OidcNativeOptionsAndroidFromJson(src);
}

// =============================================================================
// iOS / macOS — ASWebAuthenticationSession
// =============================================================================

/// Selects the `ASWebAuthenticationSession` callback type.
@JsonEnum()
enum OidcAppleCallbackMode {
  /// Derive from the `redirect_uri` scheme (https -> Universal Link, otherwise
  /// custom scheme). Preserves the existing iOS behavior.
  auto,

  /// Force `Callback.customScheme(_:)`.
  customScheme,

  /// Force `Callback.https(host:path:)` (requires an Associated Domains
  /// entitlement; iOS 17.4 / macOS 14.4+).
  https,
}

/// iOS / macOS options for the first-party `ASWebAuthenticationSession` flow.
@JsonSerializable()
class OidcNativeOptionsApple implements OidcPlatformOptionsMarker {
  ///
  const OidcNativeOptionsApple({
    this.prefersEphemeralWebBrowserSession = false,
    this.additionalHeaderFields,
    this.callbackMode = OidcAppleCallbackMode.auto,
    this.rawSessionOptions = const {},
  });

  /// Whether to use an ephemeral session (no shared cookies/cache).
  final bool prefersEphemeralWebBrowserSession;

  /// Extra HTTP headers added to the **initial** authorization request
  /// (`additionalHeaderFields`, iOS 17.4 / macOS 14.4+; ignored before that).
  final Map<String, String>? additionalHeaderFields;

  /// Which `ASWebAuthenticationSession.Callback` type to use.
  final OidcAppleCallbackMode callbackMode;

  /// Escape hatch: arbitrary **serializable** session options forwarded
  /// verbatim (read defensively / availability-guarded native-side).
  final Map<String, dynamic> rawSessionOptions;

  Map<String, dynamic> toJson() => _$OidcNativeOptionsAppleToJson(this);

  factory OidcNativeOptionsApple.fromJson(Map<String, dynamic> src) =>
      _$OidcNativeOptionsAppleFromJson(src);
}

///
@JsonSerializable()
class OidcPlatformSpecificOptions_Native {
  ///
  const OidcPlatformSpecificOptions_Native({
    this.successfulPageResponse,
    this.methodMismatchResponse,
    this.notFoundResponse,
    this.launchUrl,
  });

  /// What to return if a URI is matched
  final String? successfulPageResponse;

  /// What to return if a method other than `GET` is requested.
  final String? methodMismatchResponse;

  /// What to return if a different path is used.
  final String? notFoundResponse;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final Future<bool> Function(Uri url)? launchUrl;

  Map<String, dynamic> toJson() {
    return _$OidcPlatformSpecificOptions_NativeToJson(this);
  }

  factory OidcPlatformSpecificOptions_Native.fromJson(
    Map<String, dynamic> src,
  ) => _$OidcPlatformSpecificOptions_NativeFromJson(src);
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
    this.broadcastChannel =
        OidcPlatformSpecificOptions_Web.defaultBroadcastChannel,
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

  Map<String, dynamic> toJson() {
    return _$OidcPlatformSpecificOptions_WebToJson(this);
  }

  factory OidcPlatformSpecificOptions_Web.fromJson(
    Map<String, dynamic> src,
  ) => _$OidcPlatformSpecificOptions_WebFromJson(src);
}
