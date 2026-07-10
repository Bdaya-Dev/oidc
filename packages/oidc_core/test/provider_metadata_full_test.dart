import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// A discovery document that populates EVERY typed field, so the generated
/// `fromJson` exercises every "present" branch (the common case is a sparse
/// document that only hits the `== null` side).
Map<String, dynamic> _fullDiscovery() => {
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
  'userinfo_endpoint': 'https://op.example.com/userinfo',
  'jwks_uri': 'https://op.example.com/jwks',
  'registration_endpoint': 'https://op.example.com/register',
  'scopes_supported': ['openid', 'profile', 'email'],
  'response_types_supported': ['code', 'id_token'],
  'response_modes_supported': ['query', 'fragment'],
  'grant_types_supported': ['authorization_code', 'refresh_token'],
  'acr_values_supported': ['urn:mace:incommon:iap:silver'],
  'subject_types_supported': ['public', 'pairwise'],
  'id_token_signing_alg_values_supported': ['RS256', 'ES256'],
  'id_token_encryption_alg_values_supported': ['RSA-OAEP'],
  'id_token_encryption_enc_values_supported': ['A128GCM'],
  'userinfo_signing_alg_values_supported': ['RS256'],
  'userinfo_encryption_alg_values_supported': ['RSA-OAEP'],
  'userinfo_encryption_enc_values_supported': ['A128GCM'],
  'request_object_signing_alg_values_supported': ['RS256'],
  'request_object_encryption_alg_values_supported': ['RSA-OAEP'],
  'request_object_encryption_enc_values_supported': ['A128GCM'],
  'token_endpoint_auth_methods_supported': ['client_secret_basic'],
  'token_endpoint_auth_signing_alg_values_supported': ['RS256'],
  'display_values_supported': ['page', 'popup'],
  'claim_types_supported': ['normal'],
  'claims_supported': ['sub', 'iss', 'email'],
  'service_documentation': 'https://op.example.com/docs',
  'claims_locales_supported': ['en-US'],
  'ui_locales_supported': ['en-US', 'fr-FR'],
  'pushed_authorization_request_endpoint': 'https://op.example.com/par',
  'claims_parameter_supported': true,
  'authorization_response_iss_parameter_supported': true,
  'request_parameter_supported': true,
  'require_request_uri_registration': true,
  'request_uri_parameter_supported': false,
  'require_pushed_authorization_requests': true,
  'op_policy_uri': 'https://op.example.com/policy',
  'op_tos_uri': 'https://op.example.com/tos',
  'check_session_iframe': 'https://op.example.com/checksession',
  'end_session_endpoint': 'https://op.example.com/logout',
  'frontchannel_logout_supported': true,
  'frontchannel_logout_session_supported': true,
  'backchannel_logout_supported': true,
  'backchannel_logout_session_supported': true,
  'revocation_endpoint': 'https://op.example.com/revoke',
  'revocation_endpoint_auth_methods_supported': ['client_secret_basic'],
  'revocation_endpoint_auth_signing_alg_values_supported': ['RS256'],
  'introspection_endpoint': 'https://op.example.com/introspect',
  'introspection_endpoint_auth_methods_supported': ['client_secret_basic'],
  'introspection_endpoint_auth_signing_alg_values_supported': ['RS256'],
  'code_challenge_methods_supported': ['S256', 'plain'],
};

void main() {
  group('OidcProviderMetadata full fromJson', () {
    final parsed = OidcProviderMetadata.fromJson(_fullDiscovery());

    test('all Uri fields parse', () {
      expect(parsed.issuer, Uri.parse('https://op.example.com'));
      expect(
        parsed.authorizationEndpoint,
        Uri.parse('https://op.example.com/authorize'),
      );
      expect(parsed.tokenEndpoint, Uri.parse('https://op.example.com/token'));
      expect(
        parsed.userinfoEndpoint,
        Uri.parse('https://op.example.com/userinfo'),
      );
      expect(parsed.jwksUri, Uri.parse('https://op.example.com/jwks'));
      expect(
        parsed.registrationEndpoint,
        Uri.parse('https://op.example.com/register'),
      );
      expect(
        parsed.serviceDocumentation,
        Uri.parse('https://op.example.com/docs'),
      );
      expect(
        parsed.pushedAuthorizationRequestEndpoint,
        Uri.parse('https://op.example.com/par'),
      );
      expect(parsed.opPolicyUri, Uri.parse('https://op.example.com/policy'));
      expect(parsed.opTosUri, Uri.parse('https://op.example.com/tos'));
      expect(
        parsed.checkSessionIframe,
        Uri.parse('https://op.example.com/checksession'),
      );
      expect(
        parsed.endSessionEndpoint,
        Uri.parse('https://op.example.com/logout'),
      );
      expect(
        parsed.revocationEndpoint,
        Uri.parse('https://op.example.com/revoke'),
      );
      expect(
        parsed.introspectionEndpoint,
        Uri.parse('https://op.example.com/introspect'),
      );
    });

    test('all String-list fields parse', () {
      expect(parsed.scopesSupported, ['openid', 'profile', 'email']);
      expect(parsed.responseTypesSupported, ['code', 'id_token']);
      expect(parsed.responseModesSupported, ['query', 'fragment']);
      expect(parsed.grantTypesSupported, [
        'authorization_code',
        'refresh_token',
      ]);
      expect(parsed.acrValuesSupported, ['urn:mace:incommon:iap:silver']);
      expect(parsed.subjectTypesSupported, ['public', 'pairwise']);
      expect(parsed.idTokenSigningAlgValuesSupported, ['RS256', 'ES256']);
      expect(parsed.idTokenEncryptionAlgValuesSupported, ['RSA-OAEP']);
      expect(parsed.idTokenEncryptionEncValuesSupported, ['A128GCM']);
      expect(parsed.userinfoSigningAlgValuesSupported, ['RS256']);
      expect(parsed.userinfoEncryptionAlgValuesSupported, ['RSA-OAEP']);
      expect(parsed.userinfoEncryptionEncValuesSupported, ['A128GCM']);
      expect(parsed.requestObjectSigningAlgValuesSupported, ['RS256']);
      expect(parsed.requestObjectEncryptionAlgValuesSupported, ['RSA-OAEP']);
      expect(parsed.requestObjectEncryptionEncValuesSupported, ['A128GCM']);
      expect(parsed.tokenEndpointAuthMethodsSupported, ['client_secret_basic']);
      expect(parsed.tokenEndpointAuthSigningAlgValuesSupported, ['RS256']);
      expect(parsed.displayValuesSupported, ['page', 'popup']);
      expect(parsed.claimTypesSupported, ['normal']);
      expect(parsed.claimsSupported, ['sub', 'iss', 'email']);
      expect(parsed.claimsLocalesSupported, ['en-US']);
      expect(parsed.uiLocalesSupported, ['en-US', 'fr-FR']);
      expect(
        parsed.revocationEndpointAuthMethodsSupported,
        ['client_secret_basic'],
      );
      expect(
        parsed.revocationEndpointAuthSigningAlgValuesSupported,
        ['RS256'],
      );
      expect(
        parsed.introspectionEndpointAuthMethodsSupported,
        ['client_secret_basic'],
      );
      expect(
        parsed.introspectionEndpointAuthSigningAlgValuesSupported,
        ['RS256'],
      );
      expect(parsed.codeChallengeMethodsSupported, ['S256', 'plain']);
    });

    test('all bool fields parse (with their OrDefault getters)', () {
      expect(parsed.claimsParameterSupported, isTrue);
      expect(parsed.claimsParameterSupportedOrDefault, isTrue);
      expect(parsed.authorizationResponseIssParameterSupported, isTrue);
      expect(
        parsed.authorizationResponseIssParameterSupportedOrDefault,
        isTrue,
      );
      expect(parsed.requestParameterSupported, isTrue);
      expect(parsed.requireRequestUriRegistration, isTrue);
      expect(parsed.requestUriParameterSupported, isFalse);
      expect(parsed.requestUriParameterSupportedOrDefault, isFalse);
      expect(parsed.requirePushedAuthorizationRequests, isTrue);
      expect(parsed.requirePushedAuthorizationRequestsOrDefault, isTrue);
      expect(parsed.frontchannelLogoutSupportedOrDefault, isTrue);
      expect(parsed.frontchannelLogoutSessionSupportedOrDefault, isTrue);
      expect(parsed.backchannelLogoutSupportedOrDefault, isTrue);
      expect(parsed.backchannelLogoutSessionSupportedOrDefault, isTrue);
    });

    test('src preserves the raw json', () {
      expect(parsed.src['issuer'], 'https://op.example.com');
      expect(parsed.src['code_challenge_methods_supported'], ['S256', 'plain']);
    });
  });

  group('OidcProviderMetadata OrDefault getters when absent', () {
    final sparse = OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'jwks_uri': 'https://op.example.com/jwks',
      'token_endpoint': 'https://op.example.com/token',
    });

    test('grantTypesSupportedOrDefault falls back to code+implicit', () {
      expect(sparse.grantTypesSupported, isNull);
      expect(sparse.grantTypesSupportedOrDefault, const [
        'authorization_code',
        'implicit',
      ]);
    });

    test('requestUriParameterSupportedOrDefault defaults to true', () {
      expect(sparse.requestUriParameterSupported, isNull);
      expect(sparse.requestUriParameterSupportedOrDefault, isTrue);
    });

    test('requirePushedAuthorizationRequestsOrDefault defaults to false', () {
      expect(sparse.requirePushedAuthorizationRequestsOrDefault, isFalse);
    });

    test('claims/iss parameter OrDefault getters default to false', () {
      expect(sparse.claimsParameterSupportedOrDefault, isFalse);
      expect(
        sparse.authorizationResponseIssParameterSupportedOrDefault,
        isFalse,
      );
    });
  });

  group('OidcProviderMetadata copyWith', () {
    final base = OidcProviderMetadata.fromJson(_fullDiscovery());

    test('bulk copyWith replaces every field', () {
      final updated = base.copyWith(
        issuer: Uri.parse('https://new.example.com'),
        authorizationEndpoint: Uri.parse('https://new.example.com/a'),
        jwksUri: Uri.parse('https://new.example.com/jwks'),
        responseTypesSupported: const ['code'],
        subjectTypesSupported: const ['public'],
        idTokenSigningAlgValuesSupported: const ['ES256'],
        tokenEndpoint: Uri.parse('https://new.example.com/t'),
        userinfoEndpoint: Uri.parse('https://new.example.com/u'),
        registrationEndpoint: Uri.parse('https://new.example.com/r'),
        scopesSupported: const ['openid'],
        responseModesSupported: const ['query'],
        grantTypesSupported: const ['authorization_code'],
        acrValuesSupported: const ['acr'],
        idTokenEncryptionAlgValuesSupported: const ['A'],
        requestObjectSigningAlgValuesSupported: const ['B'],
        requestObjectEncryptionAlgValuesSupported: const ['C'],
        requestObjectEncryptionEncValuesSupported: const ['D'],
        tokenEndpointAuthSigningAlgValuesSupported: const ['E'],
        tokenEndpointAuthMethodsSupported: const ['F'],
        displayValuesSupported: const ['page'],
        claimTypesSupported: const ['normal'],
        claimsSupported: const ['sub'],
        serviceDocumentation: Uri.parse('https://new.example.com/docs'),
        claimsLocalesSupported: const ['en'],
        uiLocalesSupported: const ['en'],
        pushedAuthorizationRequestEndpoint: Uri.parse(
          'https://new.example.com/par',
        ),
        claimsParameterSupported: false,
        authorizationResponseIssParameterSupported: false,
        requestParameterSupported: false,
        requireRequestUriRegistration: false,
        requestUriParameterSupported: true,
        requirePushedAuthorizationRequests: false,
        opPolicyUri: Uri.parse('https://new.example.com/policy'),
        opTosUri: Uri.parse('https://new.example.com/tos'),
        checkSessionIframe: Uri.parse('https://new.example.com/cs'),
        endSessionEndpoint: Uri.parse('https://new.example.com/logout'),
        frontchannelLogoutSupported: false,
        frontchannelLogoutSessionSupported: false,
        backchannelLogoutSupported: false,
        backchannelLogoutSessionSupported: false,
        revocationEndpoint: Uri.parse('https://new.example.com/rev'),
        revocationEndpointAuthMethodsSupported: const ['G'],
        revocationEndpointAuthSigningAlgValuesSupported: const ['H'],
        introspectionEndpoint: Uri.parse('https://new.example.com/int'),
        introspectionEndpointAuthMethodsSupported: const ['I'],
        introspectionEndpointAuthSigningAlgValuesSupported: const ['J'],
        codeChallengeMethodsSupported: const ['S256'],
        idTokenEncryptionEncValuesSupported: const ['K'],
        userinfoSigningAlgValuesSupported: const ['L'],
        userinfoEncryptionAlgValuesSupported: const ['M'],
        userinfoEncryptionEncValuesSupported: const ['N'],
        src: const {'issuer': 'https://new.example.com'},
      );

      expect(updated.issuer, Uri.parse('https://new.example.com'));
      expect(updated.responseTypesSupported, const ['code']);
      expect(updated.idTokenSigningAlgValuesSupported, const ['ES256']);
      expect(updated.claimsParameterSupported, isFalse);
      expect(updated.requestUriParameterSupported, isTrue);
      expect(updated.codeChallengeMethodsSupported, const ['S256']);
      expect(updated.userinfoEncryptionEncValuesSupported, const ['N']);
      expect(updated.src, const {'issuer': 'https://new.example.com'});
    });

    test('single-field copyWith proxies leave other fields intact', () {
      final onlyIssuer = base.copyWith.issuer(Uri.parse('https://x.example'));
      expect(onlyIssuer.issuer, Uri.parse('https://x.example'));
      // untouched
      expect(onlyIssuer.tokenEndpoint, base.tokenEndpoint);
      expect(onlyIssuer.scopesSupported, base.scopesSupported);

      expect(
        base.copyWith.tokenEndpoint(Uri.parse('https://x/t')).tokenEndpoint,
        Uri.parse('https://x/t'),
      );
      expect(
        base.copyWith.jwksUri(Uri.parse('https://x/j')).jwksUri,
        Uri.parse('https://x/j'),
      );
      expect(
        base.copyWith.grantTypesSupported(const [
          'refresh_token',
        ]).grantTypesSupported,
        const ['refresh_token'],
      );
      expect(
        base.copyWith.scopesSupported(const ['openid']).scopesSupported,
        const ['openid'],
      );
      expect(
        base.copyWith.responseTypesSupported(const [
          'code',
        ]).responseTypesSupported,
        const ['code'],
      );
      expect(
        base.copyWith.subjectTypesSupported(const [
          'public',
        ]).subjectTypesSupported,
        const ['public'],
      );
      expect(
        base.copyWith
            .frontchannelLogoutSupported(false)
            .frontchannelLogoutSupported,
        isFalse,
      );
      expect(
        base.copyWith
            .backchannelLogoutSupported(false)
            .backchannelLogoutSupported,
        isFalse,
      );
      expect(
        base.copyWith.codeChallengeMethodsSupported(const [
          'plain',
        ]).codeChallengeMethodsSupported,
        const ['plain'],
      );
      expect(
        base.copyWith
            .endSessionEndpoint(Uri.parse('https://x/end'))
            .endSessionEndpoint,
        Uri.parse('https://x/end'),
      );
      expect(
        base.copyWith
            .revocationEndpoint(Uri.parse('https://x/rev'))
            .revocationEndpoint,
        Uri.parse('https://x/rev'),
      );
      expect(
        base.copyWith
            .introspectionEndpoint(Uri.parse('https://x/int'))
            .introspectionEndpoint,
        Uri.parse('https://x/int'),
      );
    });

    test('copyWith.src replaces only the raw src map', () {
      final updated = base.copyWith.src(const {'a': 'b'});
      expect(updated.src, const {'a': 'b'});
      expect(updated.issuer, base.issuer);
    });
  });
}
