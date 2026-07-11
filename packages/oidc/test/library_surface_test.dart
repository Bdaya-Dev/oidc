import 'package:flutter_test/flutter_test.dart';
import 'package:oidc/oidc.dart';

// Every existing test in this suite that constructs `OidcUserManager` (both
// the eager and `.lazy` constructors) passes an explicit `id`, so
// `OidcUserManagerBase.id`'s documented "defaults to null when omitted"
// behavior is never actually asserted anywhere in this package -- even
// though `manager.id` is part of the public surface re-exported through
// this barrel.
void main() {
  group('oidc library surface', () {
    const clientCredentials = OidcClientAuthentication.none(
      clientId: 'client-1',
    );
    final settings = OidcUserManagerSettings(
      redirectUri: Uri.parse('https://app.example.com/cb'),
    );

    test('OidcUserManager (eager constructor) leaves id null when omitted', () {
      final manager = OidcUserManager(
        discoveryDocument: OidcProviderMetadata.fromJson(const {
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
          'token_endpoint': 'https://op.example.com/token',
        }),
        clientCredentials: clientCredentials,
        store: OidcMemoryStore(),
        settings: settings,
      );
      expect(manager.id, isNull);
      expect(manager.discoveryDocumentUri, isNull);
    });

    test('OidcUserManager.lazy leaves id null when omitted, and defers the '
        'discovery document uri instead of the document itself', () {
      final manager = OidcUserManager.lazy(
        discoveryDocumentUri: Uri.parse(
          'https://op.example.com/.well-known/openid-configuration',
        ),
        clientCredentials: clientCredentials,
        store: OidcMemoryStore(),
        settings: settings,
      );
      expect(manager.id, isNull);
      expect(
        manager.discoveryDocumentUri,
        Uri.parse('https://op.example.com/.well-known/openid-configuration'),
      );
    });
  });
}
