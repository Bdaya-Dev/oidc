import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jose_plus/jose.dart';

/// A minimal local OIDC provider used to exercise the CLI's real HTTP flows
/// (discovery document + token endpoint + JWKS) without mocking any of the
/// SDK's HTTP layer, so id_token signature verification runs for real.
class TestOidcServer {
  TestOidcServer._(this.server, this._signingKey);

  /// The bound loopback server.
  final HttpServer server;
  final JsonWebKey _signingKey;

  /// The issuer URI (also the base URI) for this server.
  Uri get issuer => Uri.parse('http://127.0.0.1:${server.port}');

  /// Signs [payload] as a compact RS256 JWS, so tests exercise the
  /// production (fail-closed) id_token verification path.
  String signIdToken(Map<String, dynamic> payload) =>
      (JsonWebSignatureBuilder()
            ..jsonContent = payload
            ..addRecipient(_signingKey, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();

  Map<String, dynamic> _publicJwk() => {
    'kty': _signingKey['kty'],
    'n': _signingKey['n'],
    'e': _signingKey['e'],
    'alg': 'RS256',
    'use': 'sig',
  };

  /// Builds a standard successful token-endpoint JSON response, complete
  /// with a validly-signed id_token for [sub] (audience = [clientId]).
  Map<String, dynamic> tokenResponseJson({
    required String sub,
    String clientId = 'my-client',
    int expiresIn = 300,
    String accessToken = 'access-token-abc',
    String refreshToken = 'refresh-token-1',
  }) {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final idToken = signIdToken({
      'iss': issuer.toString(),
      'aud': clientId,
      'sub': sub,
      'iat': nowSeconds,
      'exp': nowSeconds + 300,
    });
    return {
      'access_token': accessToken,
      'id_token': idToken,
      'token_type': 'Bearer',
      'expires_in': expiresIn,
      'refresh_token': refreshToken,
    };
  }

  /// Starts a server that serves discovery + jwks, and delegates token
  /// requests to [onToken]. [onToken] receives the parsed
  /// `application/x-www-form-urlencoded` fields of the token request (e.g.
  /// `grant_type`, `username`, `refresh_token`) plus a 1-based call counter,
  /// and must return the JSON map to serve as the response.
  static Future<TestOidcServer> start({
    required FutureOr<Map<String, dynamic>> Function(
      Map<String, String> form,
      int callCount,
    )
    onToken,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final signingKey = JsonWebKey.generate('RS256');
    final testServer = TestOidcServer._(server, signingKey);
    var tokenCallCount = 0;

    server.listen((request) async {
      try {
        final path = request.uri.path;
        if (request.method == 'GET' &&
            path == '/.well-known/openid-configuration') {
          await _writeJson(request.response, {
            'issuer': testServer.issuer.toString(),
            'token_endpoint': testServer.issuer
                .replace(path: '/token')
                .toString(),
            'jwks_uri': testServer.issuer.replace(path: '/jwks').toString(),
            'id_token_signing_alg_values_supported': ['RS256'],
          });
          return;
        }
        if (request.method == 'GET' && path == '/jwks') {
          await _writeJson(request.response, {
            'keys': [testServer._publicJwk()],
          });
          return;
        }
        if (request.method == 'POST' && path == '/token') {
          tokenCallCount += 1;
          final bodyStr = await utf8.decoder.bind(request).join();
          final form = Uri.splitQueryString(bodyStr);
          final json = await onToken(form, tokenCallCount);
          await _writeJson(request.response, json);
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } on Object {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });

    return testServer;
  }

  /// Force-closes the server.
  Future<void> close() => server.close(force: true);

  static Future<void> _writeJson(HttpResponse response, Object json) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(json));
    await response.close();
  }
}
