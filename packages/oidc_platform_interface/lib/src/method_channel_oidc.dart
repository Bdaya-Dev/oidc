import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:oidc_core/oidc_core.dart';
import 'models/authorize_options.dart';
import 'platform.dart';

/// An implementation of [OidcPlatform] that uses method channels.
class MethodChannelOidc extends OidcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('oidc');

  ///
  static const kgetPlatformName = 'getPlatformName';

  ///
  static const kgetAuthorizationResponse = 'getAuthorizationResponse';

  // @override
  // Future<String?> getPlatformName() {
  //   return methodChannel.invokeMethod<String>(kgetPlatformName);
  // }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcStore store,
    OidcAuthorizeState stateData,
    OidcAuthorizePlatformSpecificOptions options,
  ) {
    throw UnimplementedError();
  }
}
