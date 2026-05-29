
[![Build Status](https://travis-ci.org/Bdaya-Dev/crypto_keys.svg?branch=master)](https://travis-ci.org/Bdaya-Dev/crypto_keys)
[:heart: sponsor](https://github.com/sponsors/rbellens)

A library for doing cryptographic signing/verifying and encrypting/decrypting.

It uses `pointycastle` under the hood, but exposes a more convenient 
api.



## Usage

### Signing 

A simple usage example:

```dart
import 'package:crypto_keys/crypto_keys.dart';
import 'dart:typed_data';

main() {
  // Create a key pair from a JWK representation
  var keyPair = new KeyPair.fromJwk({
    "kty": "oct",
    "k": "AyM1SysPpbyDfgZld3umj1qzKObwVMkoqQ-EstJQLr_T-1qS0gZH75"
        "aKtMN3Yj0iPS4hcgUuTwjAzZr1Z9CAow"
  });

  // A key pair has a private and public key, possibly one of them is null, if
  // required info was not available when construction
  // The private key can be used for signing
  var privateKey = keyPair.privateKey;

  // Create a signer for the key using the HMAC/SHA-256 algorithm
  var signer = privateKey.createSigner(algorithms.signing.hmac.sha256);

  // Sign some content, to be integrity protected
  var content = "It's me, really me";
  var signature = signer.sign("It's me, really me".codeUnits);

  print("Signing '$content'");
  print("Signature: ${signature.data}");

  // The public key can be used for verifying the signature
  var publicKey = keyPair.publicKey;

  // Create a verifier for the key using the specified algorithm
  var verifier = publicKey.createVerifier(algorithms.signing.hmac.sha256);

  var verified =
      verifier.verify(new Uint8List.fromList(content.codeUnits), signature);
  if (verified)
    print("Verification succeeded");
  else
    print("Verification failed");
}
```

### Encryption

A simple usage example:

```dart

import 'package:crypto_keys/crypto_keys.dart';
import 'dart:typed_data';

main() {
  // Generate a new random symmetric key pair
  var keyPair = new KeyPair.generateSymmetric(128);

  // Use the public key to create an encrypter with the AES/GCM algorithm
  var encrypter =
      keyPair.publicKey.createEncrypter(algorithms.encryption.aes.gcm);

  // Encrypt the content with an additional authentication data for integrity
  // protection
  var content = "A very secret text";
  var aad = "It is me";
  var v = encrypter.encrypt(new Uint8List.fromList(content.codeUnits),
      additionalAuthenticatedData: new Uint8List.fromList(aad.codeUnits));

  print("Encrypting '$content'");
  print("Ciphertext: ${v.data}");
  print("Authentication tag: ${v.authenticationTag}");

  // Use the private key to create the decrypter
  var decrypter =
      keyPair.privateKey.createEncrypter(algorithms.encryption.aes.gcm);

  // Decrypt and verify authentication tag
  var decrypted = decrypter.decrypt(v);

  print("Decrypted text: '${new String.fromCharCodes(decrypted)}'");
}

```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Bdaya-Dev/crypto_keys/issues


## Sponsor

Creating and maintaining this package takes a lot of time. If you like the result, please consider to [:heart: sponsor](https://github.com/sponsors/rbellens). 
With your support, I will be able to further improve and support this project.
