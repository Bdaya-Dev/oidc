@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

final _key = JsonWebKey.generate('RS256');

JsonWebKeyStore _keystore() => JsonWebKeyStore()..addKey(_key);

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _base([Map<String, dynamic>? overrides]) {
  final m = <String, dynamic>{
    'iss': 'https://op.example.com',
    'aud': 'client-1',
    'iat': _epoch(clock.now()),
    'exp': _epoch(clock.now().add(const Duration(hours: 1))),
    'jti': 'jti-1',
    'sub': 'user-1',
    'events': {
      OidcConstants_JWTClaims.backchannelLogoutEvent: <String, dynamic>{},
    },
  };
  if (overrides != null) {
    m.addAll(overrides);
  }
  return m;
}

String _sign(Map<String, dynamic> claims, {JsonWebKey? key}) =>
    (JsonWebSignatureBuilder()
          ..jsonContent = claims
          ..addRecipient(key ?? _key, algorithm: 'RS256'))
        .build()
        .toCompactSerialization();

String _unsigned(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.${seg(claims)}.';
}

Future<JsonWebToken> _validate(
  String token, {
  List<String>? allowedAlgorithms = const ['RS256'],
  JsonWebKeyStore? keyStore,
  Duration? maxAge,
  Set<String>? seenJtis,
  Uri? issuer,
  String clientId = 'client-1',
}) => OidcEndpoints.validateLogoutToken(
  logoutToken: token,
  keyStore: keyStore ?? _keystore(),
  issuer: issuer ?? Uri.parse('https://op.example.com'),
  clientId: clientId,
  allowedAlgorithms: allowedAlgorithms,
  maxAge: maxAge,
  seenJtis: seenJtis,
);

void main() {
  group('valid tokens', () {
    test('sub only, RS256-signed, events {} present => returns JWT', () async {
      final jwt = await _validate(_sign(_base()));
      expect(jwt.claims.subject, 'user-1');
    });

    test('sid only (no sub) => accepted', () async {
      final claims = _base({'sid': 'sess-1'})..remove('sub');
      final jwt = await _validate(_sign(claims));
      expect(jwt.claims.sid, 'sess-1');
    });

    test('both sub and sid => accepted', () async {
      final jwt = await _validate(_sign(_base({'sid': 'sess-1'})));
      expect(jwt.claims.subject, 'user-1');
      expect(jwt.claims.sid, 'sess-1');
    });

    test('events member value is empty {} => ACCEPTED (MAY be empty)', () async {
      // The base fixture already uses an empty {} member; assert it explicitly.
      final claims = _base({
        'events': {
          OidcConstants_JWTClaims.backchannelLogoutEvent: <String, dynamic>{},
        },
      });
      final jwt = await _validate(_sign(claims));
      expect(jwt.isVerified, isTrue);
    });

    test('aud is a single string equal to clientId => accepted', () async {
      final jwt = await _validate(_sign(_base({'aud': 'client-1'})));
      expect(jwt.isVerified, isTrue);
    });
  });

  group('sub/sid (step 5)', () {
    test('neither sub nor sid present => reject', () async {
      final claims = _base()..remove('sub');
      await expectLater(
        _validate(_sign(claims)),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('events member (step 6)', () {
    test('events claim entirely missing => reject', () async {
      final claims = _base()..remove('events');
      await expectLater(
        _validate(_sign(claims)),
        throwsA(isA<OidcException>()),
      );
    });

    test(
      'events present but missing the backchannel-logout member => reject',
      () async {
        final claims = _base({
          'events': {
            'http://schemas.openid.net/event/other': <String, dynamic>{},
          },
        });
        await expectLater(
          _validate(_sign(claims)),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test(
      'backchannel-logout member is not a JSON object (string) => reject',
      () async {
        final claims = _base({
          'events': {
            OidcConstants_JWTClaims.backchannelLogoutEvent: 'not-an-object',
          },
        });
        await expectLater(
          _validate(_sign(claims)),
          throwsA(isA<OidcException>()),
        );
      },
    );
  });

  group('nonce prohibited (step 7)', () {
    test('nonce present (even with null value) => reject', () async {
      final claims = _base({'nonce': null});
      await expectLater(
        _validate(_sign(claims)),
        throwsA(isA<OidcException>()),
      );
    });

    test('nonce present with a value => reject', () async {
      final claims = _base({'nonce': 'n-1'});
      await expectLater(
        _validate(_sign(claims)),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('signature / alg (steps 2-3)', () {
    test(
      'alg:none token with allowedAlgorithms containing none => reject',
      () async {
        await expectLater(
          _validate(
            _unsigned(_base()),
            allowedAlgorithms: const ['RS256', 'none'],
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test('alg:none token with allowedAlgorithms == null => reject', () async {
      await expectLater(
        _validate(_unsigned(_base()), allowedAlgorithms: null),
        throwsA(isA<OidcException>()),
      );
    });

    test('tampered payload / bad signature => reject', () async {
      final valid = _sign(_base());
      final parts = valid.split('.');
      final tamperedPayload = base64Url
          .encode(utf8.encode(jsonEncode(_base({'sub': 'attacker'}))))
          .replaceAll('=', '');
      final tampered = '${parts[0]}.$tamperedPayload.${parts[2]}';
      await expectLater(
        _validate(tampered),
        throwsA(isA<OidcException>()),
      );
    });

    test(
      'verified with an irrelevant keyStore => reject (no unverified fallback)',
      () async {
        final foreign = JsonWebKeyStore()..addKey(JsonWebKey.generate('RS256'));
        await expectLater(
          _validate(_sign(_base()), keyStore: foreign),
          throwsA(isA<OidcException>()),
        );
      },
    );
  });

  group('iss/aud/exp (step 4)', () {
    test('iss != expected issuer => reject', () async {
      await expectLater(
        _validate(_sign(_base({'iss': 'https://attacker.example'}))),
        throwsA(isA<OidcException>()),
      );
    });

    test('aud does not contain clientId => reject', () async {
      await expectLater(
        _validate(_sign(_base({'aud': 'other-client'}))),
        throwsA(isA<OidcException>()),
      );
    });

    test(
      'exp missing => reject with clean OidcException (not a TypeError)',
      () async {
        final claims = _base()..remove('exp');
        await expectLater(
          _validate(_sign(claims)),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('exp'),
            ),
          ),
        );
      },
    );

    test('exp in the past beyond tolerance => reject', () async {
      final claims = _base({
        'exp': _epoch(clock.now().subtract(const Duration(minutes: 5))),
      });
      await expectLater(
        _validate(_sign(claims)),
        throwsA(isA<OidcException>()),
      );
    });

    test('exp slightly in past but within tolerance => accepted', () async {
      final claims = _base({
        'exp': _epoch(clock.now().subtract(const Duration(seconds: 30))),
      });
      final jwt = await _validate(_sign(claims));
      expect(jwt.isVerified, isTrue);
    });
  });

  group('iat / maxAge (step 4)', () {
    test('iat missing => reject', () async {
      final claims = _base()..remove('iat');
      await expectLater(
        _validate(_sign(claims)),
        throwsA(
          isA<OidcException>().having(
            (e) => e.message,
            'message',
            contains('iat'),
          ),
        ),
      );
    });

    test('maxAge set and iat older than maxAge+tolerance => reject', () async {
      final claims = _base({
        'iat': _epoch(clock.now().subtract(const Duration(minutes: 10))),
      });
      await expectLater(
        _validate(_sign(claims), maxAge: const Duration(minutes: 5)),
        throwsA(isA<OidcException>()),
      );
    });

    test('maxAge set and iat within the window => accepted', () async {
      final claims = _base({
        'iat': _epoch(clock.now().subtract(const Duration(minutes: 2))),
      });
      final jwt = await _validate(
        _sign(claims),
        maxAge: const Duration(minutes: 5),
      );
      expect(jwt.isVerified, isTrue);
    });
  });

  group('jti replay (step 8, OPTIONAL)', () {
    test(
      'same jti twice with a shared Set => first ok, second rejected',
      () async {
        final seen = <String>{};
        final token = _sign(_base());
        await _validate(token, seenJtis: seen);
        await expectLater(
          _validate(token, seenJtis: seen),
          throwsA(isA<OidcException>()),
        );
      },
    );

    test(
      'replay check disabled (seenJtis == null) => duplicate accepted',
      () async {
        final token = _sign(_base());
        await _validate(token);
        final jwt = await _validate(token);
        expect(jwt.isVerified, isTrue);
      },
    );
  });
}
