@TestOn('vm')
library;

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('mTLS client authentication (RFC 8705 §2)', () {
    test(
      'tls_client_auth emits only client_id in the body (RFC 8705 §2.1)',
      () {
        const auth = OidcClientAuthentication.tlsClientAuth(
          clientId: 'my-client',
        );

        expect(
          auth.location,
          OidcConstants_ClientAuthenticationMethods.tlsClientAuth,
        );
        expect(auth.location, 'tls_client_auth');
        // No Authorization header for a header-less auth method.
        expect(auth.getAuthorizationHeader(), isNull);
        // Body carries client_id and nothing else (no secret/assertion).
        expect(auth.getBodyParameters(), {'client_id': 'my-client'});
      },
    );

    test(
      'self_signed_tls_client_auth emits only client_id in the body '
      '(RFC 8705 §2.2)',
      () {
        const auth = OidcClientAuthentication.selfSignedTlsClientAuth(
          clientId: 'my-client',
        );

        expect(
          auth.location,
          OidcConstants_ClientAuthenticationMethods.selfSignedTlsClientAuth,
        );
        expect(auth.location, 'self_signed_tls_client_auth');
        expect(auth.getAuthorizationHeader(), isNull);
        expect(auth.getBodyParameters(), {'client_id': 'my-client'});
      },
    );

    test('resolveForRequest is a no-op for the mTLS methods', () {
      const auth = OidcClientAuthentication.tlsClientAuth(
        clientId: 'my-client',
      );
      final resolved = auth.resolveForRequest(
        Uri.parse('https://op.example.com/token'),
      );
      expect(identical(resolved, auth), isTrue);
    });
  });

  group('mtls_endpoint_aliases parsing (RFC 8705 §5)', () {
    OidcProviderMetadata parse(Map<String, dynamic> json) =>
        OidcProviderMetadata.fromJson(json);

    test('absent → mtlsEndpointAliases is null', () {
      final md = parse({
        'issuer': 'https://op.example.com',
        'token_endpoint': 'https://op.example.com/token',
      });
      expect(md.mtlsEndpointAliases, isNull);
    });

    test('present (full) → each typed getter resolves the alias', () {
      final md = parse({
        'issuer': 'https://op.example.com',
        'token_endpoint': 'https://op.example.com/token',
        'userinfo_endpoint': 'https://op.example.com/userinfo',
        'revocation_endpoint': 'https://op.example.com/revoke',
        'introspection_endpoint': 'https://op.example.com/introspect',
        'mtls_endpoint_aliases': {
          'token_endpoint': 'https://mtls.op.example.com/token',
          'userinfo_endpoint': 'https://mtls.op.example.com/userinfo',
          'revocation_endpoint': 'https://mtls.op.example.com/revoke',
          'introspection_endpoint': 'https://mtls.op.example.com/introspect',
          'registration_endpoint': 'https://mtls.op.example.com/register',
          'device_authorization_endpoint': 'https://mtls.op.example.com/device',
          'pushed_authorization_request_endpoint':
              'https://mtls.op.example.com/par',
        },
      });
      final aliases = md.mtlsEndpointAliases;
      expect(aliases, isNotNull);
      expect(
        aliases!.tokenEndpoint,
        Uri.parse('https://mtls.op.example.com/token'),
      );
      expect(
        aliases.userinfoEndpoint,
        Uri.parse('https://mtls.op.example.com/userinfo'),
      );
      expect(
        aliases.revocationEndpoint,
        Uri.parse('https://mtls.op.example.com/revoke'),
      );
      expect(
        aliases.introspectionEndpoint,
        Uri.parse('https://mtls.op.example.com/introspect'),
      );
      expect(
        aliases.registrationEndpoint,
        Uri.parse('https://mtls.op.example.com/register'),
      );
      expect(
        aliases.deviceAuthorizationEndpoint,
        Uri.parse('https://mtls.op.example.com/device'),
      );
      expect(
        aliases.pushedAuthorizationRequestEndpoint,
        Uri.parse('https://mtls.op.example.com/par'),
      );
    });

    test('partial → absent aliases are null, present ones parse', () {
      final md = parse({
        'issuer': 'https://op.example.com',
        'token_endpoint': 'https://op.example.com/token',
        'mtls_endpoint_aliases': {
          'token_endpoint': 'https://mtls.op.example.com/token',
          // userinfo/revocation/introspection deliberately omitted.
        },
      });
      final aliases = md.mtlsEndpointAliases!;
      expect(
        aliases.tokenEndpoint,
        Uri.parse('https://mtls.op.example.com/token'),
      );
      expect(aliases.userinfoEndpoint, isNull);
      expect(aliases.revocationEndpoint, isNull);
      expect(aliases.introspectionEndpoint, isNull);
    });

    test('generic getEndpoint reads an arbitrary aliased key', () {
      final md = parse({
        'issuer': 'https://op.example.com',
        'mtls_endpoint_aliases': {
          'token_endpoint': 'https://mtls.op.example.com/token',
        },
      });
      expect(
        md.mtlsEndpointAliases!.getEndpoint(
          OidcConstants_ProviderMetadata.tokenEndpoint,
        ),
        Uri.parse('https://mtls.op.example.com/token'),
      );
      expect(
        md.mtlsEndpointAliases!.getEndpoint(
          OidcConstants_ProviderMetadata.userinfoEndpoint,
        ),
        isNull,
      );
    });
  });

  group('tlsClientCertificateBoundAccessTokens metadata (RFC 8705 §3.3)', () {
    test('true is read', () {
      final md = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
        'tls_client_certificate_bound_access_tokens': true,
      });
      expect(md.tlsClientCertificateBoundAccessTokens, isTrue);
      expect(md.tlsClientCertificateBoundAccessTokensOrDefault, isTrue);
    });

    test('absent → null, OrDefault is false', () {
      final md = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
      });
      expect(md.tlsClientCertificateBoundAccessTokens, isNull);
      expect(md.tlsClientCertificateBoundAccessTokensOrDefault, isFalse);
    });
  });

  group('resolveEndpoint alias routing helper (RFC 8705 §5)', () {
    final md = OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'token_endpoint': 'https://op.example.com/token',
      'userinfo_endpoint': 'https://op.example.com/userinfo',
      'mtls_endpoint_aliases': {
        'token_endpoint': 'https://mtls.op.example.com/token',
        // userinfo has NO alias.
      },
    });

    test('disabled → always the top-level endpoint', () {
      expect(
        md.resolveEndpoint(OidcConstants_ProviderMetadata.tokenEndpoint),
        Uri.parse('https://op.example.com/token'),
      );
      expect(
        md.resolveEndpoint(OidcConstants_ProviderMetadata.userinfoEndpoint),
        Uri.parse('https://op.example.com/userinfo'),
      );
    });

    test('enabled + alias present → the alias', () {
      expect(
        md.resolveEndpoint(
          OidcConstants_ProviderMetadata.tokenEndpoint,
          useMtlsAliases: true,
        ),
        Uri.parse('https://mtls.op.example.com/token'),
      );
    });

    test('enabled + alias absent → falls back to the top-level endpoint', () {
      expect(
        md.resolveEndpoint(
          OidcConstants_ProviderMetadata.userinfoEndpoint,
          useMtlsAliases: true,
        ),
        Uri.parse('https://op.example.com/userinfo'),
      );
    });

    test('enabled but server publishes no aliases at all → top-level', () {
      final noAliases = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
        'token_endpoint': 'https://op.example.com/token',
      });
      expect(
        noAliases.resolveEndpoint(
          OidcConstants_ProviderMetadata.tokenEndpoint,
          useMtlsAliases: true,
        ),
        Uri.parse('https://op.example.com/token'),
      );
    });
  });

  group('DCR mTLS registration fields serialize (RFC 8705 §2.1.2 / §3.4)', () {
    test(
      'all tls_client_auth_* subject params + bound-token flag serialize',
      () {
        final req = OidcClientRegistrationRequest(
          redirectUris: [Uri.parse('https://rp.example.com/cb')],
          tokenEndpointAuthMethod:
              OidcConstants_ClientAuthenticationMethods.tlsClientAuth,
          tlsClientAuthSubjectDn: 'CN=client,O=Example,C=US',
          tlsClientAuthSanDns: 'client.example.com',
          tlsClientAuthSanUri: 'https://client.example.com',
          tlsClientAuthSanIp: '203.0.113.10',
          tlsClientAuthSanEmail: 'client@example.com',
          tlsClientCertificateBoundAccessTokens: true,
        );
        final map = req.toMap();
        expect(map['token_endpoint_auth_method'], 'tls_client_auth');
        expect(map['tls_client_auth_subject_dn'], 'CN=client,O=Example,C=US');
        expect(map['tls_client_auth_san_dns'], 'client.example.com');
        expect(map['tls_client_auth_san_uri'], 'https://client.example.com');
        expect(map['tls_client_auth_san_ip'], '203.0.113.10');
        expect(map['tls_client_auth_san_email'], 'client@example.com');
        expect(map['tls_client_certificate_bound_access_tokens'], true);
      },
    );

    test(
      'omitted mTLS fields are absent from the body (includeIfNull:false)',
      () {
        final req = OidcClientRegistrationRequest(
          redirectUris: [Uri.parse('https://rp.example.com/cb')],
        );
        final map = req.toMap();
        expect(map.containsKey('tls_client_auth_subject_dn'), isFalse);
        expect(map.containsKey('tls_client_auth_san_dns'), isFalse);
        expect(map.containsKey('tls_client_auth_san_uri'), isFalse);
        expect(map.containsKey('tls_client_auth_san_ip'), isFalse);
        expect(map.containsKey('tls_client_auth_san_email'), isFalse);
        expect(
          map.containsKey('tls_client_certificate_bound_access_tokens'),
          isFalse,
        );
      },
    );
  });

  group('OidcUserManagerSettings.useMtlsEndpointAliases', () {
    test('defaults to false', () {
      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('https://rp.example.com/cb'),
      );
      expect(settings.useMtlsEndpointAliases, isFalse);
    });

    test('is settable to true', () {
      final settings = OidcUserManagerSettings(
        redirectUri: Uri.parse('https://rp.example.com/cb'),
        useMtlsEndpointAliases: true,
      );
      expect(settings.useMtlsEndpointAliases, isTrue);
    });
  });
}
