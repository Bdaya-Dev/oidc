import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The iOS implementation of [OidcPlatform].
class OidcIOS extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_ios');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcIOS();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
