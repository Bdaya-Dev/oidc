import 'package:flutter/foundation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// Helper class for openid connect.
class Oidc {
  static OidcPlatform get _platform => OidcPlatform.instance;

  /// starts the authorization code flow, and returns the response.
  ///
  /// if the `request.responseType` is set to anything other than `code`, it returns null.
  ///
  /// NOTE: this DOES NOT do token exchange.
  ///
  /// consider using [OidcUtils.getProviderMetadata] to get the [metadata] parameter if you don't have it.
  static Future<OidcAuthorizeResponse?> getAuthorizationResponse({
    required OidcProviderMetadata metadata,
    required OidcAuthorizeRequest request,
    required OidcStore store,
    OidcAuthorizePlatformOptions options = const OidcAuthorizePlatformOptions(),
  }) {
    final respType = request.responseType;
    if (!respType.contains('code')) {
      return SynchronousFuture(null);
    }
    return _platform.getAuthorizationResponse(
      metadata,
      request,
      store,
      options,
    );
  }
}
