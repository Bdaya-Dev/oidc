@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oidc/oidc.dart';

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
    test('no plan restates a dimension at the MODULE endpoint', () {
      // This asserted the opposite until the suite's source explained the 500.
      // The observation was real:
      //   api/plan   -> "Variant 'client_registration' has been set by user,
      //                  but test plan already sets this variant"
      //   api/runner -> "createTestModule failed: Missing value for required
      //                  variant parameter: client_registration"
      // Forbidden on one endpoint, demanded by the other. But restating it to
      // satisfy api/runner only moved the failure: the value then joins the
      // arrayFilter that attaches the module to its plan, the stored entry
      // does not match, and the request 500s with "modifiedCount=0".
      //
      // Both complaints have one answer -- send NO variant, per
      // [moduleVariantComesFromPlan] -- so this map is empty and the rule it
      // encoded is recorded as a dead end rather than a fact.
      expect(
        moduleVariantFor('oidcc-client-dynamic-certification-test-plan'),
        isEmpty,
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

  // The WebFinger modules address the running test through an alias:
  // `acct:<alias>.<testName>@<host>`, parsed by the conformance suite's
  // TestDispatcher with
  //
  //   ^acct:([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)@.*$
  //
  // A dot inside the alias would be read as the alias/test-name separator, and
  // an alias the suite has no running test for answers 404. So the alias is not
  // cosmetic: without one the harness cannot name the test it is driving, and
  // no WebFinger module can resolve.
  group('conformance alias', () {
    const dynamicPlan = 'oidcc-client-dynamic-certification-test-plan';

    test('is legal for the suite dispatcher regex', () {
      final alias = conformanceAlias(planName: dynamicPlan, platform: 'linux');
      expect(alias, matches(RegExp(r'^[a-zA-Z0-9_-]+$')));
      expect(alias, isNot(contains('.')));
      expect(alias, isNotEmpty);
    });

    test('is distinct per platform so matrix jobs cannot collide', () {
      final seen = {
        for (final p in ['linux', 'web', 'android', 'ios', 'macos', 'windows'])
          p: conformanceAlias(planName: dynamicPlan, platform: p),
      };
      expect(seen.values.toSet(), hasLength(seen.length));
    });

    test('is distinct per plan', () {
      expect(
        conformanceAlias(planName: dynamicPlan, platform: 'linux'),
        isNot(
          conformanceAlias(
            planName: 'oidcc-client-basic-certification-test-plan',
            platform: 'linux',
          ),
        ),
      );
    });

    test('sanitises characters the dispatcher regex would reject', () {
      final alias = conformanceAlias(
        planName: 'weird.plan/name with spaces',
        platform: 'linux',
      );
      expect(alias, matches(RegExp(r'^[a-zA-Z0-9_-]+$')));
    });

    test('is required only by the plan whose modules use WebFinger', () {
      expect(planNeedsAlias(dynamicPlan), isTrue);
      for (final p in [
        'oidcc-client-basic-certification-test-plan',
        'oidcc-client-config-certification-test-plan',
        'oidcc-client-hybrid-certification-test-plan',
        'oidcc-client-test-3rd-party-init-login-test-plan',
      ]) {
        expect(planNeedsAlias(p), isFalse, reason: p);
      }
    });

    test('feeds a WebFinger identifier the library can normalize', () {
      // The whole point of the alias: it is the only handle the RP has on the
      // running test, and it reaches the suite through the identifier.
      final identifier = webFingerIdentifierFor(
        moduleName: 'oidcc-client-test-discovery-webfinger-acct',
        alias: conformanceAlias(planName: dynamicPlan, platform: 'linux'),
        host: 'www.certification.openid.net',
      );
      final normalized = OidcUtils.normalizeWebFingerIdentifier(identifier!);
      expect(normalized.host, 'www.certification.openid.net');
      expect(normalized.resource, startsWith('acct:'));
    });

    test('reaches the plan request body only when supplied', () {
      final (_, withAlias) = prepareTestPlanRequest(
        planName: dynamicPlan,
        description: 'd',
        clientId: 'c',
        redirectUri: 'http://localhost:22434',
        alias: 'oidc_linux',
        extraVariant: const {'client_auth_type': 'client_secret_basic'},
      );
      expect(withAlias['alias'], 'oidc_linux');

      final (_, withoutAlias) = prepareTestPlanRequest(
        planName: dynamicPlan,
        description: 'd',
        clientId: 'c',
        redirectUri: 'http://localhost:22434',
        extraVariant: const {'client_auth_type': 'client_secret_basic'},
      );
      expect(withoutAlias.containsKey('alias'), isFalse);
    });
  });

  // Dynamic RP's 500 was never a missing dimension. The suite attaches a new
  // module instance to its plan with a Mongo arrayFilter built from the variant
  // the CALLER sent (DBTestPlanService.updateTestPlanWithModule):
  //
  //   variant.getVariant().forEach((name, value) ->
  //       updateCriteria.and("module.variant." + name).is(value));
  //   updateCriteria.and("module.testModule").is(testName);
  //
  // Every dimension sent becomes another equality the stored module entry must
  // satisfy, so sending MORE over-constrains the filter and it matches nothing
  // -- "modifiedCount=0". Sending none is the supported path: TestRunner only
  // calls getFixedVariantIfOnlyOneMatchingModuleInPlan, which returns the
  // module's OWN stored variant, when no variant arrived from the API. That
  // value matches the filter by construction, whatever it happens to be.
  group('module variant that the plan owns is not restated', () {
    const dynamicPlan = 'oidcc-client-dynamic-certification-test-plan';

    test('the dynamic plan lets the suite supply the module variant', () {
      expect(moduleVariantComesFromPlan(dynamicPlan), isTrue);
    });

    test('every other plan still sends its own', () {
      for (final p in [
        'oidcc-client-basic-certification-test-plan',
        'oidcc-client-config-certification-test-plan',
        'oidcc-client-hybrid-certification-test-plan',
      ]) {
        expect(moduleVariantComesFromPlan(p), isFalse, reason: p);
      }
    });

    test('omitting the variant leaves it out of the query entirely', () {
      final uri = moduleInstanceUri(planId: 'p1', moduleName: 'm1');
      expect(uri.queryParameters.containsKey('variant'), isFalse);
      expect(uri.queryParameters['plan'], 'p1');
      expect(uri.queryParameters['test'], 'm1');
    });

    test('supplying one still encodes it', () {
      final uri = moduleInstanceUri(
        planId: 'p1',
        moduleName: 'm1',
        variant: const {'response_type': 'code'},
      );
      expect(uri.queryParameters['variant'], '{"response_type":"code"}');
    });
  });

  // The two identifier shapes the suite's dispatcher parses. They are not
  // interchangeable: each module validates the scheme of the resource it was
  // asked with, so the acct form sent to the URL module is refused with
  // "This test expects a webfinger request using URL syntax", and vice versa.
  group('WebFinger identifiers', () {
    const host = 'www.certification.openid.net';
    const alias = 'oidc_linux';

    test('the acct module wants acct:<alias>.<module>@<host>', () {
      expect(
        webFingerIdentifierFor(
          moduleName: 'oidcc-client-test-discovery-webfinger-acct',
          alias: alias,
          host: host,
        ),
        'acct:$alias.oidcc-client-test-discovery-webfinger-acct@$host',
      );
    });

    test('the url module wants https://<host>/<alias>/<module>', () {
      expect(
        webFingerIdentifierFor(
          moduleName: 'oidcc-client-test-discovery-webfinger-url',
          alias: alias,
          host: host,
        ),
        'https://$host/$alias/oidcc-client-test-discovery-webfinger-url',
      );
    });

    test('every other module resolves its issuer the ordinary way', () {
      for (final m in [
        'oidcc-client-test-discovery-openid-config',
        'oidcc-client-test-registration-dynamic',
        'oidcc-client-test',
      ]) {
        expect(
          webFingerIdentifierFor(moduleName: m, alias: alias, host: host),
          isNull,
          reason: m,
        );
      }
    });

    test('both identifiers normalize back to the suite host', () {
      for (final m in [
        'oidcc-client-test-discovery-webfinger-acct',
        'oidcc-client-test-discovery-webfinger-url',
      ]) {
        final identifier = webFingerIdentifierFor(
          moduleName: m,
          alias: alias,
          host: host,
        );
        expect(
          OidcUtils.normalizeWebFingerIdentifier(identifier!).host,
          host,
          reason: m,
        );
      }
    });
  });
}
