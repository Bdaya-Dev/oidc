@TestOn('vm')
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/api.dart';

// #467 review follow-up: CI run 37252425838 confirmed the Config RP plan's
// remaining per-module failures against real suite output (see api.dart's
// moduleFinishesBeforeUserinfo / requiresSecondLoginForKeyRotation docs for
// the suite-source citations). These tests pin the pure classification logic
// the harness now uses to drive those two modules correctly, and the
// transient-poll-retry decision added alongside it -- none of which need a
// live suite, or even a real Dio call, to verify.
void main() {
  group('moduleFinishesBeforeUserinfo', () {
    test('the jwks-uri-keys module finishes before userinfo', () {
      expect(
        moduleFinishesBeforeUserinfo(
          'oidcc-client-test-discovery-jwks-uri-keys',
        ),
        isTrue,
      );
    });

    test('other Config RP modules are unaffected', () {
      for (final module in [
        'oidcc-client-test-discovery-openid-config',
        'oidcc-client-test-discovery-issuer-mismatch',
        'oidcc-client-test-idtoken-sig-none',
        'oidcc-client-test-signing-key-rotation',
        'oidcc-client-test-signing-key-rotation-just-before-signing',
      ]) {
        expect(moduleFinishesBeforeUserinfo(module), isFalse, reason: module);
      }
    });
  });

  group('requiresSecondLoginForKeyRotation', () {
    test('the signing-key-rotation module needs a second login', () {
      expect(
        requiresSecondLoginForKeyRotation(
          'oidcc-client-test-signing-key-rotation',
        ),
        isTrue,
      );
    });

    test('the just-before-signing variant is a DIFFERENT module and is not '
        'matched by a substring/prefix check', () {
      // This module already passes with a single login (confirmed on CI run
      // 37252425838: status=FINISHED result=PASSED after one login) because
      // it rotates the key BEFORE signing the first id_token rather than
      // requiring a second interaction. A prefix or substring match on
      // 'oidcc-client-test-signing-key-rotation' would wrongly rope this
      // module into issuing (and waiting on) a second login it does not
      // need.
      expect(
        requiresSecondLoginForKeyRotation(
          'oidcc-client-test-signing-key-rotation-just-before-signing',
        ),
        isFalse,
      );
    });

    test('other Config RP modules are unaffected', () {
      for (final module in [
        'oidcc-client-test-discovery-openid-config',
        'oidcc-client-test-discovery-jwks-uri-keys',
        'oidcc-client-test-discovery-issuer-mismatch',
        'oidcc-client-test-idtoken-sig-none',
      ]) {
        expect(
          requiresSecondLoginForKeyRotation(module),
          isFalse,
          reason: module,
        );
      }
    });
  });

  group('isTransientConformancePollError', () {
    final path = RequestOptions(path: 'api/info/abc');

    DioException timeoutError(DioExceptionType type) =>
        DioException(requestOptions: path, type: type);

    DioException badResponse(int statusCode) => DioException(
      requestOptions: path,
      type: DioExceptionType.badResponse,
      response: Response<void>(requestOptions: path, statusCode: statusCode),
    );

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$type is transient', () {
        expect(isTransientConformancePollError(timeoutError(type)), isTrue);
      });
    }

    for (final statusCode in [500, 502, 503]) {
      test('a $statusCode response is transient', () {
        expect(
          isTransientConformancePollError(badResponse(statusCode)),
          isTrue,
        );
      });
    }

    for (final statusCode in [400, 401, 404, 422]) {
      test(
        'a $statusCode response is NOT transient (retrying cannot fix it)',
        () {
          expect(
            isTransientConformancePollError(badResponse(statusCode)),
            isFalse,
          );
        },
      );
    }

    for (final type in [
      DioExceptionType.cancel,
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
    ]) {
      test('$type is not transient', () {
        expect(isTransientConformancePollError(timeoutError(type)), isFalse);
      });
    }

    test('a non-DioException error is not transient', () {
      expect(isTransientConformancePollError(StateError('boom')), isFalse);
    });
  });

  group('retryTransientConformancePollErrors', () {
    const fastDelay = Duration(milliseconds: 1);
    final requestOptions = RequestOptions(path: 'api/info/abc');
    DioException transient() => DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionError,
    );
    DioException nonTransient() => DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<void>(requestOptions: requestOptions, statusCode: 404),
    );

    test('succeeds on the first attempt without retrying', () async {
      var calls = 0;
      final result = await retryTransientConformancePollErrors(() async {
        calls++;
        return 'ok';
      }, initialDelay: fastDelay);
      expect(result, 'ok');
      expect(calls, 1);
    });

    test(
      'retries a transient failure and returns the eventual success',
      () async {
        var calls = 0;
        final result = await retryTransientConformancePollErrors(
          () async {
            calls++;
            if (calls < 3) {
              throw transient();
            }
            return 'ok after retries';
          },
          maxAttempts: 5,
          initialDelay: fastDelay,
        );
        expect(result, 'ok after retries');
        expect(calls, 3);
      },
    );

    test(
      'does not retry a non-transient error: fails on the first attempt',
      () async {
        var calls = 0;
        await expectLater(
          retryTransientConformancePollErrors(
            () async {
              calls++;
              throw nonTransient();
            },
            maxAttempts: 5,
            initialDelay: fastDelay,
          ),
          throwsA(isA<DioException>()),
        );
        expect(
          calls,
          1,
          reason: 'a 404 cannot be fixed by waiting and retrying',
        );
      },
    );

    test('gives up after maxAttempts of a persistent transient error, without '
        'retrying forever', () async {
      var calls = 0;
      await expectLater(
        retryTransientConformancePollErrors(() async {
          calls++;
          throw transient();
        }, initialDelay: fastDelay),
        throwsA(isA<DioException>()),
      );
      expect(calls, 3, reason: 'the default maxAttempts is 3');
    });
  });

  // #469 web-job follow-up: the session-management plan runs for real on web
  // (it is markTestSkipped everywhere else -- see shared_e2e.dart's
  // supportsSessionManagement), and the module stayed at status=WAITING
  // because OidcSessionManagementSettings.enabled defaults to false and the
  // harness called logout() immediately after login, with no
  // check_session_iframe traffic at all. These tests pin the pure logic the
  // fix added: which module needs the setting turned on, and which suite log
  // message actually confirms a postMessage round trip (as opposed to merely
  // loading the iframe).
  group('requiresSessionManagementMonitoring', () {
    test('the session-management module needs it', () {
      expect(
        requiresSessionManagementMonitoring(
          'oidcc-client-test-session-management',
        ),
        isTrue,
      );
    });

    test('other Config/logout modules do not', () {
      for (final module in [
        'oidcc-client-test-discovery-openid-config',
        'oidcc-client-test-discovery-jwks-uri-keys',
        'oidcc-client-test-signing-key-rotation',
        'oidcc-client-test-rp-init-logout',
      ]) {
        expect(
          requiresSessionManagementMonitoring(module),
          isFalse,
          reason: module,
        );
      }
    });
  });

  group('isSessionCheckPostMessageLogEntry', () {
    test('matches the logged-in variant', () {
      expect(
        isSessionCheckPostMessageLogEntry(
          'OP iframe received postMessage request from RP iframe',
        ),
        isTrue,
      );
    });

    test(
      'matches the not-logged-in variant (same boolean flips either way)',
      () {
        expect(
          isSessionCheckPostMessageLogEntry(
            'OP iframe received postMessage request from RP iframe but the '
            'user is not logged in',
          ),
          isTrue,
        );
      },
    );

    test(
      'does NOT match merely loading the iframe -- that is a weaker signal',
      () {
        expect(
          isSessionCheckPostMessageLogEntry(
            'The client requested check_session_iframe',
          ),
          isFalse,
        );
      },
    );

    test('does not match an unrelated log message', () {
      expect(isSessionCheckPostMessageLogEntry('Setup Done'), isFalse);
    });

    test('does not match null', () {
      expect(isSessionCheckPostMessageLogEntry(null), isFalse);
    });
  });
}
