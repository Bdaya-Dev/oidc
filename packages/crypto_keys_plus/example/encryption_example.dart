import 'package:crypto_keys_plus/crypto_keys.dart';
import 'dart:typed_data';

void main() {
  // Generate a random symmetric key pair
  var keyPair = KeyPair.generateSymmetric(128);

  // Use the public key to create an encrypter with the AES/GCM algorithm
  var encrypter =
      keyPair.publicKey!.createEncrypter(algorithms.encryption.aes.gcm);

  // Encrypt the content with an additional authentication data for integrity
  // protection
  var content = 'A very secret text';
  var aad = 'It is me';
  var v = encrypter.encrypt(Uint8List.fromList(content.codeUnits),
      additionalAuthenticatedData: Uint8List.fromList(aad.codeUnits));

  print("Encrypting '$content'");
  print('Ciphertext: ${v.data}');
  print('Authentication tag: ${v.authenticationTag}');

  // Use the private key to create the decrypter
  var decrypter =
      keyPair.privateKey!.createEncrypter(algorithms.encryption.aes.gcm);

  // Decrypt and verify authentication tag
  var decrypted = decrypter.decrypt(v);

  print("Decrypted text: '${String.fromCharCodes(decrypted)}'");
}
