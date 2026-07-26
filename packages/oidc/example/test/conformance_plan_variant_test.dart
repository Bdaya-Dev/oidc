@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/api.dart';

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

  test('the dynamic plan is rejected locally when request_type is sent', () {
    // A SECOND dimension with per-plan rules, found the same way as the first:
    //   Variant 'request_type' has been set by user, but test plan already
    //   sets this variant
    // Every other plan requires plain_http_request, so "always send it" looked
    // like a constant until this plan proved it was an assumption.
    expect(
      () => build('oidcc-client-dynamic-certification-test-plan'),
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
}
