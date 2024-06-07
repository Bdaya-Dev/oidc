// ignore_for_file: camel_case_types

/// The possible navigation modes to use for web.
enum OidcPlatformSpecificOptions_WebCore_NavigationMode {
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
class OidcPlatformSpecificOptions_WebCore {
  ///
  const OidcPlatformSpecificOptions_WebCore({
    this.navigationMode =
        OidcPlatformSpecificOptions_WebCore_NavigationMode.newPage,
    this.popupWidth = 700,
    this.popupHeight = 750,
    this.broadcastChannel = defaultBroadcastChannel,
    this.hiddenIframeTimeout = const Duration(seconds: 10),
  });

  /// The default broadcast channel to use.
  static const defaultBroadcastChannel = 'oidc_flutter_web/redirect';

  /// The navigation mode to use for web.
  final OidcPlatformSpecificOptions_WebCore_NavigationMode navigationMode;

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

///
class OidcFrontChannelRequestListeningOptions_WebCore {
  ///
  const OidcFrontChannelRequestListeningOptions_WebCore({
    this.broadcastChannel = defaultBroadcastChannel,
  });

  /// `oidc_flutter_web/request`
  static const defaultBroadcastChannel = 'oidc_flutter_web/request';

  /// The broadcast channel to use when receiving messages from the browser.
  ///
  /// defaults to [defaultBroadcastChannel].
  final String broadcastChannel;
}
