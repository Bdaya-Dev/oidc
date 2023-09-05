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
  samePage,
  newPage,
  popup,
  // iframe,
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
