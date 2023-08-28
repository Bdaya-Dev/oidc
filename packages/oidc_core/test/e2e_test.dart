import 'package:http/http.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() async {
  final serverUri = Uri.parse('http://localhost:4011');
  final wellKnownUrl = OidcUtils.getWellKnownUriFromBase(serverUri);
  try {
    final config = await OidcUtils.getConfiguration(wellKnownUrl);
    // print(config);
    expect(config.issuer.toString(), serverUri.toString());
  } on ClientException {
    print("Skipping e2e tests since server isn't up");
    test('dummy', () {});
    return;
  }

  group('E2E', () {
    test('fetch discovery', () async {
      final config = await OidcUtils.getConfiguration(wellKnownUrl);
      // print(config);
      expect(config.issuer.toString(), 'http://localhost:4011');
    });
  });
}
