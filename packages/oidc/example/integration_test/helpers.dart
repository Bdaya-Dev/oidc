import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:oidc_example/web_redirect_uri.dart';

Uri getPlatformRedirectUri() {
  return kIsWeb
      // this url must be an actual html page.
      // see the file in /web/redirect.html for an example.
      //
      // Derived from the origin the app is actually served from, via the same
      // function app_state.dart uses. This is what gets registered with the
      // conformance test plan, so a hardcoded origin here would register a
      // redirect_uri the app does not send the moment it is served anywhere
      // else -- and OIDC Registration section 2 requires it to be served
      // somewhere else: https, and not localhost, for the implicit and hybrid
      // flows.
      ? harnessWebRedirectUri(base: Uri.base)
      : Platform.isIOS || Platform.isMacOS || Platform.isAndroid
      // scheme: reverse domain name notation of your package name.
      // path: anything.
      ? Uri.parse('com.bdayadev.oidc.example:/oauth2redirect')
      : Platform.isWindows || Platform.isLinux
      // using port 0 means that we don't care which port is used,
      // and a random unused port will be assigned.
      //
      // this is safer than passing a port yourself.
      //
      // note that you can also pass a path like /redirect,
      // but it's completely optional.
      ? Uri.parse('http://localhost:22434')
      : Uri();
}

/// The `frontchannel_logout_uri` registered with the conformance test plan.
///
/// Platform-branched for the same reason [getPlatformRedirectUri] is: only web
/// has an http(s) origin to derive from. `Uri.base` is a `file://` URI on every
/// other platform, and deriving a web URI from it throws before any test runs.
///
/// The non-web value is the fixed literal this harness has always sent. Front-
/// channel logout needs a browser-reachable page, which a private-use scheme
/// cannot provide, so there is no per-platform value to compute -- the logout
/// profiles that depend on it are gated out on those platforms anyway.
Uri getPlatformFrontChannelLogoutUri() => kIsWeb
    ? webFrontChannelLogoutUri(base: Uri.base)
    : Uri.parse(
        'http://localhost:22433/redirect.html?requestType=front-channel-logout',
      );

String getPlatformName() {
  return kIsWeb
      ? 'Web'
      : Platform.isAndroid
      ? 'android'
      : Platform.isIOS
      ? 'ios'
      : Platform.isMacOS
      ? 'macos'
      : Platform.isWindows
      ? 'windows'
      : Platform.isLinux
      ? 'linux'
      : Platform.isFuchsia
      ? 'fuchsia'
      : Platform.operatingSystem;
}
