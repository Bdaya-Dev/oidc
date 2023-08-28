import 'package:oidc_core/oidc_core.dart';
// import 'package:http/http.dart' as http;

class OidcClientHelper {
  /// Input is the queryParameters from a redirected Url.
  ///
  /// Returns either an [OidcSuccessAuthResponse] or [OidcErrorAuthResponse].
  ///
  /// The contents of the returned [OidcSuccessAuthResponse] are entirely based on the sent request, specifically [response_type].
  ///
  /// * response_type containing code, returns [OidcSuccessAuthResponse.code]
  /// * response_type containing id_token, returns [OidcSuccessAuthResponse.idToken]
  /// * response_type containing token, returns [OidcSuccessAuthResponse.accessToken] and [OidcSuccessAuthResponse.tokenType]
  ///
  /// see: https://openid.net/specs/openid-connect-core-1_0.html#AuthorizationExamples
  static OidcAuthResponseBase parseRedirectResponse(
    Map<String, dynamic> queryParameters,
  ) =>
      OidcAuthResponseBase.fromJson(queryParameters);

  /// Validates a success response, and fills its missing data.
  // static Future<OidcAuthResponseBase> validateResponse({
  //   required OidcSuccessAuthResponse success,
  //   required Uri tokenEndpoint,
  //   required String grantType,
  //   required String clientId,
  //   http.Client? client,
  // }) async {
  //   client ??= http.Client();

  //   await client.post(
  //     tokenEndpoint,
  //     body: {},
  //   );
  // }
}
