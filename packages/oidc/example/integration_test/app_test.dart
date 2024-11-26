import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/app_state.dart' as app_state;
import 'package:oidc_example/main.dart' as example;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(
    () async {
      print(
        'tearDownAll is called, binding.allTestsPassed.isCompleted: ${binding.allTestsPassed.isCompleted}, binding.failureMethodsDetails.isEmpty: ${binding.failureMethodsDetails.isEmpty}.',
      );
      if (!binding.allTestsPassed.isCompleted) {
        print('binding.allTestsPassed was not completed, completing it...');

        binding.allTestsPassed.complete(binding.failureMethodsDetails.isEmpty);
      }
      if (await binding.allTestsPassed.future) {
        print('tearDownAll is called AND allTestsPassed = true.');
      } else {
        print('tearDownAll is called AND allTestsPassed = false.');
      }
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
