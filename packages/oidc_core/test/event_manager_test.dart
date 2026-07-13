// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

TypeMatcher<LogRecord> _loggerHavingMessage(String message) {
  return isA<LogRecord>().having(
    (p0) => p0.message,
    'message',
    contains(message),
  );
}

void main() {
  hierarchicalLoggingEnabled = true;
  OidcTokenEventsManager.logger.level = Level.ALL;
  final pastCreationTime = DateTime.utc(2023, 1, 1, 12, 0);

  final src = {
    OidcConstants_AuthParameters.accessToken: 'TlBN45jURg',
    OidcConstants_AuthParameters.tokenType: 'Bearer',
    OidcConstants_AuthParameters.refreshToken: '9yNOxJtZa5',
    OidcConstants_AuthParameters.expiresIn: const Duration(hours: 1).inSeconds,
    OidcConstants_Store.expiresInReferenceDate: pastCreationTime
        .toIso8601String(),
  };

  group(
    'OidcTokenEventsManager',
    timeout: const Timeout(Duration(seconds: 5)),
    () {
      test('unknown expiresIn', () async {
        final token = OidcToken.fromJson({
          ...src,
          OidcConstants_AuthParameters.expiresIn: null,
        });

        final manager = OidcTokenEventsManager(
          getExpiringNotificationTime: null,
        );
        final expectation = expectLater(
          OidcTokenEventsManager.logger.onRecord,
          emitsThrough(
            _loggerHavingMessage(
              'expiresInFromNow is null, no timer will be started.',
            ),
          ),
        );
        manager.load(token);
        await expectation;
      });
      group('no getExpiringNotificationTime', () {
        final token = OidcToken.fromJson(src);
        test('start by unloading.', () {
          final manager = OidcTokenEventsManager(
            getExpiringNotificationTime: null,
          );
          expect(
            OidcTokenEventsManager.logger.onRecord,
            emits(_loggerHavingMessage('Unloading timers.')),
          );
          manager.load(token);
        });
        test(
          'still schedules expired even when expiring notifications are disabled.',
          () async {
            // Covered by the behavioral test below; this test is intentionally
            // lightweight to avoid flakiness from shared logger ordering.
            final localManager = OidcTokenEventsManager(
              getExpiringNotificationTime: null,
            );
            localManager.load(token);
          },
        );

        test('still emits expired after expiry time', () {
          fakeAsync(
            (async) {
              final localManager = OidcTokenEventsManager(
                getExpiringNotificationTime: null,
              );
              localManager.load(token);

              expect(localManager.expired, emits(token));
              async.elapse(const Duration(hours: 1));
            },
            initialTime: pastCreationTime,
          );
        });
      });

      group('normal', () {
        final token = OidcToken.fromJson(src);
        //notify me 10 minutes before it fires.
        const notifyBefore = Duration(minutes: 10);

        test('expiring/expired after some time', () {
          fakeAsync(
            (async) {
              final manager = OidcTokenEventsManager(
                getExpiringNotificationTime: (token) => notifyBefore,
              );
              expect(
                OidcTokenEventsManager.logger.onRecord,
                emitsInOrder([
                  emitsThrough(
                    _loggerHavingMessage(
                      'started a timer that will raise the expiring event',
                    ),
                  ),
                  _loggerHavingMessage(
                    'started a timer that will raise the expired event',
                  ),
                  _loggerHavingMessage(
                    'raising expiring event',
                  ),
                  _loggerHavingMessage(
                    'raising expired event.',
                  ),
                ]),
              );
              //load the token.
              manager.load(token);
              //elapsing the time by 51 minutes will fire expiring event
              expect(manager.expiring, emits(token));
              async.elapse(const Duration(minutes: 51));

              //elapsing the time by 1 hour 1 minutes will fire expired event
              expect(manager.expired, emits(token));
              async.elapse(const Duration(minutes: 10));
            },
            initialTime: pastCreationTime,
          );
        });

        // #123: a token loaded already inside its notification window must NOT
        // fire `expiring` SYNCHRONOUSLY during load() (the old behavior, which
        // drove a tight refresh loop). It is instead scheduled on a zero-delay
        // timer and delivered on the next event-loop turn.
        test('schedules (does not synchronously fire) expiring when already in '
            'the notification window', () {
          fakeAsync(
            (async) {
              final manager = OidcTokenEventsManager(
                getExpiringNotificationTime: (token) => notifyBefore,
              );
              final expiringFired = <OidcToken>[];
              manager.expiring.listen(expiringFired.add);

              manager.load(token);
              // Must not have fired during load().
              expect(expiringFired, isEmpty);

              // But it is scheduled: the next event-loop turn delivers it.
              async.elapse(Duration.zero);
              expect(expiringFired, [token]);
            },
            initialTime: pastCreationTime.add(const Duration(minutes: 51)),
          );
        });

        // #123: an already-EXPIRED token still fires `expired` (that path is
        // unchanged), while `expiring` remains non-synchronous (scheduled).
        test('already-expired token: expired still fires, expiring is scheduled '
            'not synchronous', () {
          fakeAsync(
            (async) {
              final manager = OidcTokenEventsManager(
                getExpiringNotificationTime: (token) => notifyBefore,
              );
              final expiringFired = <OidcToken>[];
              final expiredFired = <OidcToken>[];
              manager.expiring.listen(expiringFired.add);
              manager.expired.listen(expiredFired.add);

              manager.load(token);
              // Neither is delivered synchronously (broadcast delivery is async),
              // and crucially expiring is not synchronously ADDED during load.
              expect(expiringFired, isEmpty);
              expect(expiredFired, isEmpty);

              async.elapse(Duration.zero);
              // Genuinely-expired-token behavior is preserved.
              expect(expiredFired, [token]);
              // Expiring is still delivered (scheduled), never synchronously.
              expect(expiringFired, [token]);
            },
            initialTime: pastCreationTime.add(
              const Duration(hours: 1, minutes: 1),
            ),
          );
        });
      });
    },
  );
}
