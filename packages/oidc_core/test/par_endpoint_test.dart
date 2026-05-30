@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

OidcAuthorizeRequest _authRequest() => OidcAuthorizeRequest(
  clientId: 'client-1',
  redirectUri: Uri.parse('com.example.app://cb'),
  responseType: const [OidcConstants_AuthorizationEndpoint_ResponseType.code],
  scope: const ['openid'],
  state: 'state-1',
);

void main() {
  test('pushAuthorizationRequest posts the authorize params and parses '
      'the request_uri + expires_in', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'request_uri': 'urn:ietf:params:oauth:request_uri:abc123',
          'expires_in': 60,
        }),
        201,
        headers: const {'content-type': 'application/json'},
      );
    });

    final resp = await OidcEndpoints.pushAuthorizationRequest(
      pushedAuthorizationRequestEndpoint: Uri.parse(
        'https://op.example.com/par',
      ),
      request: _authRequest(),
      client: client,
    );

    expect(
      resp.requestUri,
      Uri.parse('urn:ietf:params:oauth:request_uri:abc123'),
    );
    expect(resp.expiresIn, const Duration(seconds: 60));

    // The PAR endpoint receives the authorization parameters as a form POST.
    expect(captured.method, 'POST');
    expect(
      captured.headers['content-type'],
      contains('application/x-www-form-urlencoded'),
    );
    final body = Uri.splitQueryString(captured.body);
    expect(body['client_id'], 'client-1');
    expect(body['response_type'], 'code');
    expect(body['state'], 'state-1');
    expect(body['redirect_uri'], 'com.example.app://cb');
    expect(body['scope'], 'openid');
  });

  test('pushAuthorizationRequest surfaces an OAuth error response', () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'error': 'invalid_request',
          'error_description': 'bad par',
        }),
        400,
        headers: const {'content-type': 'application/json'},
      );
    });

    await expectLater(
      OidcEndpoints.pushAuthorizationRequest(
        pushedAuthorizationRequestEndpoint: Uri.parse(
          'https://op.example.com/par',
        ),
        request: _authRequest(),
        client: client,
      ),
      throwsA(isA<OidcException>()),
    );
  });
}
