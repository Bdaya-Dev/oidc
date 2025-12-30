import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
	group('OidcEndpoints.token', () {
		final tokenEndpoint = Uri.parse('https://server.example.com/token');

		test('omits Authorization header when credentials have no auth header', () async {
			late http.Request captured;
			final client = MockClient((request) async {
				captured = request;
				return http.Response(jsonEncode(<String, dynamic>{}), 200);
			});

			await OidcEndpoints.token(
				tokenEndpoint: tokenEndpoint,
				request: OidcTokenRequest.clientCredentials(),
				credentials: const OidcClientAuthentication.none(clientId: 'client'),
				headers: {'X-Test': '1'},
				client: client,
			);

			expect(captured.headers.containsKey('Authorization'), isFalse);
			expect(captured.headers['X-Test'], '1');

			// When no Authorization header is used, client authentication should be in the body.
			expect(captured.bodyFields['client_id'], 'client');
			expect(captured.bodyFields.containsKey('client_secret'), isFalse);
		});

		test('uses Authorization header for client_secret_basic and does not add body auth params', () async {
			late http.Request captured;
			final client = MockClient((request) async {
				captured = request;
				return http.Response(jsonEncode(<String, dynamic>{}), 200);
			});

			await OidcEndpoints.token(
				tokenEndpoint: tokenEndpoint,
				request: OidcTokenRequest.clientCredentials(),
				credentials: const OidcClientAuthentication.clientSecretBasic(
					clientId: 'client',
					clientSecret: 'secret',
				),
				client: client,
			);

			expect(captured.headers['Authorization'], startsWith('Basic '));
			// Since we rely on the Authorization header, auth params shouldn't be injected into body.
			expect(captured.bodyFields.containsKey('client_id'), isFalse);
			expect(captured.bodyFields.containsKey('client_secret'), isFalse);
		});
	});
}
