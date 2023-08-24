import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:oidc_windows/oidc_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcWindows', () {
    const kPlatformName = 'Windows';
    late OidcWindows oidc;
    late List<MethodCall> log;

    setUp(() async {
      oidc = OidcWindows();

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
      OidcWindows.registerWith();
      expect(OidcPlatform.instance, isA<OidcWindows>());
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
