import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// An implementation of [OidcPlatform] that uses method channels.
class MethodChannelOidc extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc');

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }
}
