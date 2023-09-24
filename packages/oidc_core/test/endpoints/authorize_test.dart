import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
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
