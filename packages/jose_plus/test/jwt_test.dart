@Tags(['slow-web-crypto'])
library;

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JWT Examples from RFC7519', () {
    var context = JsonWebKeyStore()
      ..addKey(JsonWebKey.fromJson({
        'kty': 'oct',
        'k':
            'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow'
      }))
      ..addKey(JsonWebKey.fromJson(
        {
          'kty': 'RSA',
          'n': 'sXchDaQebHnPiGvyDOAT4saGEUetSyo9MKLOoWFsueri23bOdgWp4Dy1Wl'
              'UzewbgBHod5pcM9H95GQRV3JDXboIRROSBigeC5yjU1hGzHHyXss8UDpre'
              'cbAYxknTcQkhslANGRUZmdTOQ5qTRsLAt6BTYuyvVRdhS8exSZEy_c4gs_'
              '7svlJJQ4H9_NxsiIoLwAEk7-Q3UXERGYw_75IDrGA84-lA_-Ct4eTlXHBI'
              'Y2EaV7t7LjJaynVJCpkv4LKjTTAumiGUIuQhrNhZLuF_RJLqHpM2kgWFLU'
              '7-VTdL1VbC2tejvcI2BlMkEpk1BzBZI0KQB0GaDWFLN-aEAw3vRw',
          'e': 'AQAB',
          'd': 'VFCWOqXr8nvZNyaaJLXdnNPXZKRaWCjkU5Q2egQQpTBMwhprMzWzpR8Sxq'
              '1OPThh_J6MUD8Z35wky9b8eEO0pwNS8xlh1lOFRRBoNqDIKVOku0aZb-ry'
              'nq8cxjDTLZQ6Fz7jSjR1Klop-YKaUHc9GsEofQqYruPhzSA-QgajZGPbE_'
              '0ZaVDJHfyd7UUBUKunFMScbflYAAOYJqVIVwaYR5zWEEceUjNnTNo_CVSj'
              '-VvXLO5VZfCUAVLgW4dpf1SrtZjSt34YLsRarSb127reG_DUwg9Ch-Kyvj'
              'T1SkHgUWRVGcyly7uvVGRSDwsXypdrNinPA4jlhoNdizK2zF2CWQ',
          'p': '9gY2w6I6S6L0juEKsbeDAwpd9WMfgqFoeA9vEyEUuk4kLwBKcoe1x4HG68'
              'ik918hdDSE9vDQSccA3xXHOAFOPJ8R9EeIAbTi1VwBYnbTp87X-xcPWlEP'
              'krdoUKW60tgs1aNd_Nnc9LEVVPMS390zbFxt8TN_biaBgelNgbC95sM',
          'q': 'uKlCKvKv_ZJMVcdIs5vVSU_6cPtYI1ljWytExV_skstvRSNi9r66jdd9-y'
              'BhVfuG4shsp2j7rGnIio901RBeHo6TPKWVVykPu1iYhQXw1jIABfw-MVsN'
              '-3bQ76WLdt2SDxsHs7q7zPyUyHXmps7ycZ5c72wGkUwNOjYelmkiNS0',
          'dp': 'w0kZbV63cVRvVX6yk3C8cMxo2qCM4Y8nsq1lmMSYhG4EcL6FWbX5h9yuv'
              'ngs4iLEFk6eALoUS4vIWEwcL4txw9LsWH_zKI-hwoReoP77cOdSL4AVcra'
              'Hawlkpyd2TWjE5evgbhWtOxnZee3cXJBkAi64Ik6jZxbvk-RR3pEhnCs',
          'dq': 'o_8V14SezckO6CNLKs_btPdFiO9_kC1DsuUTd2LAfIIVeMZ7jn1Gus_Ff'
              '7B7IVx3p5KuBGOVF8L-qifLb6nQnLysgHDh132NDioZkhH7mI7hPG-PYE_'
              'odApKdnqECHWw0J-F0JWnUd6D2B_1TvF9mXA2Qx-iGYn8OVV1Bsmp6qU',
          'qi': 'eNho5yRBEBxhGBtQRww9QirZsB66TrfFReG_CcteI1aCneT0ELGhYlRlC'
              'tUkTRclIfuEPmNsNDPbLoLqqCVznFbvdB7x-Tl-m0l_eFTj2KiqwGqE9PZ'
              'B9nNTwMVvH3VRRSLWACvPnSiwP8N5Usy-WRXS-V7TbpxIhvepTfE0NNo'
        },
      ))
      ..addKey(JsonWebKey.fromJson({
        'kty': 'RSA',
        'n': 'ofgWCuLjybRlzo0tZWJjNiuSfb4p4fAkd_wWJcyQoTbji9k0l8W26mPddx'
            'HmfHQp-Vaw-4qPCJrcS2mJPMEzP1Pt0Bm4d4QlL-yRT-SFd2lZS-pCgNMs'
            'D1W_YpRPEwOWvG6b32690r2jZ47soMZo9wGzjb_7OMg0LOL-bSf63kpaSH'
            'SXndS5z5rexMdbBYUsLA9e-KXBdQOS-UTo7WTBEMa2R2CapHg665xsmtdV'
            'MTBQY4uDZlxvb3qCo5ZwKh9kG4LT6_I5IhlJH7aGhyxXFvUK-DWNmoudF8'
            'NAco9_h9iaGNj8q2ethFkMLs91kzk2PAcDTW9gb54h4FRWyuXpoQ',
        'e': 'AQAB',
        'd': 'Eq5xpGnNCivDflJsRQBXHx1hdR1k6Ulwe2JZD50LpXyWPEAeP88vLNO97I'
            'jlA7_GQ5sLKMgvfTeXZx9SE-7YwVol2NXOoAJe46sui395IW_GO-pWJ1O0'
            'BkTGoVEn2bKVRUCgu-GjBVaYLU6f3l9kJfFNS3E0QbVdxzubSu3Mkqzjkn'
            '439X0M_V51gfpRLI9JYanrC4D4qAdGcopV_0ZHHzQlBjudU2QvXt4ehNYT'
            'CBr6XCLQUShb1juUO1ZdiYoFaFQT5Tw8bGUl_x_jTj3ccPDVZFD9pIuhLh'
            'BOneufuBiB4cS98l2SR_RQyGWSeWjnczT0QU91p1DhOVRuOopznQ',
        'p': '4BzEEOtIpmVdVEZNCqS7baC4crd0pqnRH_5IB3jw3bcxGn6QLvnEtfdUdi'
            'YrqBdss1l58BQ3KhooKeQTa9AB0Hw_Py5PJdTJNPY8cQn7ouZ2KKDcmnPG'
            'BY5t7yLc1QlQ5xHdwW1VhvKn-nXqhJTBgIPgtldC-KDV5z-y2XDwGUc',
        'q': 'uQPEfgmVtjL0Uyyx88GZFF1fOunH3-7cepKmtH4pxhtCoHqpWmT8YAmZxa'
            'ewHgHAjLYsp1ZSe7zFYHj7C6ul7TjeLQeZD_YwD66t62wDmpe_HlB-TnBA'
            '-njbglfIsRLtXlnDzQkv5dTltRJ11BKBBypeeF6689rjcJIDEz9RWdc',
        'dp': 'BwKfV3Akq5_MFZDFZCnW-wzl-CCo83WoZvnLQwCTeDv8uzluRSnm71I3Q'
            'CLdhrqE2e9YkxvuxdBfpT_PI7Yz-FOKnu1R6HsJeDCjn12Sk3vmAktV2zb'
            '34MCdy7cpdTh_YVr7tss2u6vneTwrA86rZtu5Mbr1C1XsmvkxHQAdYo0',
        'dq': 'h_96-mK1R_7glhsum81dZxjTnYynPbZpHziZjeeHcXYsXaaMwkOlODsWa'
            '7I9xXDoRwbKgB719rrmI2oKr6N3Do9U0ajaHF-NKJnwgjMd2w9cjz3_-ky'
            'NlxAr2v4IKhGNpmM5iIgOS1VZnOZ68m6_pbLBSp3nssTdlqvd0tIiTHU',
        'qi': 'IYd7DHOhrWvxkwPQsRM2tOgrjbcrfvtQJipd-DlcxyVuuM9sQLdgjVk2o'
            'y26F0EmpScGLq2MowX7fhd_QJQ3ydy5cY7YIBi87w93IKLEdfnbJtoOPLU'
            'W0ITrJReOgo1cq9SbsxYawBgfp_gh6A5603k2-ZQwVK0JKSHuLFkuQ3U'
      }));

    void doTests(dynamic payload, dynamic encoded, [bool verify = true]) {
      test('decode', () async {
        var jwt = await JsonWebToken.decodeAndVerify(encoded, context,
            allowedArguments: verify ? null : ['none']);

        expect(jwt.toCompactSerialization(), encoded);
        expect(jwt.claims.toJson(), payload);
      });
      test('create', () {
/*
    var jws = JsonWebSignature.unsigned(payload);

    for (var key in keys.keys) {
      jws = jws.sign(key);
    }

    expect(jws.verify(keys), true);
    _expectPayload(jws);
*/
      });
    }

    group('Example JWT', () {
      doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          'eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.'
          'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
          'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.'
          'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
    });
    group('Example Unsecured JWT', () {
      doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          'eyJhbGciOiJub25lIn0.'
          'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
          'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.',
          false);
    });
    group('Example Encrypted JWT', () {
      doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          'eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0.'
          'QR1Owv2ug2WyPBnbQrRARTeEk9kDO2w8qDcjiHnSJflSdv1iNqhWXaKH4MqAkQtM'
          'oNfABIPJaZm0HaA415sv3aeuBWnD8J-Ui7Ah6cWafs3ZwwFKDFUUsWHSK-IPKxLG'
          'TkND09XyjORj_CHAgOPJ-Sd8ONQRnJvWn_hXV1BNMHzUjPyYwEsRhDhzjAD26ima'
          'sOTsgruobpYGoQcXUwFDn7moXPRfDE8-NoQX7N7ZYMmpUDkR-Cx9obNGwJQ3nM52'
          'YCitxoQVPzjbl7WBuB7AohdBoZOdZ24WlN1lVIeh8v1K4krB8xgKvRU8kgFrEn_a'
          '1rZgN5TiysnmzTROF869lQ.'
          'AxY8DCtDaGlsbGljb3RoZQ.'
          'MKOle7UQrG6nSxTLX6Mqwt0orbHvAKeWnDYvpIAeZ72deHxz3roJDXQyhxx0wKaM'
          'HDjUEOKIwrtkHthpqEanSBNYHZgmNOV7sln1Eu9g3J8.'
          'fiK51VwhsxJ-siBMR-YFiA');
    });
    group('Example Nested JWT', () {
      doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          'eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2IiwiY3R5IjoiSldU'
          'In0.'
          'g_hEwksO1Ax8Qn7HoN-BVeBoa8FXe0kpyk_XdcSmxvcM5_P296JXXtoHISr_DD_M'
          'qewaQSH4dZOQHoUgKLeFly-9RI11TG-_Ge1bZFazBPwKC5lJ6OLANLMd0QSL4fYE'
          'b9ERe-epKYE3xb2jfY1AltHqBO-PM6j23Guj2yDKnFv6WO72tteVzm_2n17SBFvh'
          'DuR9a2nHTE67pe0XGBUS_TK7ecA-iVq5COeVdJR4U4VZGGlxRGPLRHvolVLEHx6D'
          'YyLpw30Ay9R6d68YCLi9FYTq3hIXPK_-dmPlOUlKvPr1GgJzRoeC9G5qCvdcHWsq'
          'JGTO_z3Wfo5zsqwkxruxwA.'
          'UmVkbW9uZCBXQSA5ODA1Mg.'
          'VwHERHPvCNcHHpTjkoigx3_ExK0Qc71RMEParpatm0X_qpg-w8kozSjfNIPPXiTB'
          'BLXR65CIPkFqz4l1Ae9w_uowKiwyi9acgVztAi-pSL8GQSXnaamh9kX1mdh3M_TT'
          '-FZGQFQsFhu0Z72gJKGdfGE-OE7hS1zuBD5oEUfk0Dmb0VzWEzpxxiSSBbBAzP10'
          'l56pPfAtrjEYw-7ygeMkwBl6Z_mLS6w6xUgKlvW6ULmkV-uLC4FUiyKECK4e3WZY'
          'Kw1bpgIqGYsw2v_grHjszJZ-_I5uM-9RA8ycX9KqPRp9gc6pXmoU_-27ATs9XCvr'
          'ZXUtK2902AUzqpeEUJYjWWxSNsS-r1TJ1I-FMJ4XyAiGrfmo9hQPcNBYxPz3GQb2'
          '8Y5CLSQfNgKSGt0A4isp1hBUXBHAndgtcslt7ZoQJaKe_nNJgNliWtWpJ_ebuOpE'
          'l8jdhehdccnRMIwAmU1n7SPkmhIl1HlSOpvcvDfhUN5wuqU955vOBvfkBOh5A11U'
          'zBuo2WlgZ6hYi9-e3w29bR0C2-pp3jbqxEDw3iWaf2dc5b-LnR0FEYXvI_tYk5rd'
          '_J9N0mg0tQ6RbpxNEMNoA9QWk5lgdPvbh9BaO195abQ.'
          'AVO9iT5AV4CzvDJCdhSFlQ');
    });
  });

  test('JsonWebTokenClaims can handle doubles in expiration', () {
    final claims = JsonWebTokenClaims.fromJson({'exp': 1300819380.0});
    expect(claims.expiry, DateTime.fromMillisecondsSinceEpoch(1300819380000));
  });

  group('Verification key selection', () {
    test('JWT with header jwk is rejected when no matching trusted key exists',
        () async {
      final trustedKey = JsonWebKey.generate('RS256');
      final keyStore = JsonWebKeyStore()..addKey(trustedKey);

      final alternateKey = JsonWebKey.generate('RS256');
      final claims = JsonWebTokenClaims.fromJson({
        'sub': 'user-2',
        'iss': 'https://trusted-issuer.example.com',
        'aud': 'my-application',
        'exp': DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims.toJson()
        ..setProtectedHeader('typ', 'JWT')
        ..addRecipient(alternateKey, algorithm: 'RS256')
        ..setProtectedHeader(
            'jwk',
            JsonWebKey.fromCryptoKeys(
                    publicKey: alternateKey.cryptoKeyPair.publicKey)
                .toJson());
      final jwtCompact = builder.build().toCompactSerialization();

      expect(
        () => JsonWebToken.decodeAndVerify(jwtCompact, keyStore),
        throwsA(isA<JoseException>()),
      );
    });
  });

  group('JWT with ES256K signature', () {
    test('JWT with ES256K signature', () async {
      var key = JsonWebKey.fromJson({
        'kty': 'EC',
        'd': 'e8HThqO0wR_Qw4pNIb80Cs0mYuCSqT6BSQj-o-tKTrg',
        'x': 'A3hkIubgDggcoHzmVdXIm11gZ7UMaOa71JVf1eCifD8',
        'y': 'ejpRwmCvNMdXMOjR2DodOt09OLPgNUrcKA9hBslaFU0',
        'crv': 'P-256K',
        'kid': '123'
      });

      var jwt = JsonWebToken.unverified(
          'eyJhbGciOiJFUzI1NksiLCJraWQiOiIxMjMiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJ5b3UiLCJpc3MiOiJtZSIsImV4cCI6MTU3NjQ0Mzg2NS4wLCJpYXQiOjE1NzY0NDAyNjUsIm5iZiI6MTU3NjQ0MDI2NX0.nngSyreix-Ri0H1lC4PRGYLNEktMDUag22VmSYe_SRJFd_Oh-Qag1XSLr1Pq0puym8KSVVuPYCzIh5rsuAFH6g');

      var verified = await jwt.verify(JsonWebKeyStore()..addKey(key));
      expect(verified, true);
    });
  });
}
