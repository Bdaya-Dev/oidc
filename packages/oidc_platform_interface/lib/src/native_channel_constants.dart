/// Shared constants for the first-party native browser channels
/// (`oidc_android` / `oidc_ios`).
///
/// These are the single source of truth on the Dart side for the
/// [MethodChannel](https://api.flutter.dev/flutter/services/MethodChannel-class.html)
/// names and the error codes the native plugins return. The native code
/// (Kotlin `OidcPlugin.kt`, Swift `OidcPlugin.swift`) must keep its
/// `result.error(...)` / `FlutterError(...)` codes BYTE-FOR-BYTE identical to
/// the values declared here.
library;

/// Domain-prefixed platform-channel names.
///
/// Flutter requires channel names to be unique across the whole app; the
/// documented convention is a reverse-DNS prefix
/// (`domain/feature`) — see
/// https://docs.flutter.dev/platform-integration/platform-channels#step-3-add-an-android-platform-specific-implementation
abstract final class OidcNativeChannels {
  /// The Android Chrome-Custom-Tabs channel.
  static const String android = 'com.bdayadev.oidc/android';

  /// The iOS `ASWebAuthenticationSession` channel.
  static const String ios = 'com.bdayadev.oidc/ios';

  /// The macOS `ASWebAuthenticationSession` channel.
  static const String macos = 'com.bdayadev.oidc/macos';

  /// The Android observability `EventChannel`.
  static const String androidEvents = 'com.bdayadev.oidc/android/events';

  /// The iOS observability `EventChannel`.
  static const String iosEvents = 'com.bdayadev.oidc/ios/events';

  /// The macOS observability `EventChannel`.
  static const String macosEvents = 'com.bdayadev.oidc/macos/events';
}

/// Method names invoked on the native channels.
abstract final class OidcNativeMethods {
  /// Open the authorization URL and capture the redirect.
  static const String authorize = 'authorize';

  /// Open the end-session URL and capture the redirect.
  static const String endSession = 'endSession';

  /// Cancel any in-flight native session.
  static const String cancel = 'cancel';
}

/// Error codes returned by the native plugins via `result.error(...)`.
///
/// Kept in sync with `OidcPlugin.kt` / `OidcPlugin.swift`.
abstract final class OidcNativeErrorCodes {
  /// The user dismissed the browser before completing the flow. Treated as a
  /// benign `null` result (matching the cancellation contract of the other
  /// platforms).
  static const String userCancelled = 'USER_CANCELLED';

  /// iOS only: the presentation context was closed/invalid (the iOS + Azure
  /// "-3" end-session case), which for logout means the session simply ended.
  static const String presentationContextInvalid =
      'PRESENTATION_CONTEXT_INVALID';
}
