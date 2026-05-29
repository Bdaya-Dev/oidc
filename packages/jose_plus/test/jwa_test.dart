import 'dart:convert';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JWA', () {
    test('Generating keys', () {
      var data = utf8.encode('hello world');

      for (var a in JsonWebAlgorithm.allAlgorithms) {
        print(a.name);
        var keyPair = a.generateCryptoKeyPair();

        var key = a.jwkFromCryptoKeyPair(keyPair);
        if (key == null) {
          throw UnimplementedError('Unkown key');
        }
        if (a.type == 'oct') {
          expect((key.cryptoKeyPair.publicKey as SymmetricKey).keyValue,
              (keyPair.publicKey as SymmetricKey).keyValue);
        } else {
          expect(key.cryptoKeyPair.publicKey, keyPair.publicKey);
          expect(key.cryptoKeyPair.privateKey, keyPair.privateKey);
        }

        switch (a.use) {
          case 'sig':
            expect(key.keyOperations, {'sign', 'verify'});
            var signature = key.sign(data);
            expect(key.verify(data, signature), isTrue);
            break;
          case 'enc':
            expect(key.keyOperations, {'encrypt', 'decrypt'});
            var encrypted = key.encrypt(data);
            expect(
                key.decrypt(encrypted.data,
                    initializationVector: encrypted.initializationVector,
                    additionalAuthenticatedData:
                        encrypted.additionalAuthenticatedData,
                    authenticationTag: encrypted.authenticationTag),
                data);
        }
      }
    });
  });
}
