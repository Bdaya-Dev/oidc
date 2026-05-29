import 'dart:convert';
import 'dart:io';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JWK Examples from RFC7517', () {
    group('Example JSON Web Key Sets', () {
      test('Example Public Keys', () {
        var json = {
          'keys': [
            {
              'kty': 'EC',
              'crv': 'P-256',
              'x': 'MKBCTNIcKUSDii11ySs3526iDZ8AiTo7Tu6KPAqv7D4',
              'y': '4Etl6SRW2YiLUrN5vfvVHuhp7x8PxltmWWlbbM4IFyM',
              'use': 'enc',
              'kid': '1'
            },
            {
              'kty': 'RSA',
              'n': '0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx'
                  '4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMs'
                  'tn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2'
                  'QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbI'
                  'SD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqb'
                  'w0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw',
              'e': 'AQAB',
              'alg': 'RS256',
              'kid': '2011-04-29'
            }
          ]
        };

        var key1 = JsonWebKey.fromJson(json['keys']![0])!;

        expect(key1.keyType, 'EC');
        expect(key1.keyId, '1');
        expect(key1.publicKeyUse, 'enc');

        var key2 = JsonWebKey.fromJson(json['keys']![1])!;

        expect(key2.keyType, 'RSA');
        expect(key2.keyId, '2011-04-29');
        expect(key2.algorithm, 'RS256');

        var keySet = JsonWebKeySet.fromJson(json);

        expect(keySet.keys[0], key1);
        expect(keySet.keys[1], key2);

        expect(keySet.toJson(), json);
      });

      test('Example Private Keys', () {
        var json = {
          'keys': [
            {
              'kty': 'EC',
              'crv': 'P-256',
              'x': 'MKBCTNIcKUSDii11ySs3526iDZ8AiTo7Tu6KPAqv7D4',
              'y': '4Etl6SRW2YiLUrN5vfvVHuhp7x8PxltmWWlbbM4IFyM',
              'd': '870MB6gfuTJ4HtUnUvYMyJpr5eUZNP4Bk43bVdj3eAE',
              'use': 'enc',
              'kid': '1'
            },
            {
              'kty': 'RSA',
              'n': '0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4'
                  'cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMst'
                  'n64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2Q'
                  'vzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbIS'
                  'D08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw'
                  '0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw',
              'e': 'AQAB',
              'd': 'X4cTteJY_gn4FYPsXB8rdXix5vwsg1FLN5E3EaG6RJoVH-HLLKD9'
                  'M7dx5oo7GURknchnrRweUkC7hT5fJLM0WbFAKNLWY2vv7B6NqXSzUvxT0_YSfqij'
                  'wp3RTzlBaCxWp4doFk5N2o8Gy_nHNKroADIkJ46pRUohsXywbReAdYaMwFs9tv8d'
                  '_cPVY3i07a3t8MN6TNwm0dSawm9v47UiCl3Sk5ZiG7xojPLu4sbg1U2jx4IBTNBz'
                  'nbJSzFHK66jT8bgkuqsk0GjskDJk19Z4qwjwbsnn4j2WBii3RL-Us2lGVkY8fkFz'
                  'me1z0HbIkfz0Y6mqnOYtqc0X4jfcKoAC8Q',
              'p': '83i-7IvMGXoMXCskv73TKr8637FiO7Z27zv8oj6pbWUQyLPQBQxtPV'
                  'nwD20R-60eTDmD2ujnMt5PoqMrm8RfmNhVWDtjjMmCMjOpSXicFHj7XOuVIYQyqV'
                  'WlWEh6dN36GVZYk93N8Bc9vY41xy8B9RzzOGVQzXvNEvn7O0nVbfs',
              'q': '3dfOR9cuYq-0S-mkFLzgItgMEfFzB2q3hWehMuG0oCuqnb3vobLyum'
                  'qjVZQO1dIrdwgTnCdpYzBcOfW5r370AFXjiWft_NGEiovonizhKpo9VVS78TzFgx'
                  'kIdrecRezsZ-1kYd_s1qDbxtkDEgfAITAG9LUnADun4vIcb6yelxk',
              'dp': 'G4sPXkc6Ya9y8oJW9_ILj4xuppu0lzi_H7VTkS8xj5SdX3coE0oim'
                  'YwxIi2emTAue0UOa5dpgFGyBJ4c8tQ2VF402XRugKDTP8akYhFo5tAA77Qe_Nmtu'
                  'YZc3C3m3I24G2GvR5sSDxUyAN2zq8Lfn9EUms6rY3Ob8YeiKkTiBj0',
              'dq': 's9lAH9fggBsoFR8Oac2R_E2gw282rT2kGOAhvIllETE1efrA6huUU'
                  'vMfBcMpn8lqeW6vzznYY5SSQF7pMdC_agI3nG8Ibp1BUb0JUiraRNqUfLhcQb_d9'
                  'GF4Dh7e74WbRsobRonujTYN1xCaP6TO61jvWrX-L18txXw494Q_cgk',
              'qi': 'GyM_p6JrXySiz1toFgKbWV-JdI3jQ4ypu9rbMWx3rQJBfmt0FoYzg'
                  'UIZEVFEcOqwemRN81zoDAaa-Bk0KWNGDjJHZDdDmFhW3AN7lI-puxk_mHZGJ11rx'
                  'yR8O55XLSe3SPmRfKwZI6yU24ZxvQKFYItdldUKGzO6Ia6zTKhAVRU',
              'alg': 'RS256',
              'kid': '2011-04-29'
            }
          ]
        };

        var key1 = JsonWebKey.fromJson(json['keys']![0])!;

        expect(key1.keyType, 'EC');
        expect(key1.keyId, '1');
        expect(key1.publicKeyUse, 'enc');

        var key2 = JsonWebKey.fromJson(json['keys']![1])!;

        expect(key2.keyType, 'RSA');
        expect(key2.keyId, '2011-04-29');
        expect(key2.algorithm, 'RS256');

        var keySet = JsonWebKeySet.fromJson(json);

        expect(keySet.keys[0], key1);
        expect(keySet.keys[1], key2);

        expect(keySet.toJson(), json);
      });

      test('Example Symmetric Keys', () {
        var json = {
          'keys': [
            {'kty': 'oct', 'alg': 'A128KW', 'k': 'GawgguFyGrWKav7AX4VKUg'},
            {
              'kty': 'oct',
              'k': 'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75'
                  'aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
              'kid': 'HMAC key used in JWS spec Appendix A.1 example'
            }
          ]
        };

        var key1 = JsonWebKey.fromJson(json['keys']![0])!;

        expect(key1.keyType, 'oct');
        expect(key1.algorithm, 'A128KW');

        var key2 = JsonWebKey.fromJson(json['keys']![1])!;

        expect(key2.keyType, 'oct');
        expect(key2.keyId, 'HMAC key used in JWS spec Appendix A.1 example');

        var keySet = JsonWebKeySet.fromJson(json);

        expect(keySet.keys[0], key1);
        expect(keySet.keys[1], key2);

        expect(keySet.toJson(), json);
      });

      test('Web Key Set from url', () async {
        var v = {
          'keys': [
            {
              'kty': 'oct',
              'alg': 'A128KW',
              'k': 'GawgguFyGrWKav7AX4VKUg',
              'kid': 'key1'
            },
            {
              'kty': 'oct',
              'k': 'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75'
                  'aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
              'kid': 'HMAC key used in JWS spec Appendix A.1 example'
            }
          ]
        };

        var client = MockClient((request) async {
          return Response(json.encode(v), 200);
        });

        var store = JsonWebKeyStore()
          ..addKeySetUrl(Uri.parse('https://appsup.be/keys.json'));

        await JsonWebKeySetLoader.runZoned(() async {
          var key = await store
              .findJsonWebKeys(
                  JoseHeader.fromJson({'kid': 'key1', 'alg': 'A128KW'}), 'sign')
              .first;

          expect(key?.keyType, 'oct');
          expect(key?.algorithm, 'A128KW');

          key = await store
              .findJsonWebKeys(
                  JoseHeader.fromJson({'kid': 'key1', 'alg': 'A128KW'}), 'sign')
              .first;
        }, loader: DefaultJsonWebKeySetLoader(httpClient: client));
      });
    });

    test("Example Use of 'x5c' (X.509 Certificate Chain) Parameter", () {
      var json = {
        'kty': 'RSA',
        'use': 'sig',
        'kid': '1b94c',
        'n': 'vrjOfz9Ccdgx5nQudyhdoR17V-IubWMeOZCwX_jj0hgAsz2J_pqYW08'
            'PLbK_PdiVGKPrqzmDIsLI7sA25VEnHU1uCLNwBuUiCO11_-7dYbsr4iJmG0Q'
            'u2j8DsVyT1azpJC_NG84Ty5KKthuCaPod7iI7w0LK9orSMhBEwwZDCxTWq4a'
            'YWAchc8t-emd9qOvWtVMDC2BXksRngh6X5bUYLy6AyHKvj-nUy1wgzjYQDwH'
            'MTplCoLtU-o-8SNnZ1tmRoGE9uJkBLdh5gFENabWnU5m1ZqZPdwS-qo-meMv'
            'VfJb6jJVWRpl2SUtCnYG2C32qvbWbjZ_jBPD5eunqsIo1vQ',
        'e': 'AQAB',
        'x5c': [
          'MIIDQjCCAiqgAwIBAgIGATz/FuLiMA0GCSqGSIb3DQEBBQUAMGIxCzAJB'
              'gNVBAYTAlVTMQswCQYDVQQIEwJDTzEPMA0GA1UEBxMGRGVudmVyMRwwGgYD'
              'VQQKExNQaW5nIElkZW50aXR5IENvcnAuMRcwFQYDVQQDEw5CcmlhbiBDYW1'
              'wYmVsbDAeFw0xMzAyMjEyMzI5MTVaFw0xODA4MTQyMjI5MTVaMGIxCzAJBg'
              'NVBAYTAlVTMQswCQYDVQQIEwJDTzEPMA0GA1UEBxMGRGVudmVyMRwwGgYDV'
              'QQKExNQaW5nIElkZW50aXR5IENvcnAuMRcwFQYDVQQDEw5CcmlhbiBDYW1w'
              'YmVsbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL64zn8/QnH'
              'YMeZ0LncoXaEde1fiLm1jHjmQsF/449IYALM9if6amFtPDy2yvz3YlRij66'
              's5gyLCyO7ANuVRJx1NbgizcAblIgjtdf/u3WG7K+IiZhtELto/A7Fck9Ws6'
              'SQvzRvOE8uSirYbgmj6He4iO8NCyvaK0jIQRMMGQwsU1quGmFgHIXPLfnpn'
              'fajr1rVTAwtgV5LEZ4Iel+W1GC8ugMhyr4/p1MtcIM42EA8BzE6ZQqC7VPq'
              'PvEjZ2dbZkaBhPbiZAS3YeYBRDWm1p1OZtWamT3cEvqqPpnjL1XyW+oyVVk'
              'aZdklLQp2Btgt9qr21m42f4wTw+Xrp6rCKNb0CAwEAATANBgkqhkiG9w0BA'
              'QUFAAOCAQEAh8zGlfSlcI0o3rYDPBB07aXNswb4ECNIKG0CETTUxmXl9KUL'
              '+9gGlqCz5iWLOgWsnrcKcY0vXPG9J1r9AqBNTqNgHq2G03X09266X5CpOe1'
              'zFo+Owb1zxtp3PehFdfQJ610CDLEaS9V9Rqp17hCyybEpOGVwe8fnk+fbEL'
              '2Bo3UPGrpsHzUoaGpDftmWssZkhpBJKVMJyf/RuP2SmmaIzmnw9JiSlYhzo'
              '4tpzd5rFXhjRbg4zW9C+2qok+2+qDM1iJ684gPHMIY8aLWrdgQTxkumGmTq'
              'gawR+N5MDtdPTEQ0XfIBc2cJEUyMTY5MPvACWpkA6SdS4xSvdXK3IVfOWA=='
        ]
      };

      var key = JsonWebKey.fromJson(json)!;

      expect(key.keyType, 'RSA');

      expect(key.toJson(), json);

      json['e'] = base64.encode([0, 0, 0]);
      expect(() => JsonWebKey.fromJson(json),
          throwsA(TypeMatcher<ArgumentError>()));
    });
  });

  group('JWK from pem files', () {
    test('JWK from pem PRIVATE RSA KEY', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/rsa.key').readAsStringSync(),
      );

      expect(key.keyType, 'RSA');
      expect(key.cryptoKeyPair.publicKey, isA<RsaPublicKey>());
      expect(key.cryptoKeyPair.privateKey, isA<RsaPrivateKey>());
    });
    test('JWK from pem PUBLIC KEY with RSA', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/rsa.pub.key').readAsStringSync(),
      );

      expect(key.keyType, 'RSA');
      expect(key.cryptoKeyPair.publicKey, isA<RsaPublicKey>());
      expect(key.cryptoKeyPair.privateKey, isNull);
    });
    test('JWK from pem PRIVATE EC KEY with P-256 curve', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/ec256.key').readAsStringSync(),
      );

      expect(key.keyType, 'EC');
      expect(key.cryptoKeyPair.publicKey, isA<EcPublicKey>());
      expect((key.cryptoKeyPair.publicKey as EcKey).curve, curves.p256);
      expect(key.cryptoKeyPair.privateKey, isA<EcPrivateKey>());
      expect((key.cryptoKeyPair.privateKey as EcKey).curve, curves.p256);
    });
    test('JWK from pem PUBLIC KEY with EC P-256 curve', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/ec256.pub.key').readAsStringSync(),
      );

      expect(key.keyType, 'EC');
      expect(key.cryptoKeyPair.publicKey, isA<EcPublicKey>());
      expect((key.cryptoKeyPair.publicKey as EcKey).curve, curves.p256);
      expect(key.cryptoKeyPair.privateKey, isNull);
    });
    test('JWK from pem PRIVATE EC KEY with P-256K curve', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/ec256k.key').readAsStringSync(),
      );

      expect(key.keyType, 'EC');
      expect(key.cryptoKeyPair.publicKey, isA<EcPublicKey>());
      expect((key.cryptoKeyPair.publicKey as EcKey).curve, curves.p256k);
      expect(key.cryptoKeyPair.privateKey, isA<EcPrivateKey>());
      expect((key.cryptoKeyPair.privateKey as EcKey).curve, curves.p256k);
    });
    test('JWK from pem PUBLIC KEY with EC P-256K curve', () {
      var key = JsonWebKey.fromPem(
        File('test/pem/ec256k.pub.key').readAsStringSync(),
      );

      expect(key.keyType, 'EC');
      expect(key.cryptoKeyPair.publicKey, isA<EcPublicKey>());
      expect((key.cryptoKeyPair.publicKey as EcKey).curve, curves.p256k);
      expect(key.cryptoKeyPair.privateKey, isNull);
    });
    test('JWK from pem CERTIFICATE', () {
      var key = JsonWebKey.fromPem('-----BEGIN CERTIFICATE-----\n'
          'MIIDHDCCAgSgAwIBAgIIcYRws2sTxJkwDQYJKoZIhvcNAQEFBQAwMTEvMC0GA1UE\n'
          'AxMmc2VjdXJldG9rZW4uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wHhcNMjEw\n'
          'NDA2MDkyMDIwWhcNMjEwNDIyMjEzNTIwWjAxMS8wLQYDVQQDEyZzZWN1cmV0b2tl\n'
          'bi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTCCASIwDQYJKoZIhvcNAQEBBQAD\n'
          'ggEPADCCAQoCggEBAMoRTVdYXX6kW8oEplmvw5K2LnN3TSxdU2E4r3LKwY5wWEOI\n'
          'EJkgXq5mj+1D/AESJRE8eveVAKlR5/vBITPuJT99agjG/4vr9CNdEZjPc/TmqFmX\n'
          'wldeX/oE89LIoSuBKR/g3CRI17Z/0V/ZaeLwNlWz/A/L6+MEfEbgAIiSxXFkctXL\n'
          'TIWf3Ith24OTN8hVCgCaUWVLuY+FGprUnqQOqn1lpbtb1fgTSI/JAGXu6wsESyc3\n'
          'xslD2e4VyBQ1i+JoW3/VKydlODd3THydFRBHGPdJQkLH4ccDh2kQ4sWQ4vjupSsk\n'
          'BKMAvLqftpvVUo6LogEXNRmmI6sjluRlEvYk14kCAwEAAaM4MDYwDAYDVR0TAQH/\n'
          'BAIwADAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwDQYJ\n'
          'KoZIhvcNAQEFBQADggEBADFwIJVQERKO+x8Fx01ySjgSG6Rb81a17WQSCP2dlYmK\n'
          'FBvwaKK5tGVDt3RUnMgM5myEY11TX8yBF8UstxkqtMTzJh+K1hV6lC11YRqWzodq\n'
          'mJUBDuU39MYcRgoQn7szodBckdUGQlkTZti7xLApewkDpmR3Wx0KQBQpGt20Oaoq\n'
          'B2a5DVq4KsRirPtS71QvekM9Aars7pKrVNhxvXgkIMpiUAj3GJR5NAsJD0tsa9LM\n'
          'Lvo31/AE1VKiRJ9ta21m15wO4CJyAiWvRbRiHDN9b9oXuJwUlzUgT0GFWHayt56e\n'
          'CYTU00dPphNMO1O07aqHq2O44/wPXYtQGDlHsg4sCeM=\n'
          '-----END CERTIFICATE-----\n');

      expect(key.keyType, 'RSA');
      expect(key.cryptoKeyPair.publicKey, isA<RsaPublicKey>());
      expect(key.cryptoKeyPair.privateKey, isNull);
    });
  });

  group('Issues', () {
    test(
        'Issue #16: _intToBase64 bug causing decryption fail when create key using exponent=65537',
        () {
      final jwk = JsonWebKey.rsa(
        modulus: BigInt.parse('12345678'),
        exponent: BigInt.parse('65537'),
      );
      var publicKey = jwk.cryptoKeyPair.publicKey as RsaPublicKey;
      expect(publicKey.modulus, BigInt.parse('12345678'));
      expect(publicKey.exponent, BigInt.parse('65537'));
    });
  });
}
