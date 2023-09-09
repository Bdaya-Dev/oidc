import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    testWidgets('manager initializes correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      expect(app_state.manager.didInit, true);
      // await tester.tap(find.text('Get Platform Name'));
      // await tester.pumpAndSettle();
      // final expected = expectedPlatformName();
      // await tester.ensureVisible(find.text('Platform Name: $expected'));
    });
  });
}

String expectedPlatformName() {
  if (isWeb) return 'Web';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'MacOS';
  if (Platform.isWindows) return 'Windows';
  throw UnsupportedError('Unsupported platform ${Platform.operatingSystem}');
}

bool get isWeb => identical(0, 0.0);
