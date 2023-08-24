import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_ios/oidc_ios.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcIOS', () {
    const kPlatformName = 'iOS';
    late OidcIOS oidc;
    late List<MethodCall> log;

    setUp(() async {
      oidc = OidcIOS();

      log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(oidc.methodChannel, (methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getPlatformName':
            return kPlatformName;
          default:
            return null;
        }
      });
    });

    test('can be registered', () {
      OidcIOS.registerWith();
      expect(OidcPlatform.instance, isA<OidcIOS>());
    });

    test('getPlatformName returns correct name', () async {
      final name = await oidc.getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(name, equals(kPlatformName));
    });
  });
}
