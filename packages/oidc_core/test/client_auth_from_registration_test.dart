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
      'no issued client_secret and no server-stated method → a PUBLIC client '
      '(none), not the client_secret_basic default',
      () {
        // RFC 7591 §3.2.1 makes `client_secret` OPTIONAL: an OP may issue a
        // client_id alone. §2 defines `none` as exactly that case ("the client
        // is a public client ... and does not have a client secret"), so the
        // §2 `client_secret_basic` default only describes a client that WAS
        // issued a secret.
        final auth = OidcClientAuthentication.fromRegistrationResponse(_resp());
        expect(
          auth.location,
          OidcConstants_ClientAuthenticationMethods.none,
        );
        expect(auth.clientId, 'reg-client');
        expect(auth.clientSecret, isNull);
        expect(auth.getAuthorizationHeader(), isNull);
        expect(auth.getBodyParameters(), isNot(contains('client_secret')));
      },
    );

    test(
      'the response token_endpoint_auth_method beats preferredMethod — OIDC '
      'Core §3.1.3.1 makes the REGISTERED method a MUST',
      () {
        // The inverse of what this asserted before. OIDC Core §3.1.3.1: "If
        // the Client is a Confidential Client, then it MUST authenticate to
        // the Token Endpoint using the authentication method registered for
        // its client_id" (§12.1 repeats it for refresh). Honouring a local
        // preference over the registered value authenticates one way against a
        // client_id registered another, which a conformant OP rejects.
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
          OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
        );
      },
    );

    test('preferredMethod decides when the response states none', () {
      // RFC 7591 §2 would otherwise default an OP-silent registration to
      // client_secret_basic unaided. Nothing was registered to contradict the
      // caller here, so the preference is not overriding anything.
      final auth = OidcClientAuthentication.fromRegistrationResponse(
        _resp(clientSecret: 's3cr3t'),
        preferredMethod:
            OidcConstants_ClientAuthenticationMethods.clientSecretPost,
      );
      expect(
        auth.location,
        OidcConstants_ClientAuthenticationMethods.clientSecretPost,
      );
    });

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
