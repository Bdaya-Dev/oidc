import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcEndSessionRequest', () {
    test('generateUri', () {
      //
      final request = OidcEndSessionRequest(
        clientId: 'my-client',
        extra: {
          'hello': 'world',
          'hello2': 10,
        },
        idTokenHint:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c',
        logoutHint: 'my@email.com',
        postLogoutRedirectUri: Uri.parse('https://example.com/redirect'),
        state: 'my-state',
      );

      final uri = request
          .generateUri(Uri.parse('https://auth.example.com/logout?tid=123'));

      expect(
        uri.toString(),
        'https://auth.example.com/logout?tid=123&id_token_hint=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c&logout_hint=my%40email.com&client_id=my-client&post_logout_redirect_uri=https%3A%2F%2Fexample.com%2Fredirect&state=my-state&hello=world&hello2=10',
      );
    });
  });
}
