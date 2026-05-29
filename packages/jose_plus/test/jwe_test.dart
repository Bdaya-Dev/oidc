import 'dart:convert';

import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JWE Examples from RFC7516', () {
    group('Example JWE using RSAES-OAEP and AES GCM', () {
      _doTests(
          'The true sign of intelligence is not knowledge but imagination.',
          JsonWebKey.fromJson({
            'kty': 'RSA',
            'n': 'oahUIoWw0K0usKNuOR6H4wkf4oBUXHTxRvgb48E-BVvxkeDNjbC4he8rUW'
                'cJoZmds2h7M70imEVhRU5djINXtqllXI4DFqcI1DgjT9LewND8MW2Krf3S'
                'psk_ZkoFnilakGygTwpZ3uesH-PFABNIUYpOiN15dsQRkgr0vEhxN92i2a'
                'sbOenSZeyaxziK72UwxrrKoExv6kc5twXTq4h-QChLOln0_mtUZwfsRaMS'
                'tPs6mS6XrgxnxbWhojf663tuEQueGC-FCMfra36C9knDFGzKsNa7LZK2dj'
                'YgyD3JR_MB_4NUJW_TqOQtwHYbxevoJArm-L5StowjzGy-_bq6Gw',
            'e': 'AQAB',
            'd': 'kLdtIj6GbDks_ApCSTYQtelcNttlKiOyPzMrXHeI-yk1F7-kpDxY4-WY5N'
                'WV5KntaEeXS1j82E375xxhWMHXyvjYecPT9fpwR_M9gV8n9Hrh2anTpTD9'
                '3Dt62ypW3yDsJzBnTnrYu1iwWRgBKrEYY46qAZIrA2xAwnm2X7uGR1hghk'
                'qDp0Vqj3kbSCz1XyfCs6_LehBwtxHIyh8Ripy40p24moOAbgxVw3rxT_vl'
                't3UVe4WO3JkJOzlpUf-KTVI2Ptgm-dARxTEtE-id-4OJr0h-K-VFs3VSnd'
                'VTIznSxfyrj8ILL6MG_Uv8YAu7VILSB3lOW085-4qE3DzgrTjgyQ',
            'p': '1r52Xk46c-LsfB5P442p7atdPUrxQSy4mti_tZI3Mgf2EuFVbUoDBvaRQ-'
                'SWxkbkmoEzL7JXroSBjSrK3YIQgYdMgyAEPTPjXv_hI2_1eTSPVZfzL0lf'
                'fNn03IXqWF5MDFuoUYE0hzb2vhrlN_rKrbfDIwUbTrjjgieRbwC6Cl0',
            'q': 'wLb35x7hmQWZsWJmB_vle87ihgZ19S8lBEROLIsZG4ayZVe9Hi9gDVCOBm'
                'UDdaDYVTSNx_8Fyw1YYa9XGrGnDew00J28cRUoeBB_jKI1oma0Orv1T9aX'
                'IWxKwd4gvxFImOWr3QRL9KEBRzk2RatUBnmDZJTIAfwTs0g68UZHvtc',
            'dp': 'ZK-YwE7diUh0qR1tR7w8WHtolDx3MZ_OTowiFvgfeQ3SiresXjm9gZ5KL'
                'hMXvo-uz-KUJWDxS5pFQ_M0evdo1dKiRTjVw_x4NyqyXPM5nULPkcpU827'
                'rnpZzAJKpdhWAgqrXGKAECQH0Xt4taznjnd_zVpAmZZq60WPMBMfKcuE',
            'dq': 'Dq0gfgJ1DdFGXiLvQEZnuKEN0UUmsJBxkjydc3j4ZYdBiMRAy86x0vHCj'
                'ywcMlYYg4yoC4YZa9hNVcsjqA3FeiL19rk8g6Qn29Tt0cj8qqyFpz9vNDB'
                'UfCAiJVeESOjJDZPYHdHY8v1b-o-Z2X5tvLx-TCekf7oxyeKDUqKWjis',
            'qi': 'VIMpMYbPf47dT1w_zDUXfPimsSegnMOA1zTaX7aGk_8urY6R8-ZW1FxU7'
                'AlWAyLWybqq6t16VFd7hQd0y6flUK4SlOydB61gwanOsXGOAOv82cHq0E3'
                'eL4HrtZkUuKvnPrMnsUUFlfUdybVzxyjz9JF_XyaY14ardLSjf4L_FNY'
          }),
          'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZHQ00ifQ.'
              'OKOawDo13gRp2ojaHV7LFpZcgV7T6DVZKTyKOMTYUmKoTCVJRgckCL9kiMT03JGe'
              'ipsEdY3mx_etLbbWSrFr05kLzcSr4qKAq7YN7e9jwQRb23nfa6c9d-StnImGyFDb'
              'Sv04uVuxIp5Zms1gNxKKK2Da14B8S4rzVRltdYwam_lDp5XnZAYpQdb76FdIKLaV'
              'mqgfwX7XWRxv2322i-vDxRfqNzo_tETKzpVLzfiwQyeyPGLBIO56YJ7eObdv0je8'
              '1860ppamavo35UgoRdbYaBcoh9QcfylQr66oc6vFWXRcZ_ZT2LawVCWTIy3brGPi'
              '6UklfCpIMfIjf7iGdXKHzg.'
              '48V1_ALb6US04U3b.'
              '5eym8TW_c8SuK0ltJ3rpYIzOeDQz7TALvtu6UG9oMo4vpzs9tX_EFShS8iB7j6ji'
              'SdiwkIr3ajwQzaBtQD_A.'
              'XFBoMYUZodetZdvTiFvSkQ');
    });
    group('Example JWE using RSAES-PKCS1-v1_5 and AES_128_CBC_HMAC_SHA_256',
        () {
      _doTests(
          'Live long and prosper.',
          JsonWebKey.fromJson(
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
          ),
          'eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0.'
              'UGhIOguC7IuEvf_NPVaXsGMoLOmwvc1GyqlIKOK1nN94nHPoltGRhWhw7Zx0-kFm'
              '1NJn8LE9XShH59_i8J0PH5ZZyNfGy2xGdULU7sHNF6Gp2vPLgNZ__deLKxGHZ7Pc'
              'HALUzoOegEI-8E66jX2E4zyJKx-YxzZIItRzC5hlRirb6Y5Cl_p-ko3YvkkysZIF'
              'NPccxRU7qve1WYPxqbb2Yw8kZqa2rMWI5ng8OtvzlV7elprCbuPhcCdZ6XDP0_F8'
              'rkXds2vE4X-ncOIM8hAYHHi29NX0mcKiRaD0-D-ljQTP-cFPgwCp6X-nZZd9OHBv'
              '-B3oWh2TbqmScqXMR4gp_A.'
              'AxY8DCtDaGlsbGljb3RoZQ.'
              'KDlTtXchhZTGufMYmOYGS4HffxPSUrfmqCHXaI9wOGY.'
              '9hH0vgRfYgPnAHOd8stkvw');
    });
    group('Example JWE Using AES Key Wrap and AES_128_CBC_HMAC_SHA_256', () {
      _doTests(
          'Live long and prosper.',
          JsonWebKey.fromJson({'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg'}),
          'eyJhbGciOiJBMTI4S1ciLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0.'
              '6KB707dM9YTIgHtLvtgWQ8mKwboJW3of9locizkDTHzBC2IlrT1oOQ.'
              'AxY8DCtDaGlsbGljb3RoZQ.'
              'KDlTtXchhZTGufMYmOYGS4HffxPSUrfmqCHXaI9wOGY.'
              'U0m_YmjN04DJvceFICbCVQ');
    });
    group('Example JWE Using General JWE JSON Serialization', () {
      var keys = [
        JsonWebKey.fromJson(
          {
            'kty': 'RSA',
            'kid': '2011-04-29',
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
        ),
        JsonWebKey.fromJson(
            {'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg', 'kid': '7'}),
      ];
      var plaintext = 'Live long and prosper.';
      var encoded = {
        'protected': 'eyJlbmMiOiJBMTI4Q0JDLUhTMjU2In0',
        'unprotected': {'jku': 'https://server.example.com/keys.jwks'},
        'recipients': [
          {
            'header': {'alg': 'RSA1_5', 'kid': '2011-04-29'},
            'encrypted_key': 'UGhIOguC7IuEvf_NPVaXsGMoLOmwvc1GyqlIKOK1nN94nHPoltGRhWhw7Zx0-'
                'kFm1NJn8LE9XShH59_i8J0PH5ZZyNfGy2xGdULU7sHNF6Gp2vPLgNZ__deLKx'
                'GHZ7PcHALUzoOegEI-8E66jX2E4zyJKx-YxzZIItRzC5hlRirb6Y5Cl_p-ko3'
                'YvkkysZIFNPccxRU7qve1WYPxqbb2Yw8kZqa2rMWI5ng8OtvzlV7elprCbuPh'
                'cCdZ6XDP0_F8rkXds2vE4X-ncOIM8hAYHHi29NX0mcKiRaD0-D-ljQTP-cFPg'
                'wCp6X-nZZd9OHBv-B3oWh2TbqmScqXMR4gp_A'
          },
          {
            'header': {'alg': 'A128KW', 'kid': '7'},
            'encrypted_key':
                '6KB707dM9YTIgHtLvtgWQ8mKwboJW3of9locizkDTHzBC2IlrT1oOQ'
          }
        ],
        'iv': 'AxY8DCtDaGlsbGljb3RoZQ',
        'ciphertext': 'KDlTtXchhZTGufMYmOYGS4HffxPSUrfmqCHXaI9wOGY',
        'tag': 'Mz-VPPyU4RlcuYv1IwIvzw'
      };

      group('Example JWE Using General JWE JSON Serialization: Recipient 1',
          () {
        _doTests(plaintext, keys[0], encoded);
      });
      group('Example JWE Using General JWE JSON Serialization: Recipient 2',
          () {
        _doTests(plaintext, keys[1], encoded);
      });
    });
    group('Example JWE Using Flattened JWE JSON Serialization', () {
      _doTests(
          'Live long and prosper.',
          JsonWebKey.fromJson(
              {'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg', 'kid': '7'}),
          {
            'protected': 'eyJlbmMiOiJBMTI4Q0JDLUhTMjU2In0',
            'unprotected': {'jku': 'https://server.example.com/keys.jwks'},
            'header': {'alg': 'A128KW', 'kid': '7'},
            'encrypted_key':
                '6KB707dM9YTIgHtLvtgWQ8mKwboJW3of9locizkDTHzBC2IlrT1oOQ',
            'iv': 'AxY8DCtDaGlsbGljb3RoZQ',
            'ciphertext': 'KDlTtXchhZTGufMYmOYGS4HffxPSUrfmqCHXaI9wOGY',
            'tag': 'Mz-VPPyU4RlcuYv1IwIvzw'
          });
    });
  });
  group('Special algorithms JWE', () {
    test('Key wrapping with `dir`', () async {
      var payload = 'I am disguised';
      var builder = JsonWebEncryptionBuilder()..content = payload;

      var key = JsonWebKey.generate(builder.encryptionAlgorithm);
      var keyStore = JsonWebKeyStore()..addKey(key);

      builder.addRecipient(key, algorithm: 'dir');
      var jwe = builder.build();

      jwe = JsonWebEncryption.fromCompactSerialization(
          jwe.toCompactSerialization());

      expect((await jwe.getPayload(keyStore)).stringContent, payload);
    });
  });
  group('JWE Examples from jose4j', () {
    group('Example JWE Using RSAES-OAEP-256 and A128CBC-HS256', () {
      _doTests(
          "Well, as of this moment, they're on DOUBLE SECRET PROBATION!",
          JsonWebKey.fromJson({
            'kty': 'RSA',
            'n': '2cQJH1f6yF9DcGa8Cmbnhn4LHLs5L6kNb2rxkrNFZArJLRaKvaC3tMCKZ8Zg'
                'IpO9bVMPx5UMjJoaf7p9O5BSApVqA2J10fUbdSIomCcDwvGo0eyhty0D'
                'ILLWTMXzGEVM3BXzuJQoeDkuUCXXcCwA4Msyyd2OHVu-pB2OrGv6fcjH'
                'wjINty3UoKm08lCvAevBKHsuA-FFwQII9bycvRx5wRqFUjdMAyiOmLYB'
                'HBaJSi11g3HVexMcb29v14PSlVzdGUMN8oboa-zcIyaPrIiczLqAkSXQ'
                'NdEFHrjsJHfFeNMfOblLM7icKN_tyWujYeItt4kqUIimPn5dHjwgcQYE7w',
            'e': 'AQAB',
            'd': 'dyUz3ItVceX1Tv1WqtZMnKA_0jN5gWMcL7ayf5JISAlCssGfnUre2C10TH0U'
                'QjbVMIh-nLMnD5KNJw9Qz5MR28oGG932Gq7hm__ZeA34l-OCe4Ddpgwh'
                'pvVSHOU9MS1RdSUpmPavAcA_X6ikrAHXZSaoHhxzUgrNTpvBYQMfJUv_'
                '492fStIseQ9rwAMOpCWOiWMZOQm3KJVTLLunXdKf_UxmzmKXYKYZWke3'
                'AWIzUqnOfqIjfDTMunF4UWU0zKlhcsaQNmYMVrJGajD1bJdy_dbUU3LE'
                '8sx-bdkUI6oBk-sFtTTVyVdQcetG9kChJ5EnY5R6tt_4_xFG5kxzTo6qaQ',
            'p': '7yQmgE60SL7QrXpAJhChLgKnXWi6C8tVx1lA8FTpphpLaCtK-HbgBVHC'
                'prC2CfaM1mxFJZahxgFjC9ehuV8OzMNyFs8kekS82EsQGksi8HJP'
                'xyR1fU6ATa36ogPG0nNaqm3EDmYyjowhntgBz2OkbFAsTMHTdna-'
                'pZBRJa9lm5U',
            'q': '6R4dzo9LwHLO73EMQPQsmwXjVOvAS5W6rgQ-BCtMhec_QosAXIVE'
                '3AGyfweqZm6rurXCVFykDLwJ30GepLQ8nTlzeV6clx0x70sa'
                'GGKKVmCsHuVYWwgIRyJTrt4SX29NQDZ_FE52NlO3OhPkj1Ex'
                'Sk_pGMqGRFd26K8g0jJsXXM',
            'dp': 'VByn-hs0qB2Ncmb8ZycUOgWu7ljmjz1up1ZKU_3ZzJWVDkej7-6H'
                '7vcJ-u1OqgRxFv4v9_-aWPWl68VlWbkIkJbx6vniv6qrrXwB'
                'Zu4klOPwEYBOXsucrzXRYOjpJp5yNl2zRslFYQQC00bwpAxN'
                'CdfNLRZDlXhAqCUxlYqyt10',
            'dq': 'MJFbuGtWZvQEdRJicS3uFSY25LxxRc4eJJ8xpIC44rT5Ew4O'
                'tzf0zrlzzM92Cv1HvhCcOiNK8nRCwkbTnJEIh-EuU70I'
                'dttYSfilqSruk2x0r8Msk1qrDtbyBF60CToRKC2ycDKg'
                'olTyuaDnX4yU7lyTvdyD-L0YQwYpmmFy_k0',
            'qi': 'vy7XCwZ3jyMGik81TIZDAOQKC8FVUc0TG5KVYfti4tgw'
                'zUqFwtuB8Oc1ctCKRbE7uZUPwZh4OsCTLqIvqBQd'
                'a_kaxOxo5EF7iXj6yHmZ2s8P_Z_u3JLuh-oAT_6k'
                'mbLx6CAO0DbtKtxp24Ivc1hDfqSwWORgN1AOrSRC'
                'mE3nwxg'
          }),
          'eyJhbGciOiJSU0EtT0FFUC0yNTYiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0.'
              'fL5IL5cMCjjU9G9_ZjsD2XO0HIwTOwbVwulcZVw31_rx2qTcHzbYhIvrvbcVLTfJzn8xbQ3UEL442ZgZ1PcFYKENYePXiEyvYxPN8dmvj_'
              'OfLSJDEqR6kvwOb6nghGtxfzdB_VRvFt2eehbCA3gWpiOYHHvSTFdBPGx2KZHQisLz3oZR8EWiZ1woEpHy8a7FoQ2zzuDlZEJQOUrh09b_'
              'EJxmcE2jL6wmEtgabyxy3VgWg3GqSPUISlJZV9HThuVJezzktJdpntRDnAPUqjc8IwByGpMleIQcPuBUseRRPr_OsroOJ6eTl5DuFCmBOKb-eNNw5v-GEcVYr1w7X9oXoA.'
              '0frdIwx8P8UAzh1s9_PgOA.'
              'RAzILH0xfs0yxzML1CzzGExCfE2_wzWKs0FVuXfM8R5H68yTqTbqIqRCp2feAH5GSvluzmztk2_CkGNSjAyoaw.'
              '4nMUXOgmgWvM-08tIZ-h5w');
    });
  });

  test(
      'Issue #26: Non-Obvious error happening while trying to create JWE token',
      () async {
    var jwk =
        JsonWebKey.fromJson({'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg'});
    var builder = JsonWebEncryptionBuilder();
    builder.stringContent =
        '{"aud": "somekey", "sub": 12, "iss": "auth.example.com", "exp": 1617349353}';
    builder.setProtectedHeader('createdAt', DateTime.now().toIso8601String());
    builder.addRecipient(jwk, algorithm: 'dir');
    builder.encryptionAlgorithm = 'A256GCM';

    var jwe = builder.build();
    expect(
        utf8.decode(
            jwe.getPayloadFor(jwk, jwe.commonHeader, jwe.recipients.first)!),
        '{"aud": "somekey", "sub": 12, "iss": "auth.example.com", "exp": 1617349353}');
  });

  group('Fallback JWE JSON parsing (no recipients/header)', () {
    test('Direct encryption without encrypted_key succeeds', () async {
      var payload = 'Secret message';
      var builder = JsonWebEncryptionBuilder()..stringContent = payload;
      builder.encryptionAlgorithm = 'A256GCM';
      // Generate a symmetric key for direct encryption
      var key = JsonWebKey.generate(builder.encryptionAlgorithm);
      builder.addRecipient(key, algorithm: 'dir');
      var jwe = builder.build();
      // Build JSON representation without recipients/header and intentionally omit encrypted_key
      var compact = jwe.toCompactSerialization().split('.');
      // compact parts: [protected, encrypted_key (empty for dir), iv, ciphertext, tag]
      var fallbackJson = {
        'protected': compact[0],
        // intentionally no 'encrypted_key'
        'iv': compact[2],
        'ciphertext': compact[3],
        'tag': compact[4]
      };
      var parsed = JsonWebEncryption.fromJson(fallbackJson);
      var keyStore = JsonWebKeyStore()..addKey(key);
      expect((await parsed.getPayload(keyStore)).stringContent, payload);
    });

    test('Missing encrypted_key for non-direct algorithm throws', () async {
      var payload = 'Another secret';
      var builder = JsonWebEncryptionBuilder()..stringContent = payload;
      builder.encryptionAlgorithm = 'A128CBC-HS256';
      // Use an octet key suitable for key wrapping (A128KW)
      var key =
          JsonWebKey.fromJson({'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg'});
      builder.addRecipient(key, algorithm: 'A128KW');
      var jwe = builder.build();
      var compact = jwe.toCompactSerialization().split('.');
      // Remove encrypted_key field
      var fallbackJson = {
        'protected': compact[0],
        // encrypted_key omitted but algorithm in protected header is not 'dir'
        'iv': compact[2],
        'ciphertext': compact[3],
        'tag': compact[4]
      };
      expect(
          () => JsonWebEncryption.fromJson(fallbackJson), throwsArgumentError);
    });

    test('Parse JWE protected header (Base64URL unpadded)', () {
      final jweJson = {
        'ciphertext':
            'F9vgLFXCxXd46RVux-YNAT0aSxAevRvz0Po1vLrbc45vTC3r_S8fv2S24I9IVOjRvE1CJm73-cyf04CvtngCiyLwgzhnr2hFiIzVOQ4bM077_KqHkn0rWHD5xGekxNHcGpVMkcXfhwnRGNMTCfcnJV5YbolDNYXwYJw4Wcjk2suLCPB-NFK0yuakmszOzC82PIlKBJ4VQ0Gjh_R5DsQoz00IcpvQogzsYWxgbV87TsGXrjqbV8x97ng_8B0V0Yd9EURg3SWJqsuWFPFig9k2voNwurztmKoRiNbYEdIV5Zn-AP96G7p4i76rY0h_v-NdBsTz38z17Qu_1W8-RNsdcH0rGUblQPQV6VWVQjrS3D6AfSoz-uoYga2X3BISU1GTmsqtHnOauq03aT2pN33PqxQ0nxQgJ1bvU1E4BuHugN6Mt9kVwv9ssNeYk3QE6gax4LE24f1SGH3-PfKQ0hwGfeql6yRdVA',
        'encrypted_key':
            'eId1wPPb7TEH9PazhcUsYEk5_nPOfVmqxwui7W7k5bqbIvIsJKX7vIh3xrcYF51fheHvOdZfqewWoJY3PTtPwBg1pJ-IE6V8UPKFpyJ6p8ETjKpypE5VijXrYeqTfFAXxpU3dhk5xVnm7eF8YfymmqzHA2_ErFzqbHu6e5JK6xGFkSc_bMINBBs1612ow1HHBr1LnnGUGM5hVX0bydisnJG9kkxLX7PH_0Np1vzkRspVlsi16zK4uA09GXraxIVo5GQNPoEdoAqC7AK71DzThOBMZMbN7incVJxegBnO8G0oqkG9IvCHHglTP6wtOVF_qzNNZ36-q5uxDatw4-oc6Q',
        'iv': '4fX9lmzwwR1d4Jbw',
        'protected':
            'eyJhbGciOiJSU0EtT0FFUC0yNTYiLCJlbmMiOiJBMjU2R0NNIiwia2lkIjoiZGlkOmlkZW4zOmJpbGxpb25zOnRlc3Q6MlZ4bm9pTnFkTVB5SE10VXdBRXpobldxWEdrRWVKcEFwNG50VGtMOFhUI2tleTEiLCJ0eXAiOiJhcHBsaWNhdGlvbi9pZGVuM2NvbW0tZW5jcnlwdGVkLWpzb24ifQ',
        'tag': 'of7WWH7gbhEiADgowsXiOA',
      };
      // Parsing should succeed and derive header values from protected header (unpadded base64url)
      final jwe = JsonWebEncryption.fromJson(jweJson);
      final header = jwe.commonHeader;
      expect(header.algorithm, 'RSA-OAEP-256');
      expect(header.encryptionAlgorithm, 'A256GCM');
      expect(header.type, 'application/iden3comm-encrypted-json');
      expect(header.keyId, isNotNull);
      // Ensure keyId has expected suffix fragment
      expect(header.keyId!.endsWith('#key1'), isTrue);
      // Ensure no recipients array created (flattened/fallback single recipient)
      expect(jwe.recipients.length, 1);
    });

    test('Key wrapping (non-dir) fallback with encrypted_key present',
        () async {
      var payload = 'Key wrap fallback';
      var builder = JsonWebEncryptionBuilder()..stringContent = payload;
      builder.encryptionAlgorithm = 'A128CBC-HS256';
      var key =
          JsonWebKey.fromJson({'kty': 'oct', 'k': 'GawgguFyGrWKav7AX4VKUg'});
      builder.addRecipient(key, algorithm: 'A128KW');
      var jwe = builder.build();
      var parts = jwe.toCompactSerialization().split('.');
      var fallbackJson = {
        'protected': parts[0],
        'encrypted_key': parts[1],
        'iv': parts[2],
        'ciphertext': parts[3],
        'tag': parts[4]
      };
      var parsed = JsonWebEncryption.fromJson(fallbackJson);
      var store = JsonWebKeyStore()..addKey(key);
      expect((await parsed.getPayload(store)).stringContent, payload);
      expect(parsed.commonHeader.algorithm, 'A128KW');
      expect(parsed.commonHeader.encryptionAlgorithm, 'A128CBC-HS256');
    });

    test('Error when protected header missing', () {
      var json = {
        'iv': 'AA',
        'ciphertext': 'AA',
        'tag': 'AA'
      }; // intentionally minimal
      expect(() => JsonWebEncryption.fromJson(json), throwsArgumentError);
    });

    test('Error for invalid protected header base64/json', () {
      var json = {
        'protected': '***', // invalid base64 / json
        'iv': 'AA',
        'ciphertext': 'AA',
        'tag': 'AA'
      };
      expect(() => JsonWebEncryption.fromJson(json), throwsA(isA<Exception>()));
    });
  });
}

void _doTests(dynamic payload, dynamic key, dynamic encoded) {
  var jwe = encoded is String
      ? JsonWebEncryption.fromCompactSerialization(encoded)
      : JsonWebEncryption.fromJson(encoded);
  var keys = key is JsonWebKeySet
      ? key
      : JsonWebKeySet.fromKeys(key == null ? [] : [key]);
  var context = JsonWebKeyStore()..addKeySet(keys);

  Future<void> expectPayload(JsonWebEncryption jwe) async {
    var content = await jwe.getPayload(context);
    if (payload is String) {
      expect(content.stringContent, payload);
    } else if (payload is Map) {
      expect(content.jsonContent, payload);
    } else if (payload is List<int>) {
      expect(content.data, payload);
    }
  }

  test('decode', () {
    if (encoded is String) {
      expect(jwe.toCompactSerialization(), encoded);
    } else {
      expect(jwe.toJson(), encoded);
    }
  });
  test('decrypt', () async {
    await expectPayload(jwe);
  });
  test('create', () async {
    var builder = JsonWebEncryptionBuilder()
      ..content = payload
      ..encryptionAlgorithm = jwe.commonHeader.encryptionAlgorithm
      ..additionalAuthenticatedData = jwe.additionalAuthenticatedData;

    var p = jwe.sharedProtectedHeader!.toJson();
    p.forEach((k, v) => builder.setProtectedHeader(k, v));
    builder.encryptionAlgorithm = jwe.commonHeader.encryptionAlgorithm;
    if (keys.keys.isEmpty) {
      builder.addRecipient(null, algorithm: 'none');
    } else {
      for (var key in keys.keys) {
        builder.addRecipient(key, algorithm: jwe.commonHeader.algorithm);
      }
    }

    jwe = builder.build();

    if (encoded is String) jwe.toCompactSerialization();
    await expectPayload(jwe);
  });
}
