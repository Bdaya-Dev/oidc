// ignore_for_file: prefer_single_quotes

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:http/src/request.dart';
import 'package:http/src/response.dart';
import 'package:http/testing.dart';
import 'package:oidc/oidc.dart';
// import 'package:oidc_core/oidc_core.dart';

Map<String, dynamic> createMockTokenResponse({
  required Map<String, dynamic> claimsJson,
  Duration expiresIn = const Duration(hours: 1),
}) {
  return {
    "access_token": clock.now().microsecondsSinceEpoch.toString(),
    "token_type": "Bearer",
    "refresh_token": "8xLOxBtZp8",
    "expires_in": expiresIn.inSeconds,
    "id_token": createIdToken(claimsJson: claimsJson),
  };
}

Map<String, dynamic> defaultIdTokenClaimsJson({DateTime? iat, DateTime? exp}) =>
    {
      "iss": "http://server.example.com",
      //id token expires after 1 hour
      "iat": (iat ?? clock.now()).secondsSinceEpoch,
      "exp":
          (exp ?? clock.now().add(const Duration(hours: 1))).secondsSinceEpoch,
      "aud": "my_client_id",
      "sub": "248289761001",
      "nonce": "n-0S6_WzA2Mj"
    };
String createIdToken({
  required Map<String, dynamic> claimsJson,
}) {
  final claims = JsonWebTokenClaims.fromJson(claimsJson);

  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims.toJson()
    ..addRecipient(
      JsonWebKey.fromJson({
        "kty": "oct",
        "k":
            "AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow"
      }),
      algorithm: "HS256",
    );
  final res = builder.build();
  return res.toCompactSerialization();
}

MockClient createMockOidcClient({
  MockClientHandler? beforeDefault,
  MockClientHandler? afterDefault,
}) {
  assert(
    (beforeDefault == null && afterDefault == null) ||
        (beforeDefault != null) ^ (afterDefault != null),
    'Either supply beforeDefault or afterDefault',
  );
  return MockClient(
    beforeDefault ??
        (request) => _handleRequest(request, afterDefault: afterDefault),
  );
}

const _eq = DeepCollectionEquality();
Future<Response> _handleRequest(
  Request request, {
  MockClientHandler? afterDefault,
}) async {
  final url = request.url;

  if (_eq.equals(url.pathSegments, ['.well-known', 'openid-configuration'])) {
    return Response(jsonEncode(mockProviderMetadata), 200);
  }
  if (url.pathSegments.first == 'token') {
    final tokenResp = createMockTokenResponse(
      claimsJson: defaultIdTokenClaimsJson(),
    );
    return Response(jsonEncode(tokenResp), 200);
  }
  if (afterDefault != null) {
    return afterDefault(request);
  }
  throw UnimplementedError(
    "Don't know how to handle the request ${request.url}",
  );
}

const mockProviderMetadata = {
  'issuer': 'http://server.example.com',
  'authorization_endpoint': 'http://server.example.com/authorize',
  'token_endpoint': 'http://server.example.com/token',
  'grant_types_supported': [
    OidcConstants_GrantType.authorizationCode,
    OidcConstants_GrantType.refreshToken,
  ]
};
const googleProviderMetadata = {
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
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256"],
  "scopes_supported": ["openid", "email", "profile"],
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
  "code_challenge_methods_supported": ["plain", "S256"],
  "grant_types_supported": [
    "authorization_code",
    "refresh_token",
    "urn:ietf:params:oauth:grant-type:device_code",
    "urn:ietf:params:oauth:grant-type:jwt-bearer"
  ]
};
