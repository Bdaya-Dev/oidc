import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_android/oidc_android.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OidcAndroid', () {
    const kPlatformName = 'Android';
    late OidcAndroid oidc;
    late List<MethodCall> log;

    setUp(() async {
      oidc = OidcAndroid();

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
      OidcAndroid.registerWith();
      expect(OidcPlatform.instance, isA<OidcAndroid>());
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
