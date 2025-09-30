import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

Uri getPlatformRedirectUri() {
  return kIsWeb
      // this url must be an actual html page.
      // see the file in /web/redirect.html for an example.
      //
      // for debugging in flutter, you must run this app with --web-port 22433
      ? Uri.parse('http://localhost:22433/redirect.html')
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
