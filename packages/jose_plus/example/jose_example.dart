import 'dart:convert';
import 'dart:io';

import 'package:jose_plus/jose.dart';

void main() async {
  await example1();
  await example2();
  await example3();
  await example4();
  await example5();
  await example6();
  await example7();
  await example8();
  await example9();
  await example10();
}

// decode and verify a JWS
Future<void> example1() async {
  var encoded = 'eyJhbGciOiJFUzUxMiJ9.'
      'UGF5bG9hZA.'
      'AdwMgeerwtHoh-l192l60hp9wAHZFVJbLfD_UxMi70cwnZOYaRI1bKPWROc-mZZq'
      'wqT2SI-KGDKB34XO0aw_7XdtAG8GaSwFKdCAPZgoXD2YBJZCPEX3xKpRwcdOO8Kp'
      'EHwJjyqOgzDO7iKvU8vcnwNrmxYbSW9ERBXukOXolLzeO_Jn';

  // create a JsonWebSignature from the encoded string
  var jws = JsonWebSignature.fromCompactSerialization(encoded);

  // extract the payload
  var payload = jws.unverifiedPayload;

  print('content of jws: ${payload.stringContent}');
  print('protected parameters: ${payload.protectedHeader!.toJson()}');

  // create a JsonWebKey for verifying the signature
  var jwk = JsonWebKey.fromJson({
    'kty': 'EC',
    'crv': 'P-521',
    'x': 'AekpBQ8ST8a8VcfVOTNl353vSrDCLLJXmPk06wTjxrrjcBpXp5EOnYG_'
        'NjFZ6OvLFV1jSfS9tsz4qUxcWceqwQGk',
    'y': 'ADSmRA43Z1DSNx_RvcLI87cdL07l6jQyyBXMoxVg_l2Th-x3S1WDhjDl'
        'y79ajL4Kkd0AZMaZmh9ubmf63e3kyMj2',
    'd': 'AY5pb7A0UFiB3RELSD64fTLOSV_jazdF7fLYyuTw8lOfRhWg6Y6rUrPA'
        'xerEzgdRhajnu0ferB0d53vM9mE15j2C'
  });
  var keyStore = JsonWebKeyStore()..addKey(jwk);

  // verify the signature
  var verified = await jws.verify(keyStore);
  print('signature verified: $verified');
}

// create a JWS
Future<void> example2() async {
  // create a builder
  var builder = JsonWebSignatureBuilder();

  // set the content
  builder.stringContent = 'It is me';

  // set some protected header
  builder.setProtectedHeader('createdAt', DateTime.now().toIso8601String());

  // add a key to sign, you can add multiple keys for different recipients
  builder.addRecipient(
      JsonWebKey.fromJson({
        'kty': 'oct',
        'k':
            'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow'
      }),
      algorithm: 'HS256');

  // build the jws
  var jws = builder.build();

  // output the compact serialization
  print('jws compact serialization: ${jws.toCompactSerialization()}');

  // output the json serialization
  print('jws json serialization: ${jws.toJson()}');
}

// decode and decrypt a JWE
Future<void> example3() async {
  var encoded = 'eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0.'
      'UGhIOguC7IuEvf_NPVaXsGMoLOmwvc1GyqlIKOK1nN94nHPoltGRhWhw7Zx0-kFm'
      '1NJn8LE9XShH59_i8J0PH5ZZyNfGy2xGdULU7sHNF6Gp2vPLgNZ__deLKxGHZ7Pc'
      'HALUzoOegEI-8E66jX2E4zyJKx-YxzZIItRzC5hlRirb6Y5Cl_p-ko3YvkkysZIF'
      'NPccxRU7qve1WYPxqbb2Yw8kZqa2rMWI5ng8OtvzlV7elprCbuPhcCdZ6XDP0_F8'
      'rkXds2vE4X-ncOIM8hAYHHi29NX0mcKiRaD0-D-ljQTP-cFPgwCp6X-nZZd9OHBv'
      '-B3oWh2TbqmScqXMR4gp_A.'
      'AxY8DCtDaGlsbGljb3RoZQ.'
      'KDlTtXchhZTGufMYmOYGS4HffxPSUrfmqCHXaI9wOGY.'
      '9hH0vgRfYgPnAHOd8stkvw';

  // create a JsonWebEncryption from the encoded string
  var jwe = JsonWebEncryption.fromCompactSerialization(encoded);

  // create a JsonWebKey for decrypting the signature
  var jwk = JsonWebKey.fromJson(
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
  );
  var keyStore = JsonWebKeyStore()..addKey(jwk);

  // decrypt the payload
  var payload = await jwe.getPayload(keyStore);
  print('decrypted content: ${payload.stringContent}');
}

// create a JWE
Future<void> example4() async {
  // create a builder
  var builder = JsonWebEncryptionBuilder();

  // set the content
  builder.stringContent = 'This is my bigest secret';

  // set some protected header
  builder.setProtectedHeader('createdAt', DateTime.now().toIso8601String());

  // add a key to encrypt the Content Encryption Key
  var jwk = JsonWebKey.fromJson(
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
  );
  builder.addRecipient(jwk, algorithm: 'RSA1_5');

  // set the content encryption algorithm to use
  builder.encryptionAlgorithm = 'A128CBC-HS256';

  // build the jws
  var jwe = builder.build();

  // output the compact serialization
  print('jwe compact serialization: ${jwe.toCompactSerialization()}');

  // output the json serialization
  print('jwe json serialization: ${jwe.toJson()}');
}

// decode and verify and validate a JWT
Future<void> example5() async {
  var encoded = 'eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9.'
      'eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFt'
      'cGxlLmNvbS9pc19yb290Ijp0cnVlfQ.'
      'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';

  // decode the jwt, note: this constructor can only be used for JWT inside JWS
  // structures
  var jwt = JsonWebToken.unverified(encoded);

  // output the claims
  print('claims: ${jwt.claims}');

  // create key store to verify the signature
  var keyStore = JsonWebKeyStore()
    ..addKey(JsonWebKey.fromJson({
      'kty': 'oct',
      'k':
          'AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow'
    }));

  var verified = await jwt.verify(keyStore);
  print('verified: $verified');

  // alternatively, create and verify the JsonWebToken together, this is also
  // applicable for JWT inside JWE
  jwt = await JsonWebToken.decodeAndVerify(encoded, keyStore);

  // validate the claims
  var violations = jwt.claims.validate(issuer: Uri.parse('alice'));
  print('violations: $violations');
}

// create a JWT
Future<void> example6() async {
  var claims = JsonWebTokenClaims.fromJson({
    'exp':
        DateTime.now().add(Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000,
    'iss': 'alice',
  });

  // create a builder, decoding the JWT in a JWS, so using a
  // JsonWebSignatureBuilder
  var builder = JsonWebSignatureBuilder();
  builder.setProtectedHeader('typ', 'JWT');

  // set the content
  builder.jsonContent = claims.toJson();

  // add a key to sign, can only add one for JWT
  builder.addRecipient(
      JsonWebKey.fromJson({
        'kty': 'oct',
        'k': base64Urlencode(' ** my secret ** '),
      }),
      algorithm: 'HS256');

  // build the jws
  var jws = builder.build();

  // output the compact serialization
  print('jwt compact serialization: ${jws.toCompactSerialization()}');
}

String base64Urlencode(String secret) {
  var stringToBase64Url = utf8.fuse(base64Url);
  return stringToBase64Url.encode(secret);
}

// create a JWT, sign with RS512
Future<void> example7() async {
  var claims = JsonWebTokenClaims.fromJson({
    'exp':
        DateTime.now().add(Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000,
    'iss': 'alice',
  });

  // create a builder, decoding the JWT in a JWS, so using a
  // JsonWebSignatureBuilder
  var builder = JsonWebSignatureBuilder();
  builder.setProtectedHeader('typ', 'JWT');

  // set the content
  builder.jsonContent = claims.toJson();

  // add a key to sign, can only add one for JWT
  var key = JsonWebKey.fromPem(File('example/jwtRS512.key').readAsStringSync());
  builder.addRecipient(key, algorithm: 'RS512');

  // build the jws
  var jws = builder.build();

  // output the compact serialization
  print('jwt compact serialization: ${jws.toCompactSerialization()}');
}

// generate a key for use with ES256 signing
Future<void> example8() async {
  var alg = JsonWebAlgorithm.getByName('ES256');

  var key = alg.generateRandomKey();
  print(JsonEncoder.withIndent(' ').convert(key));

  final hash = utf8.encode('TEST');

  var sig = key.sign(hash);
  final valid = key.verify(hash, sig);

  print('valid? $valid');
}

// decode and decrypt a JWE with compression
Future<void> example9() async {
  var encoded =
      'eyJhbGciOiJSU0ExXzUiLCJlbmMiOiJBMjU2Q0JDLUhTNTEyIiwiemlwIjoiREVGIn0.pe4pvJvfuUdntcPNywk1lv3naOcVtw4AzM0BQt00UDtrmGdMVP9k2u8VbdjWM92GWg6RWdP4mBGsZTzF-ouO43ri8Pf7OmCGSn7kieRJ0en8anW03Z6YCdwmJcJGVadWh6astPOKHQKJ9NJUXDgYbub6-xCvxLvxO8ULsZViDEHkC8pXTu6-IXZDnwMc0YHIgt6mMTlvqae9h9EE97mNKoK3Dk2E3pju-ndOmhSswB-q_vKd4GhNbZfJpNGNuqKxj1MdcBWQbRR6CM6rrCkW5UV0MTGPdvYNrt64UdyjkcI_OlO_Xdau2vP9lCPW-_I0dPbSBm--d0-IioRWx7Rubw.PT70GBmWf4Y5X1oJHZ7DGw.OSRi9i-ePL7uZJxJP4H-L-LXF62wfgyYlqJBftR05yA.tXIsIKasRxqeyqkX6tCyy_HHkb2OywyU0X-abxW0Czo';

  // create a JsonWebEncryption from the encoded string
  var jwe = JsonWebEncryption.fromCompactSerialization(encoded);

  // create a JsonWebKey for decrypting the signature
  var jwk = JsonWebKey.fromJson(
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
  );
  var keyStore = JsonWebKeyStore()..addKey(jwk);

  // decrypt the payload
  var payload = await jwe.getPayload(keyStore);
  print('decrypted content: ${payload.stringContent}');
}

// create a JWE with compression
Future<void> example10() async {
  // create a builder
  var builder = JsonWebEncryptionBuilder();

  // set the content
  builder.stringContent = 'This is my bigest secret';

  // set some protected header
  builder.setProtectedHeader('createdAt', DateTime.now().toIso8601String());

  // add a key to encrypt the Content Encryption Key
  var jwk = JsonWebKey.fromJson(
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
  );
  builder.addRecipient(jwk, algorithm: 'RSA1_5');

  // set the content encryption algorithm to use
  builder.encryptionAlgorithm = 'A128CBC-HS256';
  builder.compressionAlgorithm = 'DEF';

  // build the jws
  var jwe = builder.build();

  // output the compact serialization
  print('jwe compact serialization: ${jwe.toCompactSerialization()}');

  // output the json serialization
  print('jwe json serialization: ${jwe.toJson()}');
}
