import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The MacOS implementation of [OidcPlatform].
class OidcMacOS extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_macos');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcMacOS();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
