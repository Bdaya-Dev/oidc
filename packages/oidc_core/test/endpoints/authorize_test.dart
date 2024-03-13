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

      final url = request
          .generateUri(Uri.parse('https://auth.example.com/authorize?tid=123'));

      expect(
        url.toString(),
        'https://auth.example.com/authorize?tid=123&scope=openid&response_type=code&client_id=abc&redirect_uri=https%3A%2F%2Fexample.com%2Fredirect&max_age=20',
      );
    });
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
        OidcConstants_AuthorizeRequest_ResponseMode.fragment
      ]) {
        final (:parameters, :responseMode) =
            OidcEndpoints.resolveAuthorizeResponseParameters(
                responseUri: uri,
                resolveResponseModeByKey: 'state',
                responseMode: inputResponseMode);
        expect(
            responseMode, OidcConstants_AuthorizeRequest_ResponseMode.fragment);
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
      final (:parameters, :responseMode) =
          OidcEndpoints.resolveAuthorizeResponseParameters(
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
          isA<OidcException>().having((p0) => p0.message, 'message',
              contains("Couldn't resolve the response mode")),
        ),
      );
    });
  });
}
