import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('E2E', () {
    test('fetch discovery', () async {
      final url =
          Uri.parse('http://localhost:4011/.well-known/openid-configuration');
      try {
        final config = await OidcUtils.getConfiguration(url);
        // print(config);
        expect(config.issuer.toString(), 'http://localhost:4011');
      } on ClientException {
        print("Skipping test since server isn't up");
      }
    });
  });
}
