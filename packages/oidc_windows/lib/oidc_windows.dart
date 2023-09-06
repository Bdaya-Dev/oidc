import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// The Windows implementation of [OidcPlatform].
class OidcWindows extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc_windows');

  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith() {
    OidcPlatform.instance = OidcWindows();
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcStore store,
    OidcAuthorizePlatformSpecificOptions options,
  ) {
    throw UnimplementedError();
  }

  // @override
  // Future<String?> getPlatformName() {
  //   return methodChannel.invokeMethod<String>('getPlatformName');
  // }
}
