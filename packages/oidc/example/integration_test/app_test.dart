// integration_test entrypoint (testWidgets) — used by the linux/windows CI
// jobs. It launches the real example app via its main()/runApp, which is fine
// under IntegrationTestWidgetsFlutterBinding. android/iOS/macOS/web run the
// same flow via Patrol (patrol_test/app_test.dart). Logic lives in
// shared_e2e.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc_example/main.dart' as example;

import 'shared_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ensureLoggingConfigured();

  group('E2E', () {
    if (oidcConformanceToken.isEmpty) {
      testWidgets('Simple manager initializes correctly', (tester) async {
        await runManagerSmokeTest(() async {
          example.main();
          await tester.pumpAndSettle();
        });
      });
    } else {
      testWidgets('OIDC Conformance: Basic RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        });
      });

      // The four logout profiles, discovered from the suite's own api/plan/available
      // rather than guessed. Note the shape: they do NOT use the
      // `-certification-test-plan` suffix the other profiles use, which is why no
      // amount of searching produced them and why every guessed id would have
      // 400ed. Each is pinned to the `-rp-basic` variant, matching the profile
      // this library is certified against.
      testWidgets('OIDC Conformance: RP-Initiated Logout', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-rp-initiated-logout-rp-basic',
          clientAuthType: 'client_secret_basic',
        );
      });

      testWidgets('OIDC Conformance: Front-Channel Logout', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-front-channel-logout-rp-basic',
          clientAuthType: 'client_secret_basic',
        );
      });

      testWidgets('OIDC Conformance: Back-Channel Logout', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-back-channel-logout-rp-basic',
          clientAuthType: 'client_secret_basic',
        );
      });

      testWidgets('OIDC Conformance: Session Management', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-rp-session-management-rp-basic',
          clientAuthType: 'client_secret_basic',
        );
      });

      // Form Post and 3rd-party-init, from the suite's published list. Variant
      // rules are unknown for these; they omit clientAuthType, matching the
      // plans they most resemble. A wrong choice is named by the plan-creation
      // diagnostic and pinned in api.dart, not rediscovered.
      testWidgets('OIDC Conformance: Form Post Basic RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        }, planName: 'oidcc-client-formpost-basic-certification-test-plan');
      });

      testWidgets('OIDC Conformance: Form Post Hybrid RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        }, planName: 'oidcc-client-formpost-hybrid-certification-test-plan');
      });

      testWidgets('OIDC Conformance: Form Post Implicit RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        }, planName: 'oidcc-client-formpost-implicit-certification-test-plan');
      });

      testWidgets('OIDC Conformance: 3rd Party-Init Login RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-test-3rd-party-init-login-test-plan',
          clientAuthType: 'client_secret_basic',
        );
      });

      // Dynamic RP: the client registers itself at the OP rather than being
      // pre-provisioned, so this is the one plan that does NOT take
      // static_client. `dynamic_client` is the documented counterpart already
      // named in the harness's own variant comment, not a guess at a new value.
      testWidgets('OIDC Conformance: Dynamic RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-dynamic-certification-test-plan',
          clientRegistration: 'dynamic_client',
          requestType: null,
        );
      });

      // See the Patrol harness for why each plan is a separate case.
      testWidgets('OIDC Conformance: Hybrid RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        }, planName: 'oidcc-client-hybrid-certification-test-plan');
      });

      testWidgets('OIDC Conformance: Implicit RP', (tester) async {
        await runOidcConformanceTest(() async {
          example.main();
          await tester.pumpAndSettle();
        }, planName: 'oidcc-client-implicit-certification-test-plan');
      });

      // See the Patrol harness for why Config RP is a separate case.
      testWidgets('OIDC Conformance: Config RP', (tester) async {
        await runOidcConformanceTest(
          () async {
            example.main();
            await tester.pumpAndSettle();
          },
          planName: 'oidcc-client-config-certification-test-plan',
          // The discovery module rejects the plan outright without this; the
          // Basic plan defaults it, this one does not.
          clientAuthType: 'client_secret_basic',
        );
      });
    }
  });
}
