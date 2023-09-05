import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_macos/oidc_macos.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcMacOS', () {
    const kPlatformName = 'MacOS';
    late OidcMacOS oidc;
    late List<MethodCall> log;

    setUp(() async {
      oidc = OidcMacOS();

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
      OidcMacOS.registerWith();
      expect(OidcPlatform.instance, isA<OidcMacOS>());
    });

    test('getPlatformName returns correct name', () async {
      // final name = await oidc.getPlatformName();
      // expect(
      //   log,
      //   <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      // );
      // expect(name, equals(kPlatformName));
    });
  });
}
