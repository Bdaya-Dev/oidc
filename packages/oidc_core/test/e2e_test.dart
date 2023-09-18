import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

import 'mock_client.dart';

void main() async {
  final serverUri = Uri.parse('http://accounts.google.com');
  final wellKnownUrl = OidcUtils.getOpenIdConfigWellKnownUri(serverUri);
  group('E2E', () {
    final client = createMockOidcClient();
    test('fetch discovery', () async {
      final config = await OidcEndpoints.getProviderMetadata(
        wellKnownUrl,
        client: client,
      );
      expect(config.issuer.toString(), 'https://accounts.google.com');
    });
    test(
      'token',
      () {},
    );
  });
}
