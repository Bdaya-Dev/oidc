// ignore_for_file: camel_case_types

///
class OidcAuthorizePlatformOptions {
  ///
  const OidcAuthorizePlatformOptions({
    this.android = const OidcAuthorizePlatformOptions_AppAuth(),
    this.ios = const OidcAuthorizePlatformOptions_AppAuth(),
    this.macos = const OidcAuthorizePlatformOptions_AppAuth(),
    this.web = const OidcAuthorizePlatformOptions_Web(),
  });

  ///
  final OidcAuthorizePlatformOptions_AppAuth android;

  ///
  final OidcAuthorizePlatformOptions_AppAuth ios;

  ///
  final OidcAuthorizePlatformOptions_AppAuth macos;

  ///
  final OidcAuthorizePlatformOptions_Web web;
}

///
class OidcAuthorizePlatformOptions_AppAuth {
  ///
  const OidcAuthorizePlatformOptions_AppAuth({
    this.allowInsecureConnections = false,
    this.preferEphemeralSession = false,
  });

  ///
  final bool allowInsecureConnections;

  ///
  final bool preferEphemeralSession;
}

/// The possible navigation modes to use for web.
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
  /// 3. the page should postMessage the original page with the query parameters
  /// 4. the page should close itself
  /// 5. the app receives the postMessage, and finishes the flow.
  newPage,

  /// RECOMMENDED
  ///
  ///
  popup,

  ///
  iframe,
}

///
class OidcAuthorizePlatformOptions_Web {
  ///
  const OidcAuthorizePlatformOptions_Web({
    this.navigationMode =
        OidcAuthorizePlatformOptions_Web_NavigationMode.newPage,
  });

  /// The navigation mode to use for web.
  final OidcAuthorizePlatformOptions_Web_NavigationMode navigationMode;
}
