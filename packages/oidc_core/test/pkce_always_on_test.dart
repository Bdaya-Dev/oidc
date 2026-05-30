@TestOn('vm')
library;

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('PKCE is always on (OAuth 2.1 / RFC 9700)', () {
    OidcProviderMetadata meta(List<String>? methods) =>
        OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
          'token_endpoint': 'https://op.example.com/token',
          'code_challenge_methods_supported': ?methods,
        });

    Future<OidcAuthorizeRequest> prepare(OidcProviderMetadata m) async {
      final container = await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
        metadata: m,
        input: OidcSimpleAuthorizationCodeFlowRequest(
          clientId: 'client-1',
          redirectUri: Uri.parse('com.example.app://cb'),
          scope: const ['openid'],
        ),
      );
      return container.request;
    }

    const s256 = OidcConstants_AuthorizeRequest_CodeChallengeMethod.s256;
    const plain = OidcConstants_AuthorizeRequest_CodeChallengeMethod.plain;

    test('defaults to S256 even when metadata omits '
        'code_challenge_methods_supported (no downgrade)', () async {
      final req = await prepare(meta(null));
      expect(req.codeChallenge, isNotNull);
      expect(req.codeChallengeMethod, s256);
    });

    test('uses S256 when the OP advertises it', () async {
      final req = await prepare(meta([s256, plain]));
      expect(req.codeChallengeMethod, s256);
      expect(req.codeChallenge, isNotNull);
    });

    test('falls back to plain only when the OP supports plain but not '
        'S256', () async {
      final req = await prepare(meta([plain]));
      expect(req.codeChallengeMethod, plain);
      expect(req.codeChallenge, isNotNull);
    });
  });
}
