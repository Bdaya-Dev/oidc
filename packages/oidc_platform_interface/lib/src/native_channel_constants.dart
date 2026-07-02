/// Shared constants for the first-party native browser transport
/// (`oidc_android` / `oidc_darwin`).
///
/// The Dart<->native message transport is the Pigeon-generated
/// `OidcAndroidHostApi` / `OidcAppleHostApi` (see `oidc_native.g.dart`); Pigeon
/// owns the channel names. The constants below remain the single source of
/// truth for the method labels and error codes the native plugins use, which
/// the native code (Kotlin `OidcPlugin.kt`, Swift `OidcPlugin.swift`) must keep
/// BYTE-FOR-BYTE identical to the values declared here.
library;

/// Domain-prefixed platform-channel names for the legacy hand-rolled
/// `MethodChannel` transport.
///
/// {@template oidc_native_channels_deprecated}
/// Deprecated: the native transport now uses Pigeon (`OidcAndroidHostApi` /
/// `OidcAppleHostApi` + the `streamNativeEvents` event channel), which owns its
/// own channel names (`dev.flutter.pigeon.oidc_platform_interface.*`). These
/// constants are no longer used by the implementations and are kept only to
/// avoid breaking any external references; they will be removed in a future
/// release.
/// {@endtemplate}
@Deprecated(
  'The native transport moved to Pigeon, which owns its channel names. '
  'These constants are unused and will be removed in a future release.',
)
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

/// Logical method names for the native browser primitive.
///
/// These match the Pigeon `OidcAndroidHostApi` method names and are also used
/// as human-readable labels when wrapping native failures into an
/// `OidcException` (e.g. "Native authorize failed (...)").
abstract final class OidcNativeMethods {
  /// Open the authorization URL and capture the redirect.
  static const String authorize = 'authorize';

  /// Open the end-session URL and capture the redirect.
  static const String endSession = 'endSession';

  /// Cancel any in-flight native session.
  static const String cancel = 'cancel';
}

/// Error codes returned by the native plugins via Pigeon `PigeonError` /
/// `FlutterError` (surfaced Dart-side as a `PlatformException.code`).
///
/// Kept in sync with `OidcPlugin.kt` / `OidcPlugin.swift`.
abstract final class OidcNativeErrorCodes {
  /// The user dismissed the browser before completing the flow. Treated as a
  /// benign `null` result (matching the cancellation contract of the other
  /// platforms).
  static const String userCancelled = 'USER_CANCELLED';

  /// iOS/macOS only: the presentation context was closed/invalid (the iOS +
  /// Azure "-3" end-session case), which for logout means the session simply
  /// ended.
  static const String presentationContextInvalid =
      'PRESENTATION_CONTEXT_INVALID';
}
