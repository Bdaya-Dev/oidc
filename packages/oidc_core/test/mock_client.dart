import 'package:collection/collection.dart';
import 'package:http/src/request.dart';
import 'package:http/src/response.dart';
import 'package:http/testing.dart';

MockClient createMockOidcClient() {
  return MockClient(_handleRequest);
}

const _eq = DeepCollectionEquality();
Future<Response> _handleRequest(Request request) async {
  final url = request.url;

  if (_eq.equals(url.pathSegments, ['.well-known', 'openid-configuration'])) {
    return Response(_googleProviderMetadata, 304);
  }
  if (url.pathSegments.first == 'token') {
    // TODO(ahmednfwela): add other types of responses based on request.
    return Response(_tokenResponse, 200);
  }
  throw UnimplementedError(
    "Don't know how to handle the request ${request.url}",
  );
}

const _tokenResponse = '''
{

}
''';

const _googleProviderMetadata = '''
{
 "issuer": "https://accounts.google.com",
 "authorization_endpoint": "https://accounts.google.com/o/oauth2/v2/auth",
 "device_authorization_endpoint": "https://oauth2.googleapis.com/device/code",
 "token_endpoint": "https://oauth2.googleapis.com/token",
 "userinfo_endpoint": "https://openidconnect.googleapis.com/v1/userinfo",
 "revocation_endpoint": "https://oauth2.googleapis.com/revoke",
 "jwks_uri": "https://www.googleapis.com/oauth2/v3/certs",
 "response_types_supported": [
  "code",
  "token",
  "id_token",
  "code token",
  "code id_token",
  "token id_token",
  "code token id_token",
  "none"
 ],
 "subject_types_supported": [
  "public"
 ],
 "id_token_signing_alg_values_supported": [
  "RS256"
 ],
 "scopes_supported": [
  "openid",
  "email",
  "profile"
 ],
 "token_endpoint_auth_methods_supported": [
  "client_secret_post",
  "client_secret_basic"
 ],
 "claims_supported": [
  "aud",
  "email",
  "email_verified",
  "exp",
  "family_name",
  "given_name",
  "iat",
  "iss",
  "locale",
  "name",
  "picture",
  "sub"
 ],
 "code_challenge_methods_supported": [
  "plain",
  "S256"
 ],
 "grant_types_supported": [
  "authorization_code",
  "refresh_token",
  "urn:ietf:params:oauth:grant-type:device_code",
  "urn:ietf:params:oauth:grant-type:jwt-bearer"
 ]
}''';
