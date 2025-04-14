import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    testWidgets('manager initializes correctly', (tester) async {
      example.main();
      expect(app_state.currentManager.didInit, false);
      await tester.pumpAndSettle();
      expect(app_state.currentManager.didInit, true);
    });

    // testWidgets(
    //   'login works',
    //   (tester) async {
    //     example.main();
    //     await tester.pumpAndSettle();
    //     // final loginFuture =
    //     //     app_state.currentManager.loginAuthorizationCodeFlow();
    //     // print('waiting for login future...');

    //     // await loginFuture;
    //   },
    // );
  });
}
