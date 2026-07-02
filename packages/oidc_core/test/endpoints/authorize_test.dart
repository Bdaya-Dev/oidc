import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Authorize Request', () {
    test('basic parameters', () {
      final request = OidcAuthorizeRequest(
        clientId: 'abc',
        redirectUri: Uri.parse('https://example.com/redirect'),
        maxAge: const Duration(seconds: 20),
        scope: [OidcConstants_Scopes.openid],
        responseType: [OidcConstants_AuthorizationEndpoint_ResponseType.code],
      );

      final url = request.generateUri(
        Uri.parse('https://auth.example.com/authorize?tid=123'),
      );

      expect(
        url.toString(),
        'https://auth.example.com/authorize?tid=123&scope=openid&response_type=code&client_id=abc&redirect_uri=https%3A%2F%2Fexample.com%2Fredirect&max_age=20',
      );
    });
  });

  group('nonce required for implicit/hybrid (generateUri)', () {
    final ep = Uri.parse('https://auth.example.com/authorize');

    OidcAuthorizeRequest req({
      required List<String> responseType,
      String? nonce,
      Uri? requestUri,
      String? request,
    }) => OidcAuthorizeRequest(
      clientId: 'abc',
      redirectUri: Uri.parse('https://example.com/redirect'),
      scope: [OidcConstants_Scopes.openid],
      responseType: responseType,
      nonce: nonce,
      requestUri: requestUri,
      request: request,
    );

    Matcher throwsNonceException(Object messageMatcher) => throwsA(
      isA<OidcException>().having((e) => e.message, 'message', messageMatcher),
    );

    test('implicit id_token without nonce throws (cites §3.2.2.1)', () {
      expect(
        () => req(
          responseType: [
            OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
          ],
        ).generateUri(ep),
        throwsNonceException(contains('§3.2.2.1')),
      );
    });

    test('implicit "id_token token" without nonce throws', () {
      expect(
        () => req(
          responseType:
              OidcConstants_AuthorizationEndpoint_ResponseType.idToken_Token,
        ).generateUri(ep),
        throwsNonceException(contains('nonce is REQUIRED')),
      );
    });

    test('hybrid "code id_token" without nonce throws', () {
      expect(
        () => req(
          responseType: [
            OidcConstants_AuthorizationEndpoint_ResponseType.code,
            OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
          ],
        ).generateUri(ep),
        throwsNonceException(contains('nonce is REQUIRED')),
      );
    });

    test('hybrid "code token" without nonce throws (§3.3.2.1)', () {
      expect(
        () => req(
          responseType: [
            OidcConstants_AuthorizationEndpoint_ResponseType.code,
            OidcConstants_AuthorizationEndpoint_ResponseType.token,
          ],
        ).generateUri(ep),
        throwsNonceException(contains('§3.3.2.1')),
      );
    });

    test('empty-string nonce is treated as absent => throws', () {
      expect(
        () => req(
          responseType: [
            OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
          ],
          nonce: '',
        ).generateUri(ep),
        throwsNonceException(contains('nonce is REQUIRED')),
      );
    });

    test('single-element space-delimited "code id_token" throws', () {
      expect(
        () => req(responseType: ['code id_token']).generateUri(ep),
        throwsNonceException(contains('nonce is REQUIRED')),
      );
    });

    test('implicit id_token WITH a non-empty nonce succeeds', () {
      final url = req(
        responseType: [
          OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
        ],
        nonce: 'n-123',
      ).generateUri(ep);
      expect(url.queryParameters['nonce'], 'n-123');
      expect(url.queryParameters['response_type'], 'id_token');
    });

    test('pure code flow without nonce does NOT throw', () {
      final url = req(
        responseType: [OidcConstants_AuthorizationEndpoint_ResponseType.code],
      ).generateUri(ep);
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters.containsKey('nonce'), isFalse);
    });

    test('response_type "none" without nonce does NOT throw', () {
      final url = req(
        responseType: [OidcConstants_AuthorizationEndpoint_ResponseType.none],
      ).generateUri(ep);
      expect(url.queryParameters['response_type'], 'none');
    });

    test(
      'PAR-by-reference exemption: requestUri set, null nonce => no throw',
      () {
        final url = req(
          responseType: [
            OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
          ],
          requestUri: Uri.parse('urn:ietf:params:oauth:request_uri:abc'),
        ).generateUri(ep);
        expect(url.queryParameters.keys.toSet(), {'client_id', 'request_uri'});
        expect(url.queryParameters.containsKey('nonce'), isFalse);
      },
    );

    test('JAR-by-value exemption: request set, null nonce => no throw', () {
      final url = req(
        responseType: [
          OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
        ],
        request: 'signed.jwt.value',
      ).generateUri(ep);
      expect(url.queryParameters.keys.toSet(), {
        'client_id',
        'response_type',
        'scope',
        'request',
      });
      expect(url.queryParameters.containsKey('nonce'), isFalse);
    });

    test(
      'managed implicit flow regression: prepareImplicitFlowRequest',
      () async {
        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
          'scopes_supported': ['openid'],
        });
        final request = await OidcEndpoints.prepareImplicitFlowRequest(
          metadata: metadata,
          input: OidcSimpleImplicitFlowRequest(
            responseType: [
              OidcConstants_AuthorizationEndpoint_ResponseType.idToken,
            ],
            scope: [OidcConstants_Scopes.openid],
            clientId: 'abc',
            redirectUri: Uri.parse('https://example.com/redirect'),
          ),
        );
        final url = request.generateUri(ep);
        expect(url.queryParameters['nonce'], isNotNull);
        expect(url.queryParameters['nonce'], isNotEmpty);
      },
    );
  });
  group('resolveAuthorizeResponseParameters', () {
    test('fragment', () {
      //cspell: disable
      final uri = Uri.parse(
        'https://client.example.org/cb#'
        'access_token=SlAV32hkKG'
        '&token_type=bearer'
        '&id_token=eyJ0NiJ9.eyJ1cI6IjIifX0.DeWt4QuZXso'
        '&expires_in=3600'
        '&state=af0ifjsldkj',
      );

      //cspell: enable
      for (final inputResponseMode in <String?>[
        null,
        OidcConstants_AuthorizeRequest_ResponseMode.fragment,
      ]) {
        final (
          :parameters,
          :responseMode,
        ) = OidcEndpoints.resolveAuthorizeResponseParameters(
          responseUri: uri,
          resolveResponseModeByKey: 'state',
          responseMode: inputResponseMode,
        );
        expect(
          responseMode,
          OidcConstants_AuthorizeRequest_ResponseMode.fragment,
        );
        expect(parameters, containsPair('token_type', 'bearer'));
      }
    });

    test('query', () {
      //cspell: disable
      const state = 'af0ifjsldkj';
      final uri = Uri.parse(
        'https://client.example.org/cb?'
        'code=SplxlOBeZQQYbYS6WxSbIA'
        '&state=$state',
      );
      //cspell: enable
      final (
        :parameters,
        :responseMode,
      ) = OidcEndpoints.resolveAuthorizeResponseParameters(
        responseUri: uri,
        resolveResponseModeByKey: 'state',
      );
      expect(responseMode, OidcConstants_AuthorizeRequest_ResponseMode.query);
      expect(parameters, containsPair('state', state));
    });
    test('wrong key', () {
      //cspell: disable
      final uri = Uri.parse(
        'https://client.example.org/cb?'
        'code=SplxlOBeZQQYbYS6WxSbIA'
        '&state=af0ifjsldkj',
      );
      //cspell: enable
      expect(
        () => OidcEndpoints.resolveAuthorizeResponseParameters(
          responseUri: uri,
          resolveResponseModeByKey: 'anything',
        ),
        throwsA(
          isA<OidcException>().having(
            (p0) => p0.message,
            'message',
            contains("Couldn't resolve the response mode"),
          ),
        ),
      );
    });
  });
}
