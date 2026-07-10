import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JsonWebTokenClaims getters', () {
    test('exposes all registered claim getters', () {
      final claims = JsonWebTokenClaims.fromJson({
        'iss': 'https://issuer.example.com',
        'sid': 'session-123',
        'sub': 'subject-42',
        'aud': ['client-a', 'client-b'],
        'exp': 1300819380,
        'nbf': 1300819000,
        'iat': 1300818900,
        'jti': 'unique-id',
      });

      expect(claims.issuer, Uri.parse('https://issuer.example.com'));
      expect(claims.sid, 'session-123');
      expect(claims.subject, 'subject-42');
      expect(claims.audience, ['client-a', 'client-b']);
      expect(claims.expiry,
          DateTime.fromMillisecondsSinceEpoch(1300819380 * 1000));
      expect(claims.notBefore,
          DateTime.fromMillisecondsSinceEpoch(1300819000 * 1000));
      expect(claims.issuedAt,
          DateTime.fromMillisecondsSinceEpoch(1300818900 * 1000));
      expect(claims.jwtId, 'unique-id');
    });

    test('audience accepts a single string value', () {
      final claims = JsonWebTokenClaims.fromJson({'aud': 'only-client'});
      expect(claims.audience, ['only-client']);
    });
  });

  group('JsonWebTokenClaims.validate', () {
    // A fixed clock so expiry math is deterministic.
    final now = DateTime.utc(2022, 1, 1, 12, 0, 0);
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

    Iterable<JoseException> validateAt(
      DateTime at,
      JsonWebTokenClaims claims, {
      Duration expiryTolerance = Duration.zero,
      Uri? issuer,
      String? clientId,
    }) {
      return withClock(Clock.fixed(at), () {
        return claims
            .validate(
              expiryTolerance: expiryTolerance,
              issuer: issuer,
              clientId: clientId,
            )
            .toList();
      });
    }

    test('a valid, unexpired token yields no exceptions', () {
      final claims = JsonWebTokenClaims.fromJson({
        'iss': 'https://issuer.example.com',
        'aud': ['my-client'],
        'exp': nowSeconds + 3600,
      });

      final errors = validateAt(
        now,
        claims,
        issuer: Uri.parse('https://issuer.example.com'),
        clientId: 'my-client',
      );
      expect(errors, isEmpty);
    });

    test('reports an expired token', () {
      final claims = JsonWebTokenClaims.fromJson({
        'exp': nowSeconds - 3600,
      });

      final errors = validateAt(now, claims);
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('expired'));
    });

    test('respects the expiry tolerance', () {
      final claims = JsonWebTokenClaims.fromJson({
        'exp': nowSeconds - 30,
      });

      // Within tolerance -> accepted.
      expect(
        validateAt(now, claims, expiryTolerance: const Duration(minutes: 1)),
        isEmpty,
      );
      // Beyond tolerance -> rejected.
      expect(
        validateAt(now, claims, expiryTolerance: const Duration(seconds: 5)),
        hasLength(1),
      );
    });

    test('reports an issuer mismatch', () {
      final claims = JsonWebTokenClaims.fromJson({
        'iss': 'https://evil.example.com',
        'exp': nowSeconds + 3600,
      });

      final errors = validateAt(
        now,
        claims,
        issuer: Uri.parse('https://issuer.example.com'),
      );
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('Issuer does not match'));
    });

    test('reports a clientId not present in the audience', () {
      final claims = JsonWebTokenClaims.fromJson({
        'aud': ['someone-else'],
        'exp': nowSeconds + 3600,
      });

      final errors = validateAt(now, claims, clientId: 'my-client');
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('clientId'));
    });

    test('reports a missing audience when clientId is required', () {
      final claims = JsonWebTokenClaims.fromJson({
        'exp': nowSeconds + 3600,
      });

      final errors = validateAt(now, claims, clientId: 'my-client');
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('clientId'));
    });

    test('accumulates multiple validation errors', () {
      final claims = JsonWebTokenClaims.fromJson({
        'iss': 'https://evil.example.com',
        'aud': ['someone-else'],
        'exp': nowSeconds - 3600,
      });

      final errors = validateAt(
        now,
        claims,
        issuer: Uri.parse('https://issuer.example.com'),
        clientId: 'my-client',
      );
      expect(errors, hasLength(3));
    });
  });

  group('JsonWebToken verification state', () {
    final key = JsonWebKey.fromJson({
      'kty': 'oct',
      'k':
          'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
    })!;

    String signedJwt() {
      return (JsonWebSignatureBuilder()
            ..jsonContent = {'sub': 'user', 'exp': 9999999999}
            ..setProtectedHeader('typ', 'JWT')
            ..addRecipient(key, algorithm: 'HS256'))
          .build()
          .toCompactSerialization();
    }

    test('unverified() leaves isVerified null until a verify attempt', () {
      final jwt = JsonWebToken.unverified(signedJwt());
      expect(jwt.isVerified, isNull);
      expect(jwt.claims.subject, 'user');
    });

    test('verify() returns true and sets isVerified for the correct key',
        () async {
      final jwt = JsonWebToken.unverified(signedJwt());
      final ok = await jwt.verify(JsonWebKeyStore()..addKey(key));
      expect(ok, isTrue);
      expect(jwt.isVerified, isTrue);
    });

    test('verify() returns false and sets isVerified for a wrong key',
        () async {
      final jwt = JsonWebToken.unverified(signedJwt());
      final wrongKey = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'AAECAwQFBgcICQoLDA0ODw',
      })!;
      final ok = await jwt.verify(JsonWebKeyStore()..addKey(wrongKey));
      expect(ok, isFalse);
      expect(jwt.isVerified, isFalse);
    });
  });
}
