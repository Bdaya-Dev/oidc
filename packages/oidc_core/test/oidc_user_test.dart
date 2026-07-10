@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

String _unsignedIdToken(Map<String, dynamic> claims) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(
            JsonWebKey.fromJson({
              'kty': 'oct',
              'k': base64Url.encode(utf8.encode('x' * 32)).replaceAll('=', ''),
              'alg': 'HS256',
            }),
            algorithm: 'HS256',
          ))
        .build()
        .toCompactSerialization();

Map<String, dynamic> _claims({
  String sub = 'user-1',
  String iss = 'https://op.example.com',
}) => {
  'iss': iss,
  'sub': sub,
  'aud': 'client-1',
  'exp':
      clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
};

OidcToken _token(String idToken) => OidcToken(
  idToken: idToken,
  accessToken: 'at',
  tokenType: 'Bearer',
  expiresIn: const Duration(hours: 1),
  creationTime: clock.now(),
);

void main() {
  group('OidcUser.fromIdToken (unverified path)', () {
    test('parses claims and exposes uid/uidRequired', () async {
      final user = await OidcUser.fromIdToken(
        token: _token(_unsignedIdToken(_claims(sub: 'abc'))),
      );
      expect(user.uid, 'abc');
      expect(user.uidRequired, 'abc');
      expect(user.claims.subject, 'abc');
      expect(user.parsedIdToken.isVerified, isNot(isTrue));
    });

    test('throws OidcException when there is no id_token', () async {
      final token = OidcToken(
        accessToken: 'at',
        tokenType: 'Bearer',
        creationTime: clock.now(),
      );
      await expectLater(
        OidcUser.fromIdToken(token: token),
        throwsA(isA<OidcException>()),
      );
    });

    test('idTokenOverride takes precedence over token.idToken', () async {
      final overrideIdToken = _unsignedIdToken(_claims(sub: 'override-sub'));
      final user = await OidcUser.fromIdToken(
        token: _token(_unsignedIdToken(_claims(sub: 'original-sub'))),
        idTokenOverride: overrideIdToken,
      );
      expect(user.uid, 'override-sub');
      expect(user.idToken, overrideIdToken);
    });

    test('uidRequired throws when sub is absent', () async {
      final claims = _claims()..remove('sub');
      final user = await OidcUser.fromIdToken(
        token: _token(_unsignedIdToken(claims)),
      );
      expect(user.uid, isNull);
      expect(() => user.uidRequired, throwsA(isA<TypeError>()));
    });
  });

  group('OidcUser attributes + userInfo aggregation', () {
    late OidcUser user;

    setUp(() async {
      user = await OidcUser.fromIdToken(
        token: _token(_unsignedIdToken(_claims(sub: 'u1'))),
        attributes: const {'a': 1},
        userInfo: const {'email': 'u1@example.com'},
      );
    });

    test('aggregatedClaims merges id_token claims and userInfo', () {
      expect(user.aggregatedClaims['sub'], 'u1');
      expect(user.aggregatedClaims['email'], 'u1@example.com');
    });

    test('attributes are exposed', () {
      expect(user.attributes, const {'a': 1});
      expect(user.userInfo, const {'email': 'u1@example.com'});
    });

    test('withUserInfo replaces userInfo and re-aggregates', () {
      final updated = user.withUserInfo(const {'name': 'New Name'});
      expect(updated.userInfo, const {'name': 'New Name'});
      expect(updated.aggregatedClaims['name'], 'New Name');
      // old userInfo key is gone from the aggregate
      expect(updated.aggregatedClaims.containsKey('email'), isFalse);
      // id_token claim survives
      expect(updated.aggregatedClaims['sub'], 'u1');
      // attributes preserved
      expect(updated.attributes, const {'a': 1});
    });

    test('setAttributes merges into existing attributes', () {
      final updated = user.setAttributes(const {'b': 2});
      expect(updated.attributes, const {'a': 1, 'b': 2});
      // original is unchanged (immutability)
      expect(user.attributes, const {'a': 1});
    });

    test('setAttributes overrides an existing key', () {
      final updated = user.setAttributes(const {'a': 99});
      expect(updated.attributes, const {'a': 99});
    });

    test('clearAttributes empties the attributes map', () {
      final cleared = user.clearAttributes();
      expect(cleared.attributes, isEmpty);
      // other state preserved
      expect(cleared.userInfo, const {'email': 'u1@example.com'});
      expect(cleared.uid, 'u1');
    });
  });

  group('OidcUser.replaceToken', () {
    test('keeps the parsed id_token when the id_token is unchanged', () async {
      final idToken = _unsignedIdToken(_claims(sub: 'same'));
      final user = await OidcUser.fromIdToken(token: _token(idToken));
      final newToken = OidcToken(
        idToken: idToken,
        accessToken: 'new-at',
        tokenType: 'Bearer',
        creationTime: clock.now(),
      );

      final replaced = await user.replaceToken(newToken);
      expect(replaced.idToken, idToken);
      expect(replaced.token.accessToken, 'new-at');
      // same parsed token instance is reused (not re-verified)
      expect(replaced.parsedIdToken, same(user.parsedIdToken));
    });

    test('re-parses when the id_token changes', () async {
      final user = await OidcUser.fromIdToken(
        token: _token(_unsignedIdToken(_claims(sub: 'old'))),
      );
      final newIdToken = _unsignedIdToken(_claims(sub: 'new'));
      final replaced = await user.replaceToken(
        OidcToken(
          idToken: newIdToken,
          accessToken: 'at',
          tokenType: 'Bearer',
          creationTime: clock.now(),
        ),
      );
      expect(replaced.uid, 'new');
      expect(replaced.parsedIdToken, isNot(same(user.parsedIdToken)));
    });

    test('merges token json, preferring new values over old', () async {
      final idToken = _unsignedIdToken(_claims());
      final user = await OidcUser.fromIdToken(token: _token(idToken));
      final replaced = await user.replaceToken(
        OidcToken(
          idToken: idToken,
          accessToken: 'newer-at',
          tokenType: 'Bearer',
          creationTime: clock.now(),
        ),
      );
      // new access token wins; refresh-less new token doesn't wipe old fields
      expect(replaced.token.accessToken, 'newer-at');
    });

    test('allowExpiredIdToken=true is recorded on the merged token', () async {
      final idToken = _unsignedIdToken(_claims());
      final user = await OidcUser.fromIdToken(token: _token(idToken));
      final replaced = await user.replaceToken(
        _token(idToken),
        allowExpiredIdToken: true,
      );
      expect(replaced.token.allowExpiredIdToken, isTrue);
    });

    test('allowExpiredIdToken defaults to clearing the flag', () async {
      final idToken = _unsignedIdToken(_claims());
      final user = await OidcUser.fromIdToken(token: _token(idToken));
      final replaced = await user.replaceToken(_token(idToken));
      expect(replaced.token.allowExpiredIdToken, isNot(isTrue));
    });

    test(
      'falls back to the existing id_token when the new token has none',
      () async {
        final idToken = _unsignedIdToken(_claims(sub: 'keep-me'));
        final user = await OidcUser.fromIdToken(token: _token(idToken));
        final replaced = await user.replaceToken(
          OidcToken(
            accessToken: 'at2',
            tokenType: 'Bearer',
            creationTime: clock.now(),
          ),
        );
        expect(replaced.idToken, idToken);
        expect(replaced.uid, 'keep-me');
      },
    );
  });
}
