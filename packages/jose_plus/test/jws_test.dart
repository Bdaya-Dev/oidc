@Tags(['slow-web-crypto'])
library;

import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JWS Examples from RFC7515', () {
    group('Example JWS Using HMAC SHA-256', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          JsonWebKey.fromJson({
            'kty': 'oct',
            'k':
                'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow'
          }),
          'eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
    });
    group('Example JWS Using RSASSA-PKCS1-v1_5 SHA-256', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          JsonWebKey.fromJson({
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
          }),
          'eyJhbGciOiJSUzI1NiJ9.'
          'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
          'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.'
          'cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZmh7'
          'AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjbKBYNX4'
          'BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHlb1L07Qe7K'
          '0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZESc6BfI7noOPqv'
          'hJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AXLIhWkWywlVmtVrB'
          'p0igcN_IoypGlUPQGe77Rw');
    });
    group('Example JWS Using ECDSA P-256 SHA-256', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          JsonWebKey.fromJson({
            'kty': 'EC',
            'crv': 'P-256',
            'x': 'f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU',
            'y': 'x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0',
            'd': 'jpsQnnGQmL-YBIffH1136cspYG6-0iY7X1fCE9-E9LI'
          }),
          'eyJhbGciOiJFUzI1NiJ9.'
          'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
          'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.'
          'DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8ISlSA'
          'pmWQxfKTUJqPP3-Kg6NU1Q');
    });
    group('Example JWS Using ECDSA P-521 SHA-512', () {
      _doTests(
          'Payload',
          JsonWebKey.fromJson({
            'kty': 'EC',
            'crv': 'P-521',
            'x': 'AekpBQ8ST8a8VcfVOTNl353vSrDCLLJXmPk06wTjxrrjcBpXp5EOnYG_'
                'NjFZ6OvLFV1jSfS9tsz4qUxcWceqwQGk',
            'y': 'ADSmRA43Z1DSNx_RvcLI87cdL07l6jQyyBXMoxVg_l2Th-x3S1WDhjDl'
                'y79ajL4Kkd0AZMaZmh9ubmf63e3kyMj2',
            'd': 'AY5pb7A0UFiB3RELSD64fTLOSV_jazdF7fLYyuTw8lOfRhWg6Y6rUrPA'
                'xerEzgdRhajnu0ferB0d53vM9mE15j2C'
          }),
          'eyJhbGciOiJFUzUxMiJ9.'
              'UGF5bG9hZA.'
              'AdwMgeerwtHoh-l192l60hp9wAHZFVJbLfD_UxMi70cwnZOYaRI1bKPWROc-mZZq'
              'wqT2SI-KGDKB34XO0aw_7XdtAG8GaSwFKdCAPZgoXD2YBJZCPEX3xKpRwcdOO8Kp'
              'EHwJjyqOgzDO7iKvU8vcnwNrmxYbSW9ERBXukOXolLzeO_Jn');
    });
    group('Example Unsecured JWS', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          null,
          'eyJhbGciOiJub25lIn0.'
          'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
          'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.',
          allowedAlgorithms: ['none']);
    });
    group('Example JWS Using General JWS JSON Serialization', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          JsonWebKeySet.fromKeys([
            JsonWebKey.fromJson({
              'kty': 'RSA',
              'kid': '2010-12-29',
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
            }),
            JsonWebKey.fromJson({
              'kid': 'e9bc097a-ce51-4036-9562-d2ade882db0d',
              'kty': 'EC',
              'crv': 'P-256',
              'x': 'f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU',
              'y': 'x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0',
              'd': 'jpsQnnGQmL-YBIffH1136cspYG6-0iY7X1fCE9-E9LI'
            }),
          ]),
          {
            'payload':
                'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGF'
                    'tcGxlLmNvbS9pc19yb290Ijp0cnVlfQ',
            'signatures': [
              {
                'protected': 'eyJhbGciOiJSUzI1NiJ9',
                'header': {'kid': '2010-12-29'},
                'signature': 'cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZ'
                    'mh7AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjb'
                    'KBYNX4BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHl'
                    'b1L07Qe7K0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZES'
                    'c6BfI7noOPqvhJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AX'
                    'LIhWkWywlVmtVrBp0igcN_IoypGlUPQGe77Rw'
              },
              {
                'protected': 'eyJhbGciOiJFUzI1NiJ9',
                'header': {'kid': 'e9bc097a-ce51-4036-9562-d2ade882db0d'},
                'signature':
                    'DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8IS'
                        'lSApmWQxfKTUJqPP3-Kg6NU1Q'
              }
            ]
          });
    });
    group('Example JWS Using Flattened JWS JSON Serialization', () {
      _doTests(
          {'iss': 'joe', 'exp': 1300819380, 'http://example.com/is_root': true},
          JsonWebKey.fromJson({
            'kid': 'e9bc097a-ce51-4036-9562-d2ade882db0d',
            'kty': 'EC',
            'crv': 'P-256',
            'x': 'f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU',
            'y': 'x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0',
            'd': 'jpsQnnGQmL-YBIffH1136cspYG6-0iY7X1fCE9-E9LI'
          }),
          {
            'payload':
                'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGF'
                    'tcGxlLmNvbS9pc19yb290Ijp0cnVlfQ',
            'protected': 'eyJhbGciOiJFUzI1NiJ9',
            'header': {'kid': 'e9bc097a-ce51-4036-9562-d2ade882db0d'},
            'signature':
                'DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8IS'
                    'lSApmWQxfKTUJqPP3-Kg6NU1Q'
          });
    });
  });
  group('Special algorithms JWS', () {
    test('Signing with `none`', () async {
      var payload = 'I am disguised';
      var builder = JsonWebSignatureBuilder()..content = payload;

      builder.addRecipient(null, algorithm: 'none');
      var jws = builder.build();

      var keyStore = JsonWebKeyStore();
      jws = JsonWebSignature.fromCompactSerialization(
          jws.toCompactSerialization());

      expect(jws.getPayload(keyStore), throwsException);

      expect(
          (await jws.getPayload(keyStore, allowedAlgorithms: ['none']))
              .stringContent,
          payload);
    });
  });

  group('Issues', () {
    test('bdaya-dev/jose#4', () async {
      const jwt =
          "eyJhbGciOiJFUzI1NiIsImtpZCI6ImRpZDp3ZWI6dGFsYW8uY28ja2V5LTIiLCJ0eXAiOiJKV1QifQ."
          "eyJibG9ja2NoYWluT3B0aW9ucyI6eyJibmJTdXBwb3J0Ijp0cnVlLCJldGhlcmV1bVN1cHBvcnQiOnRy"
          "dWUsImZhbnRvbVN1cHBvcnQiOnRydWUsImhlZGVyYVN1cHBvcnQiOnRydWUsImluZnVyYUFwaUtleSI6I"
          "iIsImluZnVyYVJwY05vZGUiOmZhbHNlLCJwb2x5Z29uU3VwcG9ydCI6dHJ1ZSwidGV6b3NTdXBwb3J0Ijp"
          "0cnVlLCJ0enByb0FwaUtleSI6IiIsInR6cHJvUnBjTm9kZSI6ZmFsc2V9LCJleHAiOjE3MDk0Njc1NjAuM"
          "CwiZ2VuZXJhbE9wdGlvbnMiOnsiY29tcGFueUxvZ28iOiJodHRwczovL3RhbGFvLmNvL3N0YXRpYy9pbWc"
          "vaWNvbi5wbmciLCJjb21wYW55TmFtZSI6Ik9yZ2EiLCJjb21wYW55V2Vic2l0ZSI6Im9yZ2EuZnIiLCJjdX"
          "N0b21lclBsYW4iOiJmcmVlIiwicHJvZmlsZU5hbWUiOiJwcm9maWxlIiwicHJvZmlsZVZlcnNpb24iOiIyI"
          "iwid2FsbGV0VHlwZSI6ImFsdG1lIn0sImhlbHBDZW50ZXJPcHRpb25zIjp7ImN1c3RvbUNoYXRTdXBwb3J0I"
          "jp0cnVlLCJjdXN0b21DaGF0U3VwcG9ydE5hbWUiOiIiLCJjdXN0b21FbWFpbCI6IiIsImN1c3RvbUVtYWlsU"
          "3VwcG9ydCI6ZmFsc2UsImRpc3BsYXlDaGF0U3VwcG9ydCI6dHJ1ZSwiZGlzcGxheUVtYWlsU3VwcG9ydCI6d"
          "HJ1ZX0sImlhdCI6MTcwMTY5MTU2MC4wLCJpc3MiOiJkaWQ6d2ViOnRhbGFvLmNvIiwianRpIjoiOGY1OTgyN"
          "DYtOTI5ZC0xMWVlLWJkNzQtMGExNjI4OTU4NTYwIiwicHVibGlzaGVkIjoiMjAyMy0xMS0yOCIsInNlbGZTb"
          "3ZlcmVpZ25JZGVudGl0eU9wdGlvbnMiOnsiY3VzdG9tT2lkYzR2Y1Byb2ZpbGUiOnsiY2xpZW50QXV0aGVud"
          "GljYXRpb24iOiJub25lIiwiY2xpZW50X2lkIjoiIiwiY2xpZW50X3NlY3JldCI6IiIsImNyeXB0b0hvbGRlc"
          "kJpbmRpbmciOnRydWUsImRlZmF1bHREaWQiOiJkaWQ6a2V5OmVic2kiLCJvaWRjNHZjaURyYWZ0IjoiMTAiL"
          "CJvaWRjNHZwRHJhZnQiOiIxMyIsInNjb3BlIjp0cnVlLCJzZWN1cml0eUxldmVsIjoibG93Iiwic2lvcHYyR"
          "HJhZnQiOiIxMiIsInN1YmplY3RTeW50YXhlVHlwZSI6ImRpZCIsInVzZXJQaW5EaWdpdHMiOiI2In0sImRpc"
          "3BsYXlNYW5hZ2VEZWNlbnRyYWxpemVkSWQiOnRydWUsImRpc3BsYXlTc2lBZHZhbmNlZFNldHRpbmdzIjp0c"
          "nVlLCJkaXNwbGF5VmVyaWZpYWJsZURhdGFSZWdpc3RyeSI6dHJ1ZSwib2lkdjR2Y1Byb2ZpbGUiOiJjdXN0b"
          "20ifSwic2V0dGluZ3NNZW51Ijp7ImRpc3BsYXlEZXZlbG9wZXJNb2RlIjp0cnVlLCJkaXNwbGF5SGVscENlb"
          "nRlciI6dHJ1ZSwiZGlzcGxheVByb2ZpbGUiOnRydWV9LCJ2ZXJzaW9uIjoiMS42Iiwid2FsbGV0U2VjdXJpd"
          "HlPcHRpb25zIjp7ImNvbmZpcm1TZWN1cml0eVZlcmlmaWVyQWNjZXNzIjpmYWxzZSwiZGlzcGxheVNlY3Vya"
          "XR5QWR2YW5jZWRTZXR0aW5ncyI6dHJ1ZSwic2VjdXJlU2VjdXJpdHlBdXRoZW50aWNhdGlvbldpdGhQaW5Db"
          "2RlIjp0cnVlLCJ2ZXJpZnlTZWN1cml0eUlzc3VlcldlYnNpdGVJZGVudGl0eSI6ZmFsc2V9fQ.02QVvroqJf"
          "y5A-OajkG54htlAeiU0Q6oWEaFHTCMcDzh73p6dS86L4KznTv6c5NE0z_hh7fM3yWX1eiHGLET2w";
      const key = {
        "crv": "P-256",
        "kty": "EC",
        "kid": "did:web:talao.co#key-2",
        "x": "Bls7WaGu_jsharYBAzakvuSERIV_IFR2tS64e5p_Y_Q",
        "y": "haeKjXQ9uzyK4Ind1W4SBUkR_9udjjx1OmKK4vl1jko"
      };
      final jws = JsonWebSignature.fromCompactSerialization(jwt);
      final keyStore = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(key));
      final isVerified = await jws.verify(keyStore);
      expect(isVerified, isTrue);
    });
    test('appsup-dart/jose#57 - parse from JSON with multiple signatures',
        () async {
      final testData = {
        'payload':
            'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGF'
                'tcGxlLmNvbS9pc19yb290Ijp0cnVlfQ',
        'signatures': [
          {
            'protected': 'eyJhbGciOiJSUzI1NiJ9',
            'header': {'kid': '2010-12-29'},
            'signature': 'cC4hiUPoj9Eetdgtv3hF80EGrhuB__dzERat0XF9g2VtQgr9PJbu3XOiZj5RZ'
                'mh7AAuHIm4Bh-0Qc_lF5YKt_O8W2Fp5jujGbds9uJdbF9CUAr7t1dnZcAcQjb'
                'KBYNX4BAynRFdiuB--f_nZLgrnbyTyWzO75vRK5h6xBArLIARNPvkSjtQBMHl'
                'b1L07Qe7K0GarZRmB_eSN9383LcOLn6_dO--xi12jzDwusC-eOkHWEsqtFZES'
                'c6BfI7noOPqvhJ1phCnvWh6IeYI2w9QOYEUipUTI8np6LbgGY9Fs98rqVt5AX'
                'LIhWkWywlVmtVrBp0igcN_IoypGlUPQGe77Rw'
          },
          {
            'protected': 'eyJhbGciOiJFUzI1NiJ9',
            'header': {'kid': 'e9bc097a-ce51-4036-9562-d2ade882db0d'},
            'signature':
                'DtEhU3ljbEg8L38VWAfUAqOyKAM6-Xx-F4GawxaepmXFCgfTjDxw5djxLa8IS'
                    'lSApmWQxfKTUJqPP3-Kg6NU1Q'
          }
        ]
      };
      final jsonJWS = jsonEncode(testData);
      final jwsMap = jsonDecode(jsonJWS) as Map<String, dynamic>;
      final jws = JsonWebSignature.fromJson(jwsMap);
      expect(jws.recipients, isNotEmpty);
      expect(jws.toJson(), testData);
    });
  });
}

void _doTests(dynamic payload, dynamic key, dynamic encoded,
    {List<String>? allowedAlgorithms}) {
  var jws = encoded is String
      ? JsonWebSignature.fromCompactSerialization(encoded)
      : JsonWebSignature.fromJson(encoded);
  var keys = key is JsonWebKeySet
      ? key
      : JsonWebKeySet.fromKeys(key == null ? [] : [key]);
  var context = JsonWebKeyStore()..addKeySet(keys);

  Future<void> expectPayload(
    JoseObject jose, {
    List<String>? allowedAlgorithms,
  }) async {
    var content =
        await jose.getPayload(context, allowedAlgorithms: allowedAlgorithms);
    if (payload is String) {
      expect(content.stringContent, payload);
    } else if (payload is Map) {
      expect(content.jsonContent, payload);
    } else if (payload is List<int>) {
      expect(content.data, payload);
    }
  }

  test('decode', () {
    expectPayload(jws, allowedAlgorithms: allowedAlgorithms);
    if (encoded is String) {
      expect(jws.toCompactSerialization(), encoded);
    } else {
      expect(jws.toJson(), encoded);
    }
  });
  test('verify', () async {
    await expectPayload(jws, allowedAlgorithms: allowedAlgorithms);
  });
  test('create', () async {
    var builder = JsonWebSignatureBuilder()..content = payload;

    if (keys.keys.isEmpty) {
      builder.addRecipient(null, algorithm: 'none');
    } else {
      for (var key in keys.keys) {
        builder.addRecipient(key);
      }
    }

    var jws = builder.build();

    if (encoded is String) jws.toCompactSerialization();
    await expectPayload(jws, allowedAlgorithms: allowedAlgorithms);
  });
}
