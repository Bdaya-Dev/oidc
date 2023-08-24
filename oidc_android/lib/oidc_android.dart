import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Android implementation of [OidcPlatform].
class OidcAndroid extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_android');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcAndroid();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
