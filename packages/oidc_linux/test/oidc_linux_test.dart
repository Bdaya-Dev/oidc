import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_linux/oidc_linux.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcLinux', () {
    const kPlatformName = 'Linux';
    late OidcLinux oidc;
    late List<MethodCall> log;

    setUp(() async {
      oidc = OidcLinux();

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
      OidcLinux.registerWith();
      expect(OidcPlatform.instance, isA<OidcLinux>());
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
