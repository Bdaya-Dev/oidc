// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'package:clock/clock.dart';
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
    OidcConstants_Store.expiresInReferenceDate:
        pastCreationTime.toIso8601String(),
  };

  group(
    'OidcTokenEventsManager',
    timeout: const Timeout(Duration(seconds: 5)),
    () {
      test('unknown expiresIn', () {
        final token = OidcToken.fromJson({
          ...src,
          OidcConstants_AuthParameters.expiresIn: null,
        });

        final manager =
            OidcTokenEventsManager(getExpiringNotificationTime: null);
        expectLater(
          OidcTokenEventsManager.logger.onRecord,
          emitsThrough(
            _loggerHavingMessage(
                'expiresInFromNow is null, no timer will be started.'),
          ),
        );
        manager.load(token);
      });
      group('no getExpiringNotificationTime', () {
        final token = OidcToken.fromJson(src);

        final manager =
            OidcTokenEventsManager(getExpiringNotificationTime: null);
        test('start by unloading.', () {
          expect(
            OidcTokenEventsManager.logger.onRecord,
            emits(_loggerHavingMessage('Unloading timers.')),
          );
          manager.load(token);
        });
        test(
          'does not start timer.',
          () async {
            expect(
              OidcTokenEventsManager.logger.onRecord,
              emitsThrough(
                _loggerHavingMessage(
                  'expiringNotificationTime is null, no timer will be started.',
                ),
              ),
            );
            manager.load(token);
          },
        );
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

        test('fire expiring if time had already passed', () {
          withClock(
            Clock.fixed(
              pastCreationTime.add(const Duration(minutes: 51)),
            ),
            () {
              final manager = OidcTokenEventsManager(
                getExpiringNotificationTime: (token) => notifyBefore,
              );

              expect(
                OidcTokenEventsManager.logger.onRecord,
                emitsInOrder([
                  emitsThrough(
                    _loggerHavingMessage(
                      'loaded token was already expiring, raised expiring event.',
                    ),
                  ),
                  emits(_loggerHavingMessage(
                      'started a timer that will raise the expired event')),
                ]),
              );
              //elapsing the time by 51 minutes will fire expiring event
              expect(manager.expiring, emits(token));
              //load the token.
              manager.load(token);
            },
          );
        });

        test('fire expiring and expired if time had already passed', () {
          withClock(
            Clock.fixed(
              pastCreationTime.add(const Duration(hours: 1, minutes: 1)),
            ),
            () {
              final manager = OidcTokenEventsManager(
                getExpiringNotificationTime: (token) => notifyBefore,
              );

              expect(
                OidcTokenEventsManager.logger.onRecord,
                emitsInOrder([
                  emitsThrough(
                    _loggerHavingMessage(
                      'loaded token was already expiring, raised expiring event.',
                    ),
                  ),
                  emits(
                    _loggerHavingMessage(
                      'loaded token has already expired, raised expired event.',
                    ),
                  )
                ]),
              );
              //elapsing the time by 51 minutes will fire expiring event
              expect(manager.expiring, emits(token));
              expect(manager.expired, emits(token));
              //load the token.
              manager.load(token);
            },
          );
        });
      });
    },
  );
}
