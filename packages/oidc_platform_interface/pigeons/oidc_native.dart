// Pigeon schema for the first-party native browser transport.
//
// Codegen (from packages/oidc_platform_interface):
//   dart pub global run pigeon --input pigeons/oidc_native.dart
// Pigeon emits a single platform-guarded Swift file (`#if os(iOS)/macOS`) into
// the unified `oidc_darwin` package, so iOS and macOS share one output — there
// is nothing to copy.
//
// Options + events cross as `Map<String, Object?>` (the existing toJson /
// event maps), so the native option-parsing + event-mapping are reused; Pigeon
// provides the compiler-enforced, generated method dispatch + event channel.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/oidc_native.g.dart',
    dartPackageName: 'oidc_platform_interface',
    kotlinOut:
        '../oidc_android/android/src/main/kotlin/com/bdayadev/oidc/OidcNative.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.bdayadev.oidc'),
    swiftOut:
        '../oidc_darwin/darwin/oidc_darwin/Sources/oidc_darwin/OidcNative.g.swift',
  ),
)

/// Android Custom Tabs / Auth Tab host API (implemented by `oidc_android`).
@HostApi()
abstract class OidcAndroidHostApi {
  /// Opens the authorization URL and returns the captured redirect URI string
  /// (null when the user cancelled).
  ///
  /// Uses `@asyncCallback` (not the now-default `@async`): since pigeon
  /// 28.0.0, `@async` generates `suspend`/coroutine-based native interfaces.
  /// The hand-written Kotlin implementation (`OidcPlugin.kt`) resolves this
  /// from an `onActivityResult`-style callback, not a coroutine continuation,
  /// so `@asyncCallback` keeps generating the pre-28 callback signature
  /// (`callback: (Result<String?>) -> Unit`) and avoids an unrelated rewrite
  /// of that native glue.
  @asyncCallback
  String? authorize(
    String url,
    String? redirectUri,
    String? callbackScheme,
    Map<String, Object?> options,
  );

  /// Opens the end-session URL and returns the captured redirect URI string.
  @asyncCallback
  String? endSession(
    String url,
    String? redirectUri,
    String? callbackScheme,
    Map<String, Object?> options,
  );

  /// Cancels any in-flight native session.
  void cancel();
}

/// iOS / macOS `ASWebAuthenticationSession` host API (implemented by
/// `oidc_darwin`; only one Apple platform is active at runtime, so iOS and
/// macOS share the API channel name).
@HostApi()
abstract class OidcAppleHostApi {
  // See the `@asyncCallback` note on `OidcAndroidHostApi.authorize` above:
  // the hand-written Swift implementation (`OidcPlugin.swift`) also uses a
  // completion-handler shape, not `async`/`await`.
  @asyncCallback
  String? authorizeApple(
    String url,
    String? redirectUri,
    String? callbackScheme,
    bool preferEphemeral,
    Map<String, Object?> options,
  );

  @asyncCallback
  String? endSessionApple(
    String url,
    String? redirectUri,
    String? callbackScheme,
    bool preferEphemeral,
    Map<String, Object?> options,
  );

  void cancelApple();
}

/// Native browser observability event stream. The native side streams event
/// maps (parsed Dart-side via `OidcNativeBrowserEvent.fromMap`). Only one
/// platform is active at a time, so a single event channel is unambiguous.
@EventChannelApi()
abstract class OidcNativeEventApi {
  Map<String, Object?> streamNativeEvents();
}
