import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(
    () async {
      // under normal circumstances this callback should NEVER be called, since
      // IntegrationTestWidgetsFlutterBinding will shutdown the test process before this is reached.

      // however when running integration tests on macos, web, this might not happen and tests will hang forever.
      print(
        'tearDownAll is called, binding.allTestsPassed.isCompleted: ${binding.allTestsPassed.isCompleted}, binding.failureMethodsDetails.isEmpty: ${binding.failureMethodsDetails.isEmpty}.',
      );
      if (!binding.allTestsPassed.isCompleted) {
        print('binding.allTestsPassed was not completed, completing it...');

        binding.allTestsPassed.complete(binding.failureMethodsDetails.isEmpty);
      }

      print(
          'binding.allTestsPassed = ${await binding.allTestsPassed.future}, will attempt to call  binding.callbackManager.cleanup().');
      binding.callbackManager.cleanup();
      print('binding.callbackManager.cleanup() finished.');
    },
  );

  group('E2E', () {
    testWidgets('manager initializes correctly', (tester) async {
      example.main();
      expect(app_state.currentManager.didInit, false);
      await tester.pumpAndSettle();
      expect(app_state.currentManager.didInit, true);
    });
  });
}
