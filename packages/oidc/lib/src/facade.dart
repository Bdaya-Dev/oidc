import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// Helper class for flutter-based openid connect clients.
class OidcFlutter {
  static OidcPlatform get _platform => OidcPlatform.instance;

  /// starts the authorization flow, and returns the response.
  ///
  /// on android/ios/macos, if the `request.responseType` is set to anything other than `code`, it returns null.
  ///
  /// NOTE: this DOES NOT do token exchange.
  ///
  /// consider using [OidcEndpoints.getProviderMetadata] to get the [metadata] parameter if you don't have it.
  static Future<OidcAuthorizeResponse?> getPlatformAuthorizationResponse({
    required OidcProviderMetadata metadata,
    required OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options = const OidcPlatformSpecificOptions(),
  }) async {
    try {
      return _platform.getAuthorizationResponse(
        metadata,
        request,
        options,
      );
    } catch (e, st) {
      throw OidcException(
        'Failed to authorize user',
        internalException: e,
        internalStackTrace: st,
      );
    }
  }

  /// starts the end session flow, and returns the response.
  ///
  /// consider using [OidcEndpoints.getProviderMetadata] to get the [metadata] parameter if you don't have it.
  static Future<OidcEndSessionResponse?> getPlatformEndSessionResponse({
    required OidcProviderMetadata metadata,
    required OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options = const OidcPlatformSpecificOptions(),
  }) async {
    try {
      return _platform.getEndSessionResponse(
        metadata,
        request,
        options,
      );
    } catch (e, st) {
      throw OidcException(
        'Failed to end user session',
        internalException: e,
        internalStackTrace: st,
      );
    }
  }
}
