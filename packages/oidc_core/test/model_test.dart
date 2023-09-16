// ignore_for_file: avoid_redundant_argument_values

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Models', () {
    group('OidcState', () {
      test('Roundtrip', () {});
    });
    group('OidcClientAuthentication', () {
      test('Roundtrip', () {});
    });
    group('OidcErrorResponse', () {
      test('Roundtrip', () {});
    });
    group('OidcUserMetadata', () {
      //1 jan 2023 at 1 PM utc

      final pastCreationTime = DateTime.utc(2023, 1, 1, 10, 0);
      final now = DateTime.utc(2023, 1, 1, 11, 0);
      //issued tokens expire in 1 hour from creation time.
      const expiresInBase = Duration(hours: 1);
      //isAboutToExpire tolerance.
      const tolerance = Duration(minutes: 5);
      final refDates = <_TokenDateTest>[
        _TokenDateTest(
          creationTime: pastCreationTime,
          //expires after 1 hour, 10 minutes
          expiresIn: expiresInBase + tolerance * 2,
          tolerance: tolerance,
          isAboutToExpire: false,
          isExpired: false,
        ),
        _TokenDateTest(
          creationTime: pastCreationTime,
          //expires after 1 hour, 2.5 minutes
          expiresIn: expiresInBase + tolerance ~/ 2,
          tolerance: tolerance,
          isAboutToExpire: true,
          isExpired: false,
        ),
        _TokenDateTest(
          creationTime: pastCreationTime,
          //expires after 1 hour
          expiresIn: expiresInBase,
          tolerance: tolerance,
          isAboutToExpire: true,
          isExpired: false,
        ),
        _TokenDateTest(
          creationTime: pastCreationTime,
          //expires after 59 minutes
          expiresIn: expiresInBase - const Duration(seconds: 1),
          tolerance: tolerance,
          isAboutToExpire: true,
          isExpired: true,
        ),
        //created in the future
      ];
      for (final referenceDateEntry in refDates) {
        final createdAt = referenceDateEntry.creationTime;
        final isAboutToExpire = referenceDateEntry.isAboutToExpire;
        final isExpired = referenceDateEntry.isExpired;
        final expiresIn = referenceDateEntry.expiresIn;
        group('(referenceDate: $createdAt)', () {
          test('empty', () {
            final obj = OidcToken(creationTime: createdAt);
            expect(obj.expiresIn, isNull);
            expect(
              obj.calculateExpiresAt(),
              isNull,
            );
            expect(
              obj.calculateExpiresAt(overrideCreationTime: createdAt),
              isNull,
            );
            expect(
              obj.isAccessTokenAboutToExpire(now: now),
              true,
            );
            expect(
              obj.isAccessTokenExpired(now: now),
              true,
            );
          });
          test('not empty', () {
            final src = {
              OidcConstants_AuthParameters.accessToken: 'TlBN45jURg',
              OidcConstants_AuthParameters.tokenType: 'Bearer',
              OidcConstants_AuthParameters.refreshToken: '9yNOxJtZa5',
              OidcConstants_AuthParameters.expiresIn: expiresIn.inSeconds,
              OidcConstants_Store.expiresInReferenceDate:
                  createdAt.toIso8601String(),
            };
            final obj = OidcToken.fromJson(src);
            expect(obj.isOidc, false);
            expect(obj.toJson(), src);
            expect(obj.expiresIn, expiresIn);
            expect(
              obj.calculateExpiresAt(),
              createdAt.add(expiresIn),
            );
            //shifting input shifts output
            expect(
              obj.calculateExpiresAt(
                overrideCreationTime: createdAt.add(const Duration(seconds: 5)),
              ),
              createdAt.add(
                expiresIn + const Duration(seconds: 5),
              ),
            );
            expect(
              obj.isAccessTokenAboutToExpire(
                now: now,
                tolerance: tolerance,
              ),
              isAboutToExpire,
            );
            expect(
              obj.isAccessTokenExpired(
                now: now,
              ),
              isExpired,
            );
          });
        });
      }
    });
  });
}

class _TokenDateTest {
  const _TokenDateTest({
    required this.isAboutToExpire,
    required this.isExpired,
    required this.creationTime,
    required this.expiresIn,
    required this.tolerance,
  });

  final DateTime creationTime;
  final Duration expiresIn;
  final Duration tolerance;

  final bool isAboutToExpire;
  final bool isExpired;
}
