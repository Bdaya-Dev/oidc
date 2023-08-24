import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Linux implementation of [OidcPlatform].
class OidcLinux extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_linux');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcLinux();
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
