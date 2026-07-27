@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/api.dart';
import '../integration_test/shared_e2e.dart';

// The Config RP plan shipped broken: the harness sent request_type and
// client_registration, and the conformance suite answered
//
//   TestModule 'oidcc-client-test-discovery-openid-config' requires a value
//   for variant 'client_auth_type'
//
// as an HTTP 400 at plan creation. Nothing local objected, because
// `prepareTestPlanRequest` will happily build a request for any plan out of
// whatever dimensions it is handed. The Basic plan resolves client_auth_type
// on its own, so the omission was invisible on the only plan that had ever
// run, and the mistake could only be discovered by a CI round trip against a
// live third-party server.
//
// That round trip is the thing worth removing. A plan whose modules require a
// dimension must fail HERE, in an offline unit test, naming the dimension --
// not thirty minutes later as a 400 from certification.openid.net.
void main() {
  const configPlan = 'oidcc-client-config-certification-test-plan';
  const basicPlan = 'oidcc-client-basic-certification-test-plan';

  (String, Map<String, dynamic>) build(
    String planName, {
    Map<String, String>? extraVariant,
    String? requestType = 'plain_http_request',
  }) => prepareTestPlanRequest(
    planName: planName,
    description: 'test',
    clientId: 'my_client',
    redirectUri: 'http://localhost:22434',
    requestType: requestType,
    clientRegistration: 'static_client',
    extraVariant: extraVariant,
  );

  test('the config plan is rejected locally when client_auth_type is absent', () {
    expect(
      () => build(configPlan),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(contains('client_auth_type'), contains(configPlan)),
        ),
      ),
      reason:
          'the suite rejects this plan at creation without client_auth_type, '
          'so building the request must fail here rather than over the network',
    );
  });

  test('the hybrid plan is rejected locally when client_auth_type is sent', () {
    // The mirror image of the config case, and the reason this cannot be
    // reasoned out offline: the suite sets client_auth_type itself for these
    // plans and rejects any attempt to also set it.
    //
    //   Variant 'client_auth_type' has been set by user, but test plan
    //   already sets this variant for module 'oidcc-client-test'
    //
    // Basic defaults it, Config demands it, Hybrid/Implicit forbid it. Same
    // dimension, three rules, one HTTP 400 apiece to find out.
    expect(
      () => build(
        'oidcc-client-hybrid-certification-test-plan',
        extraVariant: {'client_auth_type': 'client_secret_basic'},
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('client_auth_type'),
        ),
      ),
    );
  });

  test('the hybrid plan builds when client_auth_type is left alone', () {
    final (path, _) = build('oidcc-client-hybrid-certification-test-plan');
    expect(path, isNot(contains('client_auth_type')));
  });

  test('the dynamic plan is rejected locally without client_auth_type', () {
    // Dynamic RP is the fourth distinct combination for the same three
    // dimensions: it FORBIDS request_type and client_registration, and
    // REQUIRES client_auth_type. Both forbidden rules were recorded from
    // earlier 400s; the required one was not, so the plan still failed at
    // creation:
    //   TestModule 'oidcc-client-test-discovery-webfinger-acct' requires a
    //   value for variant 'client_auth_type'
    expect(
      () => build(
        'oidcc-client-dynamic-certification-test-plan',
        requestType: null,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('client_auth_type'),
        ),
      ),
    );
  });

  test('the dynamic plan is rejected locally when request_type is sent', () {
    // A SECOND dimension with per-plan rules, found the same way as the first:
    //   Variant 'request_type' has been set by user, but test plan already
    //   sets this variant
    // Every other plan requires plain_http_request, so "always send it" looked
    // like a constant until this plan proved it was an assumption.
    // client_auth_type is supplied so the REQUIRED check passes and this
    // isolates the FORBIDDEN one; without it the required check fires first
    // and the assertion would pass on the wrong message.
    expect(
      () => build(
        'oidcc-client-dynamic-certification-test-plan',
        extraVariant: {'client_auth_type': 'client_secret_basic'},
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('request_type'),
        ),
      ),
    );
  });

  test('the config plan builds once client_auth_type is supplied', () {
    final (path, _) = build(
      configPlan,
      extraVariant: {'client_auth_type': 'client_secret_basic'},
    );
    expect(path, contains('client_auth_type'));
    expect(path, contains('client_secret_basic'));
  });

  test(
    'the basic plan still builds without it, because the suite defaults it',
    () {
      // Guards the fix against overcorrection: requiring the dimension
      // everywhere would break the one plan that is certified and green.
      final (path, _) = build(basicPlan);
      expect(path, isNot(contains('client_auth_type')));
    },
  );

  group('logout profiles are recognised so the harness logs out', () {
    // Four plans failed because the harness only ever logged in. The modules
    // wait for an end-session request, so each timed out at
    // flowTimeoutSeconds and reported no user.
    for (final plan in [
      'oidcc-client-rp-initiated-logout-rp-basic',
      'oidcc-client-front-channel-logout-rp-basic',
      'oidcc-client-back-channel-logout-rp-basic',
      'oidcc-client-rp-session-management-rp-basic',
      // Not wired yet; must still be recognised the day they are.
      'oidcc-client-rp-initiated-logout-rp-hybrid',
      'oidcc-client-back-channel-logout-rp-implicit',
    ]) {
      test('$plan drives a logout', () {
        expect(isLogoutConformancePlan(plan), isTrue);
      });
    }

    for (final plan in [
      'oidcc-client-basic-certification-test-plan',
      'oidcc-client-hybrid-certification-test-plan',
      'oidcc-client-config-certification-test-plan',
      'oidcc-client-formpost-basic-certification-test-plan',
    ]) {
      test('$plan does not', () {
        expect(isLogoutConformancePlan(plan), isFalse);
      });
    }
  });

  group('form_post needs an http(s) redirect', () {
    test('custom scheme cannot receive a form POST', () {
      expect(
        canReceiveFormPost(
          Uri.parse('com.bdayadev.oidc.example:/oauth2redirect'),
        ),
        isFalse,
        reason: 'a custom scheme is not an HTTP endpoint; no browser can POST',
      );
    });

    test('no transport in this harness can — not loopback, not web', () {
      // This test used to assert loopback and web COULD. That was the
      // predicate's implementation asserted back at itself, not a capability:
      //   * loopback — oidc_loopback_listener.dart:70 answers 405 to every
      //     non-GET, so a form POST never becomes a captured redirect.
      //   * web — redirect.html reads location.hash/search in JS; a POST body
      //     is not readable from the page at all.
      //   * custom scheme — not an HTTP endpoint; nothing can POST to it.
      // Until the loopback listener accepts POST, false everywhere is the
      // honest answer, and the plans skip with a reason instead of burning
      // 30s per module and failing with an Android-specific message on Linux.
      expect(canReceiveFormPost(Uri.parse('http://localhost:22434')), isFalse);
      expect(
        canReceiveFormPost(Uri.parse('http://localhost:22433/redirect.html')),
        isFalse,
      );
      expect(
        canReceiveFormPost(Uri.parse('com.bdayadev.oidc.example:/cb')),
        isFalse,
      );
    });

    test('the formpost plans are recognised, and others are not', () {
      for (final p in [
        'oidcc-client-formpost-basic-certification-test-plan',
        'oidcc-client-formpost-hybrid-certification-test-plan',
        'oidcc-client-formpost-implicit-certification-test-plan',
      ]) {
        expect(isFormPostConformancePlan(p), isTrue);
      }
      expect(
        isFormPostConformancePlan('oidcc-client-basic-certification-test-plan'),
        isFalse,
      );
    });
  });

  group('fragment responses need a transport that can carry a fragment', () {
    test('hybrid and implicit return fragments', () {
      expect(
        isFragmentResponsePlan('oidcc-client-hybrid-certification-test-plan'),
        isTrue,
      );
      expect(
        isFragmentResponsePlan('oidcc-client-implicit-certification-test-plan'),
        isTrue,
      );
    });

    test('formpost variants do NOT, despite -hybrid-/-implicit- in the id', () {
      // response_mode=form_post overrides the default, so these arrive as a
      // POST body. A naive substring match classifies them as fragment plans
      // and skips them for the wrong reason.
      for (final p in [
        'oidcc-client-formpost-hybrid-certification-test-plan',
        'oidcc-client-formpost-implicit-certification-test-plan',
      ]) {
        expect(isFragmentResponsePlan(p), isFalse, reason: p);
      }
    });

    test('the logout -rp-hybrid variants are not fragment plans either', () {
      expect(
        isFragmentResponsePlan('oidcc-client-rp-initiated-logout-rp-hybrid'),
        isFalse,
      );
    });

    test('loopback platforms cannot receive a fragment; others can', () {
      expect(canReceiveFragmentResponse('linux'), isFalse);
      expect(canReceiveFragmentResponse('windows'), isFalse);
      for (final p in ['macos', 'ios', 'android', 'web']) {
        expect(canReceiveFragmentResponse(p), isTrue, reason: p);
      }
    });
  });

  group(
    'third-party-initiated login needs an endpoint the app cannot host',
    () {
      test('the 3rd-party-init plan is recognised', () {
        expect(
          isThirdPartyInitPlan(
            'oidcc-client-test-3rd-party-init-login-test-plan',
          ),
          isTrue,
        );
      });

      test('ordinary plans are not', () {
        for (final p in [
          'oidcc-client-basic-certification-test-plan',
          'oidcc-client-dynamic-certification-test-plan',
          'oidcc-client-rp-initiated-logout-rp-basic',
        ]) {
          expect(isThirdPartyInitPlan(p), isFalse, reason: p);
        }
      });
    },
  );

  group('module-level variants differ from plan-level ones', () {
    test('dynamic requires client_registration at the MODULE endpoint', () {
      // The sharpest rule found in this whole exercise, and unguessable:
      //   api/plan   -> "Variant 'client_registration' has been set by user,
      //                  but test plan already sets this variant"
      //   api/runner -> "createTestModule failed: Missing value for required
      //                  variant parameter: client_registration"
      // Forbidden on one endpoint, required on the other, for the same
      // dimension of the same plan.
      expect(
        moduleVariantFor('oidcc-client-dynamic-certification-test-plan'),
        containsPair('client_registration', 'dynamic_client'),
      );
    });

    test('other plans send no extra module variant', () {
      for (final p in [
        'oidcc-client-basic-certification-test-plan',
        'oidcc-client-config-certification-test-plan',
        'oidcc-client-hybrid-certification-test-plan',
      ]) {
        expect(moduleVariantFor(p), isEmpty, reason: p);
      }
    });
  });
}
