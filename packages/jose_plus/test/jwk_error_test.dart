import 'dart:convert';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:jose_plus/jose.dart';
import 'package:jose_plus/src/jwk.dart';
import 'package:test/test.dart';

void main() {
  group('JsonWebKey.fromCryptoKeys', () {
    test('throws when both publicKey and privateKey are null', () {
      expect(
        () => JsonWebKey.fromCryptoKeys(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when an RSA private key is paired with a non-RSA public key',
        () {
      final rsaPriv = JsonWebKey.generate('RS256').cryptoKeyPair.privateKey
          as RsaPrivateKey;
      final ecPub =
          JsonWebKey.generate('ES256').cryptoKeyPair.publicKey as EcPublicKey;
      expect(
        () => JsonWebKey.fromCryptoKeys(privateKey: rsaPriv, publicKey: ecPub),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when an EC private key is paired with a non-EC public key',
        () {
      final ecPriv =
          JsonWebKey.generate('ES256').cryptoKeyPair.privateKey as EcPrivateKey;
      final rsaPub =
          JsonWebKey.generate('RS256').cryptoKeyPair.publicKey as RsaPublicKey;
      expect(
        () => JsonWebKey.fromCryptoKeys(privateKey: ecPriv, publicKey: rsaPub),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws UnsupportedError for an unsupported public-only key type', () {
      final okpPub = JsonWebKey.generate('EdDSA').cryptoKeyPair.publicKey;
      expect(
        () => JsonWebKey.fromCryptoKeys(publicKey: okpPub),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('throws UnsupportedError for an unsupported private key type', () {
      final okpPriv = JsonWebKey.generate('EdDSA').cryptoKeyPair.privateKey;
      expect(
        () => JsonWebKey.fromCryptoKeys(privateKey: okpPriv),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('builds an RSA public JWK from a public key', () {
      final rsaPub =
          JsonWebKey.generate('RS256').cryptoKeyPair.publicKey as RsaPublicKey;
      final jwk = JsonWebKey.fromCryptoKeys(publicKey: rsaPub, keyId: 'r1');
      expect(jwk.keyType, 'RSA');
      expect(jwk.keyId, 'r1');
      expect(jwk.cryptoKeyPair.privateKey, isNull);
    });

    test('builds an EC public JWK from a public key', () {
      final ecPub =
          JsonWebKey.generate('ES256').cryptoKeyPair.publicKey as EcPublicKey;
      final jwk = JsonWebKey.fromCryptoKeys(publicKey: ecPub, keyId: 'e1');
      expect(jwk.keyType, 'EC');
      expect(jwk.keyId, 'e1');
    });
  });

  group('JsonWebKey factory constructors', () {
    test('rsa honours keyId and algorithm', () {
      final jwk = JsonWebKey.rsa(
        modulus: BigInt.parse('12345678'),
        exponent: BigInt.parse('65537'),
        keyId: 'rsa-key',
        algorithm: 'RS256',
      );
      expect(jwk.keyType, 'RSA');
      expect(jwk.keyId, 'rsa-key');
      expect(jwk.algorithm, 'RS256');
    });

    test('ec honours keyId and algorithm', () {
      final source = JsonWebKey.generate('ES256');
      final pub = source.cryptoKeyPair.publicKey as EcPublicKey;
      final jwk = JsonWebKey.ec(
        curve: 'P-256',
        xCoordinate: pub.xCoordinate,
        yCoordinate: pub.yCoordinate,
        keyId: 'ec-key',
        algorithm: 'ES256',
      );
      expect(jwk.keyType, 'EC');
      expect(jwk.keyId, 'ec-key');
      expect(jwk.algorithm, 'ES256');
    });

    test('symmetric builds an oct key with a keyId', () {
      final jwk = JsonWebKey.symmetric(
        key: BigInt.parse('123456789abcdef0', radix: 16),
        keyId: 'sym-key',
      );
      expect(jwk.keyType, 'oct');
      expect(jwk.keyId, 'sym-key');
    });
  });

  group('JsonWebKey X.509 accessors', () {
    test('exposes x5u, x5t and x5t#S256 parameters', () {
      final jwk = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'GawgguFyGrWKav7AX4VKUg',
        'x5u': 'https://example.com/cert',
        'x5t': 'thumb-1',
        'x5t#S256': 'thumb-256',
      })!;
      expect(jwk.x509Url, Uri.parse('https://example.com/cert'));
      expect(jwk.x509CertificateThumbprint, 'thumb-1');
      expect(jwk.x509CertificateSha256Thumbprint, 'thumb-256');
    });

    test('throws a FormatException when x5c is not a valid certificate', () {
      // base64 of DER [0x02, 0x01, 0x05] — an ASN.1 INTEGER, not a SEQUENCE.
      final badCert = base64.encode([2, 1, 5]);
      expect(
        () => JsonWebKey.fromJson({
          'kty': 'oct',
          'k': 'GawgguFyGrWKav7AX4VKUg',
          'x5c': [badCert],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('JsonWebKey.fromPem with an unsupported PEM block type', () {
    test('throws UnsupportedError for a PKCS#10 certificate request', () {
      // `x509.parsePem` decodes a "CERTIFICATE REQUEST" block into a
      // `CertificationRequest`, which `fromPem` has no conversion for (only
      // `PrivateKeyInfo`, `KeyPair`, `X509Certificate` and
      // `SubjectPublicKeyInfo` are supported).
      const csrPem = '-----BEGIN CERTIFICATE REQUEST-----\n'
          'MIICxDCCAawCAQAwfzELMAkGA1UEBhMCQkUxEzARBgNVBAgTClNvbWUtU3RhdGUx\n'
          'DjAMBgNVBAcTBUdoZW50MQ8wDQYDVQQKEwZBcHBzVXAxFDASBgNVBAMTC1JpayBC\n'
          'ZWxsZW5zMSQwIgYJKoZIhvcNAQkBFhVyaWsuYmVsbGVuc0BhcHBzdXAuYmUwggEi\n'
          'MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDIEQi/Jsu5D1d6G4tUBGFBfzBr\n'
          'Om72d0nPo2nitdw4mjnqdSn08xPeu8ILIUds3Mbti4AXyk/Ar+RsnxtG8j85RvH+\n'
          'sx8nIc41J4//9cIlYjVCScjAvuklz2JWIMCT50y2rJ1pf0NFrs/pghRQBX5yAP0z\n'
          'KTWjQsgojLp1V4UVLfyWKdBQRDA6W2dybc8WtvCc4n3cLrMDYRY3Kwl7zl5TmIr9\n'
          'cw+B50W/9Q+lv4x3Yzj7zxs2CHrjhY1x14es1hTf6VlNH07Bb9MM8HtONq73616S\n'
          'ojzo3Wd16Zps2Kl7COHu5pG2WSR95ddjpaJur9pbZLft8n2nLLMNd+c4u2YzAgMB\n'
          'AAGgADANBgkqhkiG9w0BAQsFAAOCAQEAJyv7nIC2g//naaXwMAiBML6JlSQcrPIb\n'
          'GoVvgAXdcT9GLTg7h4So2XRj3R/qq5yzSRjZ6tSjEHpufG2z/6ewZNb/kynQjdKp\n'
          'wQ8sumReuGgOcnHw6ggEadRxVBRjCvLI2Vdz1K8aVQc0bpeEJydop+aMjLaYNypo\n'
          'dQxDBcoDQqpn5ocxQCVLXUVtuWdJQLPwaN+EuSoeuqoFgsx2MCKjCpdOfRBONqQZ\n'
          '3661iihx1kYj3BT3pUDuf8Ztbpf4th0iRX0HaQ86Cv23csvlGEggo332tuHE8nqt\n'
          'QRHW6F76DyflCMF+rSGKlf6PvU9bDjNccjxiYMum4HG+hoUqsnTW2g==\n'
          '-----END CERTIFICATE REQUEST-----\n';
      expect(
        () => JsonWebKey.fromPem(csrPem),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonWebKey._getAlgorithm', () {
    test(
        'sign with algorithm "none" throws UnsupportedError '
        '(AlgorithmIdentifier.getByJwaName returns null only for "none")', () {
      final key = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75'
            'aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
      })!;
      expect(
        () => key.sign([1, 2, 3], algorithm: 'none'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonWebKey cryptographic operation guards', () {
    test('sign throws StateError when the key cannot sign', () {
      final publicOnly = JsonWebKey.fromJson({
        'kty': 'RSA',
        'n': 'sXchDaQebHnPiGvyDOAT4saGEUetSyo9MKLOoWFsueri23bOdgWp4Dy1Wl'
            'UzewbgBHod5pcM9H95GQRV3JDXboIRROSBigeC5yjU1hGzHHyXss8UDpre'
            'cbAYxknTcQkhslANGRUZmdTOQ5qTRsLAt6BTYuyvVRdhS8exSZEy_c4gs_'
            '7svlJJQ4H9_NxsiIoLwAEk7-Q3UXERGYw_75IDrGA84-lA_-Ct4eTlXHBI'
            'Y2EaV7t7LjJaynVJCpkv4LKjTTAumiGUIuQhrNhZLuF_RJLqHpM2kgWFLU'
            '7-VTdL1VbC2tejvcI2BlMkEpk1BzBZI0KQB0GaDWFLN-aEAw3vRw',
        'e': 'AQAB',
      })!;
      expect(
        () => publicOnly.sign([1, 2, 3], algorithm: 'RS256'),
        throwsStateError,
      );
    });

    test('sign throws ArgumentError when algorithm differs from key algorithm',
        () {
      final key = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75'
            'aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
        'alg': 'HS256',
      })!;
      expect(
        () => key.sign([1, 2, 3], algorithm: 'HS384'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sign throws ArgumentError when no algorithm can be determined', () {
      final key = JsonWebKey.fromJson({
        'kty': 'oct',
        'k': 'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75'
            'aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow',
      })!;
      expect(() => key.sign([1, 2, 3]), throwsA(isA<ArgumentError>()));
    });

    test('wrapKey throws UnsupportedError when wrapping a non-oct key', () {
      final wrappingKey = JsonWebKey.generate('RSA-OAEP');
      final ecKey = JsonWebKey.generate('ES256');
      expect(
        () => wrappingKey.wrapKey(ecKey),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('wrapKey/unwrapKey round-trips a symmetric content key', () {
      final wrappingKey = JsonWebKey.generate('RSA-OAEP');
      final cek = JsonWebKey.generate('A128GCM');
      final wrapped = wrappingKey.wrapKey(cek);
      final unwrapped = wrappingKey.unwrapKey(wrapped);
      expect(unwrapped.keyType, 'oct');
      expect(unwrapped['k'], cek['k']);
    });
  });

  group('JsonWebKey.usableForOperation and algorithmForOperation', () {
    test('a private RSA signing key can sign but a public one cannot', () {
      final pub =
          JsonWebKey.generate('RS256').cryptoKeyPair.publicKey as RsaPublicKey;
      final publicJwk = JsonWebKey.fromCryptoKeys(publicKey: pub);
      expect(publicJwk.usableForOperation('sign'), isFalse);
      expect(publicJwk.usableForOperation('verify'), isTrue);
      expect(publicJwk.algorithmForOperation('sign'), isNull);
    });
  });

  group('JsonWebKeySetLoader', () {
    test('global getter and setter can be swapped and restored', () async {
      final original = JsonWebKeySetLoader.current;
      final custom = DefaultJsonWebKeySetLoader();
      try {
        JsonWebKeySetLoader.global = custom;
        expect(JsonWebKeySetLoader.current, same(custom));
      } finally {
        JsonWebKeySetLoader.global = original;
      }
    });
  });

  group('DefaultJsonWebKeySetLoader.readAsString', () {
    test('reads a JWK set from a data: URI', () async {
      final setJson = json.encode({
        'keys': [
          {'kty': 'oct', 'alg': 'A128KW', 'k': 'GawgguFyGrWKav7AX4VKUg'}
        ]
      });
      final uri = Uri.parse(
          'data:application/json;charset=utf-8,${Uri.encodeComponent(setJson)}');
      final loader = DefaultJsonWebKeySetLoader();
      final set = await loader.read(uri);
      expect(set.keys, hasLength(1));
      expect(set.keys.single.algorithm, 'A128KW');
    });

    test('throws UnsupportedError for an unsupported URI scheme', () {
      final loader = DefaultJsonWebKeySetLoader();
      expect(
        () => loader.readAsString(Uri.parse('ftp://example.com/keys')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('honours date/expires headers to compute cache expiry', () async {
      final setJson = json.encode({'keys': []});
      final now = DateTime.utc(2022, 1, 1, 12);
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return Response(setJson, 200, headers: {
          'date': formatHttpDate(now),
          'expires': formatHttpDate(now.add(const Duration(hours: 1))),
        });
      });
      final loader = DefaultJsonWebKeySetLoader(httpClient: client);
      final uri = Uri.parse('https://example.com/keys.json');
      await loader.readAsString(uri);
      // Second read within the cache window should not hit the network again.
      await loader.readAsString(uri);
      expect(callCount, 1);
    });

    test('falls back to the default cache expiry when date header is invalid',
        () async {
      final setJson = json.encode({'keys': []});
      final client = MockClient((request) async {
        return Response(setJson, 200, headers: {'date': 'not-a-real-date'});
      });
      final loader = DefaultJsonWebKeySetLoader(httpClient: client);
      final body =
          await loader.readAsString(Uri.parse('https://example.com/k.json'));
      expect(body, setJson);
    });
  });
}
