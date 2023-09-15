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
      final now = DateTime.utc(2023, 1, 1, 13, 0);
      const expiresInSeconds = 3600;
      final refDates =
          <(DateTime createdAt, bool isAboutToExpire, bool isExpired)>[
        (DateTime.utc(2023, 1, 1, 12, 0), true, false),
        (DateTime.utc(2023, 1, 1, 12, 2), false, false),
        (DateTime.utc(2023, 1, 1, 11, 59), true, true),
      ];
      for (final referenceDateEntry in refDates) {
        final createdAt = referenceDateEntry.$1;
        final isAboutToExpire = referenceDateEntry.$2;
        final isExpired = referenceDateEntry.$3;
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
              createdAt,
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
              OidcConstants_AuthParameters.expiresIn: expiresInSeconds,
              OidcConstants_Store.expiresInReferenceDate: createdAt,
            };
            final obj = OidcToken.fromJson(src);
            expect(obj.toJson(), src);
            expect(obj.expiresIn, const Duration(seconds: expiresInSeconds));
            expect(
              obj.calculateExpiresAt(),
              createdAt.add(const Duration(seconds: expiresInSeconds)),
            );
            //shifting input shifts output
            expect(
              obj.calculateExpiresAt(
                overrideCreationTime: createdAt.add(const Duration(seconds: 5)),
              ),
              createdAt.add(const Duration(seconds: 5 + expiresInSeconds)),
            );
            expect(
              obj.isAccessTokenAboutToExpire(now: now),
              isAboutToExpire,
            );
            expect(
              obj.isAccessTokenExpired(now: now),
              isExpired,
            );
          });
        });
      }
    });
  });
}
