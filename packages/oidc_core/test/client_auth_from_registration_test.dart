import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

OidcClientRegistrationResponse _resp({
  String? clientId = 'reg-client',
  String? clientSecret,
  String? method,
}) => OidcClientRegistrationResponse.fromJson({
  'client_id': ?clientId,
  'client_secret': ?clientSecret,
  'token_endpoint_auth_method': ?method,
});

void main() {
  group('OidcClientAuthentication.fromRegistrationResponse', () {
    test('none → OidcClientAuthentication.none', () {
      final auth = OidcClientAuthentication.fromRegistrationResponse(
        _resp(method: OidcConstants_ClientAuthenticationMethods.none),
      );
      expect(
        auth.location,
        OidcConstants_ClientAuthenticationMethods.none,
      );
      expect(auth.clientId, 'reg-client');
      expect(auth.clientSecret, isNull);
    });

    test('client_secret_basic maps to clientSecretBasic with the secret', () {
      final auth = OidcClientAuthentication.fromRegistrationResponse(
        _resp(
          clientSecret: 's3cr3t',
          method: OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
        ),
      );
      expect(
        auth.location,
        OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
      );
      expect(auth.clientSecret, 's3cr3t');
      expect(auth.getAuthorizationHeader(), startsWith('Basic '));
    });

    test('client_secret_post maps to clientSecretPost with the secret', () {
      final auth = OidcClientAuthentication.fromRegistrationResponse(
        _resp(
          clientSecret: 's3cr3t',
          method: OidcConstants_ClientAuthenticationMethods.clientSecretPost,
        ),
      );
      expect(
        auth.location,
        OidcConstants_ClientAuthenticationMethods.clientSecretPost,
      );
      expect(auth.clientSecret, 's3cr3t');
      // client_secret_post carries the secret in the body, not a header.
      expect(auth.getAuthorizationHeader(), isNull);
      expect(auth.getBodyParameters()['client_secret'], 's3cr3t');
    });

    test(
      'client_secret_jwt maps to the generated variant that mints assertions',
      () {
        final auth = OidcClientAuthentication.fromRegistrationResponse(
          _resp(
            clientSecret: 's3cr3t',
            method: OidcConstants_ClientAuthenticationMethods.clientSecretJwt,
          ),
        );
        expect(
          auth.location,
          OidcConstants_ClientAuthenticationMethods.clientSecretJwt,
        );
        // The generated variant holds the secret internally (never on the
        // wire) and mints a fresh assertion per request.
        expect(auth.clientSecret, isNull);
        expect(auth.clientAssertion, isNull);
        final resolved = auth.resolveForRequest(
          Uri.parse('https://op.example.com/token'),
        );
        expect(resolved.clientAssertion, isNotNull);
        expect(
          resolved.clientAssertionType,
          OidcConstants_ClientAssertionTypes.jwtBearer,
        );
      },
    );

    test('defaults to client_secret_basic when the method is absent '
        '(RFC 7591 §2)', () {
      final auth = OidcClientAuthentication.fromRegistrationResponse(
        _resp(clientSecret: 's3cr3t'),
      );
      expect(
        auth.location,
        OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
      );
      expect(auth.clientSecret, 's3cr3t');
    });

    test(
      'preferredMethod overrides the response token_endpoint_auth_method',
      () {
        final auth = OidcClientAuthentication.fromRegistrationResponse(
          _resp(
            clientSecret: 's3cr3t',
            method: OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
          ),
          preferredMethod:
              OidcConstants_ClientAuthenticationMethods.clientSecretPost,
        );
        expect(
          auth.location,
          OidcConstants_ClientAuthenticationMethods.clientSecretPost,
        );
      },
    );

    test('throws when a secret-based method has no client_secret', () {
      expect(
        () => OidcClientAuthentication.fromRegistrationResponse(
          _resp(
            method: OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
          ),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('throws when the response has no client_id', () {
      expect(
        () => OidcClientAuthentication.fromRegistrationResponse(
          _resp(
            clientId: null,
            method: OidcConstants_ClientAuthenticationMethods.none,
          ),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('throws for private_key_jwt (key is never in the response)', () {
      expect(
        () => OidcClientAuthentication.fromRegistrationResponse(
          _resp(
            method: OidcConstants_ClientAuthenticationMethods.privateKeyJwt,
          ),
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('throws for an unknown/unsupported method', () {
      expect(
        () => OidcClientAuthentication.fromRegistrationResponse(
          _resp(method: 'tls_client_auth'),
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });
}
