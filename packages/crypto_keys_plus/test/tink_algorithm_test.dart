import 'dart:typed_data';

import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

void main() {
  group('AEAD', () {
    group('AES-GCM', () {
      @isTest
      void doTest(String name, String keyValue, String plaintext, String aad,
          String iv, String ciphertext, String tag) {
        test(name, () {
          var key = SymmetricKey(keyValue: bytesFromHexString(keyValue));

          var encrypter = key.createEncrypter(algorithms.encryption.aes.gcm);

          var v = encrypter.decrypt(EncryptionResult(
              bytesFromHexString(ciphertext),
              initializationVector: bytesFromHexString(iv),
              authenticationTag: bytesFromHexString(tag),
              additionalAuthenticatedData: bytesFromHexString(aad)));

          expect(v, bytesFromHexString(plaintext));
        });
      }

      doTest('Test Case 1', '00000000000000000000000000000000', '', '',
          '000000000000000000000000', '', '58e2fccefa7e3061367f1d57a4e7455a');
      doTest(
          'Test Case 2',
          '00000000000000000000000000000000',
          '00000000000000000000000000000000',
          '',
          '000000000000000000000000',
          '0388dace60b6a392f328c2b971b2fe78',
          'ab6e47d42cec13bdf53a67b21257bddf');
      doTest(
          'Test Case 3',
          'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b391aafd255',
          '',
          'cafebabefacedbaddecaf888',
          '42831ec2217774244b7221b784d0d49c'
              'e3aa212f2c02a4e035c17e2329aca12e'
              '21d514b25466931c7d8f6a5aac84aa05'
              '1ba30b396a0aac973d58e091473f5985',
          '4d5c2af327cd64a62cf35abd2ba6fab4');
      doTest(
          'Test Case 4',
          'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          'cafebabefacedbaddecaf888',
          '42831ec2217774244b7221b784d0d49c'
              'e3aa212f2c02a4e035c17e2329aca12e'
              '21d514b25466931c7d8f6a5aac84aa05'
              '1ba30b396a0aac973d58e091',
          '5bc94fbc3221a5db94fae95ae7121a47');
      doTest(
          'Test Case 5',
          'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          'cafebabefacedbad',
          '61353b4c2806934a777ff51fa22a4755'
              '699b2a714fcdc6f83766e5f97b6c7423'
              '73806900e49f24b22b097544d4896b42'
              '4989b5e1ebac0f07c23f4598',
          '3612d2e79e3b0785561be14aaca2fccb');
      doTest(
          'Test Case 6',
          'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          '9313225df88406e555909c5aff5269aa'
              '6a7a9538534f7da1e4c303d2a318a728'
              'c3c0c95156809539fcf0e2429a6b5254'
              '16aedbf5a0de6a57a637b39b',
          '8ce24998625615b603a033aca13fb894'
              'be9112a5c3a211a8ba262a3cca7e2ca7'
              '01e4a9a4fba43c90ccdcb281d48c7c6f'
              'd62875d2aca417034c34aee5',
          '619cc5aefffe0bfa462af43c1699d050');
      doTest(
          'Test Case 13',
          '00000000000000000000000000000000'
              '00000000000000000000000000000000',
          '',
          '',
          '000000000000000000000000',
          '',
          '530f8afbc74536b9a963b4f1c4cb738b');
      doTest(
          'Test Case 14',
          '00000000000000000000000000000000'
              '00000000000000000000000000000000',
          '00000000000000000000000000000000',
          '',
          '000000000000000000000000',
          'cea7403d4d606b6e074ec5d3baf39d18',
          'd0d1c8a799996bf0265b98b5d48ab919');
      doTest(
          'Test Case 15',
          'feffe9928665731c6d6a8f9467308308'
              'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b391aafd255',
          '',
          'cafebabefacedbaddecaf888',
          '522dc1f099567d07f47f37a32a84427d'
              '643a8cdcbfe5c0c97598a2bd2555d1aa'
              '8cb08e48590dbb3da7b08b1056828838'
              'c5f61e6393ba7a0abcc9f662898015ad',
          'b094dac5d93471bdec1a502270e3cc6c');
      doTest(
          'Test Case 16',
          'feffe9928665731c6d6a8f9467308308'
              'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          'cafebabefacedbaddecaf888',
          '522dc1f099567d07f47f37a32a84427d'
              '643a8cdcbfe5c0c97598a2bd2555d1aa'
              '8cb08e48590dbb3da7b08b1056828838'
              'c5f61e6393ba7a0abcc9f662',
          '76fc6ece0f4e1768cddf8853bb2d551b');
      doTest(
          'Test Case 17',
          'feffe9928665731c6d6a8f9467308308'
              'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          'cafebabefacedbad',
          'c3762df1ca787d32ae47c13bf19844cb'
              'af1ae14d0b976afac52ff7d79bba9de0'
              'feb582d33934a4f0954cc2363bc73f78'
              '62ac430e64abe499f47c9b1f',
          '3a337dbf46a792c45e454913fe2ea8f2');
      doTest(
          'Test Case 18',
          'feffe9928665731c6d6a8f9467308308'
              'feffe9928665731c6d6a8f9467308308',
          'd9313225f88406e5a55909c5aff5269a'
              '86a7a9531534f7da2e4c303d8a318a72'
              '1c3c0c95956809532fcf0e2449a6b525'
              'b16aedf5aa0de657ba637b39',
          'feedfacedeadbeeffeedfacedeadbeefabaddad2',
          '9313225df88406e555909c5aff5269aa'
              '6a7a9538534f7da1e4c303d2a318a728'
              'c3c0c95156809539fcf0e2429a6b5254'
              '16aedbf5a0de6a57a637b39b',
          '5a8def2f0c9e53f1f75d7853659e2a20'
              'eeb2b22aafde6419a058ab4f6f746bf4'
              '0fc0c3b780f244452da3ebf1c5d82cde'
              'a2418997200ef82e44ae7e3f',
          'a44a8266ee1c8eb0c8b5d4cf5ae9f19a');
    });

    group('AES-EAX', () {
      @isTest
      void doTest(String name, String keyValue, String plaintext, String aad,
          String iv, String ciphertext, String tag) {
        test(name, () {
          var key = SymmetricKey(keyValue: bytesFromHexString(keyValue));

          var encrypter = key.createEncrypter(algorithms.encryption.aes.eax);

          var v = encrypter.decrypt(EncryptionResult(
              bytesFromHexString(ciphertext),
              initializationVector: bytesFromHexString(iv),
              authenticationTag: bytesFromHexString(tag),
              additionalAuthenticatedData: bytesFromHexString(aad)));

          expect(v, bytesFromHexString(plaintext));
        });
      }

      doTest(
          'Test Case 1',
          '233952dee4d5ed5f9b9c6d6ff80ff478',
          '',
          '6bfb914fd07eae6b',
          '62ec67f9c3a4a407fcb2a8c49031a8b3',
          '',
          'e037830e8389f27b025a2d6527e79d01');
      doTest(
          'Test Case 2',
          '91945d3f4dcbee0bf45ef52255f095a4',
          'f7fb',
          'fa3bfd4806eb53fa',
          'becaf043b0a23d843194ba972c66debd',
          '19dd',
          '5c4c9331049d0bdab0277408f67967e5');
      doTest(
          'Test Case 3',
          '01f74ad64077f2e704c0f60ada3dd523',
          '1a47cb4933',
          '234a3463c1264ac6',
          '70c3db4f0d26368400a10ed05d2bff5e',
          'd851d5bae0',
          '3a59f238a23e39199dc9266626c40f80');
      doTest(
          'Test Case 4',
          'd07cf6cbb7f313bdde66b727afd3c5e8',
          '481c9e39b1',
          '33cce2eabff5a79d',
          '8408dfff3c1a2b1292dc199e46b7d617',
          '632a9d131a',
          'd4c168a4225d8e1ff755939974a7bede');
      doTest(
          'Test Case 5',
          '35b6d0580005bbc12b0587124557d2c2',
          '40d0c07da5e4',
          'aeb96eaebe2970e9',
          'fdb6b06676eedc5c61d74276e1f8e816',
          '071dfe16c675',
          'cb0677e536f73afe6a14b74ee49844dd');
      doTest(
          'Test Case 6',
          'bd8e6e11475e60b268784c38c62feb22',
          '4de3b35c3fc039245bd1fb7d',
          'd4482d1ca78dce0f',
          '6eac5c93072d8e8513f750935e46da1b',
          '835bb4f15d743e350e728414',
          'abb8644fd6ccb86947c5e10590210a4f');
      doTest(
          'Test Case 7',
          '7c77d6e813bed5ac98baa417477a2e7d',
          '8b0a79306c9ce7ed99dae4f87f8dd61636',
          '65d2017990d62528',
          '1a8c98dcd73d38393b2bf1569deefc19',
          '02083e3979da014812f59f11d52630da30',
          '137327d10649b0aa6e1c181db617d7f2');
      doTest(
          'Test Case 8',
          '5fff20cafab119ca2fc73549e20f5b0d',
          '1bda122bce8a8dbaf1877d962b8592dd2d56',
          '54b9f04e6a09189a',
          'dde59b97d722156d4d9aff2bc7559826',
          '2ec47b2c4954a489afc7ba4897edcdae8cc3',
          '3b60450599bd02c96382902aef7f832a');
      doTest(
          'Test Case 9',
          'a4a4782bcffd3ec5e7ef6d8c34a56123',
          '6cf36720872b8513f6eab1a8a44438d5ef11',
          '899a175897561d7e',
          'b781fcf2f75fa5a8de97a9ca48e522ec',
          '0de18fd0fdd91e7af19f1d8ee8733938b1e8',
          'e7f6d2231618102fdb7fe55ff1991700');
      doTest(
          'Test Case 10',
          '8395fcf1e95bebd697bd010bc766aac3',
          'ca40d7446e545ffaed3bd12a740a659ffbbb3ceab7',
          '126735fcc320d25a',
          '22e7add93cfc6393c57ec0b3c17d6b44',
          'cb8920f87a6c75cff39627b56e3ed197c552d295a7',
          'cfc46afc253b4652b1af3795b124ab6e');
    }, skip: 'AES-EAX not implemented');
  });

  group('Digital Signatures', () {
    group('ECDSA', () {
      @isTest
      void doTest(
          String name,
          String message,
          String xCoordinate,
          String yCoordinate,
          String signature,
          AlgorithmIdentifier algorithm,
          Identifier curve) {
        test(name, () {
          var key = EcPublicKey(
              xCoordinate: bigIntFromHexString(xCoordinate),
              yCoordinate: bigIntFromHexString(yCoordinate),
              curve: curve);

          var verifier = key.createVerifier(algorithm);
          verifier.verify(bytesFromHexString(message),
              Signature(bytesFromHexString(signature)));
        });
      }

      doTest(
          'Test case 1',
          '60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6',
          '7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299',
          'EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716',
          'F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8',
          algorithms.signing.ecdsa.sha256,
          curves.p256);
      doTest(
          'Test case 2',
          'EC3A4E415B4E19A4568618029F427FA5DA9A8BC4AE92E02E06AAE5286B300C64'
              'DEF8F0EA9055866064A254515480BC13',
          '8015D9B72D7D57244EA8EF9AC0C621896708A59367F9DFB9F54CA84B3F1C9DB1'
              '288B231C3AE0D4FE7344FD2533264720',
          'ED0959D5880AB2D869AE7F6C2915C6D60F96507F9CB3E047C0046861DA4A799C'
              'FE30F35CC900056D7C99CD7882433709',
          '512C8CCEEE3890A84058CE1E22DBC2198F42323CE8ACA9135329F03C068E5112'
              'DC7CC3EF3446DEFCEB01A45C2667FDD5',
          algorithms.signing.ecdsa.sha512,
          curves.p384);
      doTest(
          'Test case 3',
          '01894550D0785932E00EAA23B694F213F8C3121F86DC97A04E5A7167DB4E5BCD3'
              '71123D46E45DB6B5D5370A7F20FB633155D38FFA16D2BD761DCAC474B9A2F502'
              '3A4',
          '00493101C962CD4D2FDDF782285E64584139C2F91B47F87FF82354D6630F746A2'
              '8A0DB25741B5B34A828008B22ACC23F924FAAFBD4D33F81EA66956DFEAA2BFDF'
              'CF5',
          '013E99020ABF5CEE7525D16B69B229652AB6BDF2AFFCAEF38773B4B7D08725F10'
              'CDB93482FDCC54EDCEE91ECA4166B2A7C6265EF0CE2BD7051B7CEF945BABD47E'
              'E6D',
          '01FBD0013C674AA79CB39849527916CE301C66EA7CE8B80682786AD60F98F7E78'
              'A19CA69EFF5C57400E3B3A0AD66CE0978214D13BAF4E9AC60752F7B155E2DE4D'
              'CE3',
          algorithms.signing.ecdsa.sha512,
          curves.p521);
    });

    group('RSA-SSA-PKCS1', () {
      @isTest
      void doTest(String name, String modulus, String exponent, String message,
          String signature, AlgorithmIdentifier algorithm) {
        test(name, () {
          var key = RsaPublicKey(
            exponent: bigIntFromHexString(exponent),
            modulus: bigIntFromHexString(modulus),
          );

          var verifier = key.createVerifier(algorithm);
          verifier.verify(bytesFromHexString(message),
              Signature(bytesFromHexString(signature)));
        });
      }

      doTest(
          'Test case 1',
          'c47abacc2a84d56f3614d92fd62ed36ddde459664b9301dcd1d61781cfcc026bcb2399bee7e75681a80b7bf500e2d08ceae1c42ec0b707927f2b2fe92ae852087d25f1d260cc74905ee5f9b254ed05494a9fe06732c3680992dd6f0dc634568d11542a705f83ae96d2a49763d5fbb24398edf3702bc94bc168190166492b8671de874bb9cecb058c6c8344aa8c93754d6effcd44a41ed7de0a9dcd9144437f212b18881d042d331a4618a9e630ef9bb66305e4fdf8f0391b3b2313fe549f0189ff968b92f33c266a4bc2cffc897d1937eeb9e406f5d0eaa7a14782e76af3fce98f54ed237b4a04a4159a5f6250a296a902880204e61d891c4da29f2d65f34cbb',
          '49d2a1',
          '95123c8d1b236540b86976a11cea31f8bd4e6c54c235147d20ce722b03a6ad756fbd918c27df8ea9ce3104444c0bbe877305bc02e35535a02a58dcda306e632ad30b3dc3ce0ba97fdf46ec192965dd9cd7f4a71b02b8cba3d442646eeec4af590824ca98d74fbca934d0b6867aa1991f3040b707e806de6e66b5934f05509bea',
          '51265d96f11ab338762891cb29bf3f1d2b3305107063f5f3245af376dfcc7027d39365de70a31db05e9e10eb6148cb7f6425f0c93c4fb0e2291adbd22c77656afc196858a11e1c670d9eeb592613e69eb4f3aa501730743ac4464486c7ae68fd509e896f63884e9424f69c1c5397959f1e52a368667a598a1fc90125273d9341295d2f8e1cc4969bf228c860e07a3546be2eeda1cde48ee94d062801fe666e4a7ae8cb9cd79262c017b081af874ff00453ca43e34efdb43fffb0bb42a4e2d32a5e5cc9e8546a221fe930250e5f5333e0efe58ffebf19369a3b8ae5a67f6a048bc9ef915bda25160729b508667ada84a0c27e7e26cf2abca413e5e4693f4a9405',
          algorithms.signing.rsa.sha256);
      doTest(
          'Test case 2',
          '9689eb163a617c0abbf01ddc0e6d88c37f8a6b0baec0f6cab8f8a683f372a53d028253a6ba502da462adaf4fd87c8dc2b03b6c07c2b6aacab1d8c8bd043d89f4effe72ea2547c73c6366a2efab9c916945820fb880890bc085564e57ee76f7107a008f71e941e9fd631aec78f82e410ea9c893faa3d553cd1ca628af1087ca1b0c6aef3b66edcee14d1d7dc48293ddd7deed1ccbe487c957585abb9509151038d53f46b068e3e139c7689bf8e8d38669896b8d082e65e458e1f82b8e8ec926e7aa0f97d08526e9636f2c00af4c2bd3d8bffc4bb93cd47b09af18883e11b639d47938d036f7cfeb77db74a2c09a6dee9df98b18eff2fda7d3f4135083bb3b59e2172244ec37bdbdcfe6e199d36dc949cda1cca123fb2be07803d003d76af3d7164453df77d44c7f2599636ca44d0b7a46218326b0c814ed322b9c4279b060f1b9e14b70f55a3751c4343763cdbf9c14637d2210c59fbd037be17ea6706846fdc7b9ab90278c01c458e64442f9256f3ad1cbceb22959d495063aaca1a3959eae03',
          'fa3751',
          '6459ea1d443df706907ffdd3ca2f193f93f5a349b50357d26748b767cde6ab5cbfe76b1acb2b9eb97da5c4d2ddc8d18e3a3b1a0326d475c1c2c49ca73c0fd3fc9540cbbba85ac52d6811fabd693a3b09a281d535715ab784df3ad7292606d15a70ccd1a7e2b1b48ad92a6a3f736f9fd5522d9a869c7b654446102e9493b3ed9f',
          '2b72942573b825cd1f0172119c23440a2b384b7f2a3c5582bb02f764e2b159ea9ad880ca61b3df7ca249134f4bec285083c7ebf984b192808e916af687ef6c6a9a6722a4fa9189fac1521d03853f3dd5a95ff4b9dbdbf3c7077f720650ead01945ab5bfee582ac1643526fbf68efe1bb3b6f7d2b4b01f2155aaea38a2c7ed29add23ee791a703d11e3b1b7c500d9a6b647c1337bf537c071e5bada6faa025bcaf5e5d1196998909c3d64758826939ae7fe1466dc6efc10a2b25e21186c2d135ceace33cdf490b13a0d10c2527e04200aa70bc1d4f3cfb04b5d2bc17aee881d3a788401f45443470bc639232088a9553c8d792aa5707654f075476a66b86368d5a92b4c84a3b4baba1b0b98bdebb85b48b82b8409f2e9c1aa500670329ff3b6e83e25c561110d47b2fe93ea2946a74f9730da9b7d126f8d7c3fa4a51fc30144a827831c186390998d552a1b677afe5afee46e9d4a5774a56355a4d1967677e75d176aef71c3fa061644d7a9582385877de67f87724b0a6e868f3a2eeafb68c53b',
          algorithms.signing.rsa.sha512);
    });

    group('RSA-SSA-PSS', () {
      @isTest
      void doTest(String name, String modulus, String exponent, String message,
          String signature, AlgorithmIdentifier algorithm) {
        test(name, () {
          var key = RsaPublicKey(
            exponent: bigIntFromHexString(exponent),
            modulus: bigIntFromHexString(modulus),
          );

          var verifier = key.createVerifier(algorithm);
          verifier.verify(bytesFromHexString(message),
              Signature(bytesFromHexString(signature)));
        });
      }

      doTest(
          'Test case 1',
          'a47d04e7cacdba4ea26eca8a4c6e14563c2ce03b623b768c0d49868a57121301dbf783d82f4c055e73960e70550187d0af62ac3496f0a3d9103c2eb7919a72752fa7ce8c688d81e3aee99468887a15288afbb7acb845b7c522b5c64e678fcd3d22feb84b44272700be527d2b2025a3f83c2383bf6a39cf5b4e48b3cf2f56eef0dfff18555e31037b915248694876f3047814415164f2c660881e694b58c28038a032ad25634aad7b39171dee368e3d59bfb7299e4601d4587e68caaf8db457b75af42fc0cf1ae7caced286d77fac6cedb03ad94f1433d2c94d08e60bc1fdef0543cd2951e765b38230fdd18de5d2ca627ddc032fe05bbd2ff21e2db1c2f94d8b',
          '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e43f',
          'e002377affb04f0fe4598de9d92d31d6c786040d5776976556a2cfc55e54a1dcb3cb1b126bd6a4bed2a184990ccea773fcc79d246553e6c64f686d21ad4152673cafec22aeb40f6a084e8a5b4991f4c64cf8a927effd0fd775e71e8329e41fdd4457b3911173187b4f09a817d79ea2397fc12dfe3d9c9a0290c8ead31b6690a6',
          '4f9b425c2058460e4ab2f5c96384da2327fd29150f01955a76b4efe956af06dc08779a374ee4607eab61a93adc5608f4ec36e47f2a0f754e8ff839a8a19b1db1e884ea4cf348cd455069eb87afd53645b44e28a0a56808f5031da5ba9112768dfbfca44ebe63a0c0572b731d66122fb71609be1480faa4e4f75e43955159d70f081e2a32fbb19a48b9f162cf6b2fb445d2d6994bc58910a26b5943477803cdaaa1bd74b0da0a5d053d8b1dc593091db5388383c26079f344e2aea600d0e324164b450f7b9b465111b7265f3b1b063089ae7e2623fc0fda8052cf4bf3379102fbf71d7c98e8258664ceed637d20f95ff0111881e650ce61f251d9c3a629ef222d',
          algorithms.signing.rsa.pss.withParameters(
              sigHash: algorithms.digest.sha256,
              mgf1Hash: algorithms.digest.sha256,
              saltLength: 32));
      doTest(
          'Test case 2',
          '99a5c8d094a5f917034667a0408b7ecfcaacc3f9784444e21773c3461ec355f0d0f52a5db0568a71d388696788ef66ae7340c6b28dbf925fe83557986575f79cca69217221397ed5808a26f7e7e714c93235f914d45c4a9af4619b20f511ad644bd3412dfdf0ff717f7aac746f310bfa9a141ac3dbf01c1fc74febd197938419c262293505c35f402f9053ad13c51a5960ecde55ec829e953f941af733e58705913767e7a7200d1d09e7e7e2d269fa29a558bb16304b059f13f4ca560a8101fe3720b4a779ec126427326caa132a3d3611d7dbc50336fac789ec406b397e1e36d7daf9b624bf639c82b859288747690c730c980b2f5a239dd95ad5389a2ec90c5778604713710383ae55d4d28c06d4ac26f0d1231f1d6762c8e0d918118156bc637760daea184746b8dcf6f61db274a7ddceaa074937ababad4549b97ab992494a807208abd789823f5d75c4b994089c8072cfc254e0d8202fd896476e96ad9d309a0e8e7301282f07eb2ae8edefb7dbbe13b96e8b4024c6b84de0a05e150285',
          '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008a649',
          'cc21593a6a0f737e2970b7c07984b070d761726296a07e24e056e68ff846b29cc1548179843d74dcee86479858b2c16e4cb84f2544b4ecdcb4dd43a04bb7183a768ae44a2712bf9ad47883acc2812f958306890ebea408c92eb4f001ed7dbf55f3a9c8d6d9f61e5fe32eb3253e59c18e863169478cd69b9155c335db66016f96',
          '0aa572a6845b870b8909a683bb7e6e7616f77beff28746116d8bc4b7335546b51e8006ed0fc9a0d66f63ce0b9ebf792d7efd4305d7624d545400a5fd6a06b78f174b86803f7cd1cc93e3a97286f0ea590e40ff26195aa219fe1510a016785223606d9311a16c59a8fe4a6da6ecd0c1d7775039290c2aaa17ed1eb1b54374f7e572db13cca3a638575f8004aa54a2fa98422fc07e43ad3a20dd93001493442677d883914dc74ec1cbebbbd3d2b6bad4666d91457b69b46a1a61f21298f1a67942ec86c876322dd366ed167814e9c8fc9040c5b4b7a859bbd880cb6bc241b9e327ce779e0783b1cf445e0b2f5771b3f5822a1364391c154dc506fff1fb9d9a35f80199a6b30b4b92b92619a40e21aea19284015863c44866c61ed904a7ad19ee04d966c0aae390636243565581ff20bd6e3cfb6e31f5afba964b311dc2d023a21998c8dd50ca453699190bd467429e2f88ace29c4d1da4da61aac1eda2380230aa8dbb63c75a3c1ec04da3a1f880c9c747acdb74a8395af58f5f044015ccaf6e94',
          algorithms.signing.rsa.pss.withParameters(
              sigHash: algorithms.digest.sha512,
              mgf1Hash: algorithms.digest.sha512,
              saltLength: 0));
    }, skip: 'RSA-SSA-PSS not implemented');
  });

  group('Hybrid Encryption', () {
    group('ECIES with AEAD and HKDF', () {
      @isTest
      void doTest(String name, String privateKey, String ciphertext,
          String encryptedKey, String plaintext) {
        test(name, () {
          var key = EcPrivateKey(
            eccPrivateKey: bigIntFromHexString(privateKey),
            curve: curves.p256,
          );
          print(key);
          // TODO
          throw UnimplementedError();
        });
      }

      doTest(
          'Test Case 1',
          '32588172ed65830571bb83748f7fddd383323208a7825c80a71bef846333eb02',
          '0401b11f8c9bafe30ae13f8bd15528714e752631a4328bf146009068e99489c8e9fae1ec39e3fe9994723711417fcab2af4b3c9b60117d47d33d35175c87b483b8935a73312940d1fbf8da3944a89b5e8b',
          'some context info',
          '');
      doTest(
          'Test Case 2',
          '32588172ed65830571bb83748f7fddd383323208a7825c80a71bef846333eb02',
          '040230023d1547b55af5a735a7f460722612126d7539d7cd0f677d308b29c6f52a964e66e7b0cb44cff1673df9e2c793f1477ca755807bfbeadcae1ab20b45ecb1501ca5e3f5b0626d3ca40aa5d010443d506e4df90b',
          'some context info',
          'hello');
      doTest(
          'Test Case 3',
          '32588172ed65830571bb83748f7fddd383323208a7825c80a71bef846333eb02',
          '0441ddd246cea0825bd68bddff05cec54a4ee678da35b2f5cfbbb32e5350bdd817214bfb7b5ed5528131bde56916062cfbd8b9952d9e0907a6e87e1de54db5df3aaccddd328efcf7771ce061e647488f66b8c11a9fca171dcff813e90b44b2739573f9f23b60202491870c7ff8aaf0ae46838e48f17f8dc1ad55b67809699dd31eb6ca50dfa9beeee32d30bdc00a1eb1d8b0cbcedbe50b1e24619cc5e79042f25f49e2c2d5a35c79e833c0d68e31a93da4173aacd0428b367594ed4636763d16c23e4f8c115d44bddc83bcefcaea13587238ce8b7a5d5fad53beeb59aaa1d7483eb4bac93ed50ed4d3e9fd5af760283fd38080b58744b73212a36039179ce6f96ef1ecaa05b5186967d81c06b9cd91140dfbd54084ddcfd941527719848a2eecb84278f6a0fe9357a3964f87222fcd16a12a353e1f64fd45dc227a4a2112da6f61269f22f16b41e68eadf0b6b3a48c67b9e7e3ec1c66eecce50dda8ecbce99d3778299aa28741b7247fbc46a1b8a908dc23943c2dd17210a270bb12b096c2c6a00400a95c62894a15b9fc44e709d27348f2f2644a786cd9e96caf42ea9b949f76e85e6f7365e15fa2902e851222c025f6c208269d799fcfc4c0b37aba8979ed9e6ccf543c217ee0b6ad05f0e3ffb92943d308c801b25efedab5bf93a733bdae611132d774d4b9ee4fb5e88ae63014315ae9571039a8c8c7020e2b3a1bbd4235b65af94771c8417c87fd6cab423b82a557f60a99ae7402dba205e05136dd34f0026fce87899d4b9819cc2b2ba686512d62c41a1e3a667a705ea45404aafa489cd7f53f42455fff3f9b22f960d12a2587efd6ed0fa3e00dd4645face1b2f1268e6019be70999eab00f0aeff3cb0e77b7c4a1ab1fdf15d00c4eedd7b75e8cf5c90119346894089ee0299d58f1d7ebac9b592da2325a5a738ea2baecc1468670f5aec880bce32efecfb2a7c5ad3ae4096b0a07aa9bfe6cbaf53da6757377bb692e55ec8caf5f0af28dafdc42e1d6e5893140945a853f56652c575b99d64399aad2d042948575134c8fe638fb0b80ac3a0f08a60f3aa817fe0a24c1fffee6933bd72ea460e0b241d3f5d98b2321ee25d8c0302353fcfd41bce964d73ff670422864506cc56f3470362c90144586ccbfc8e5e6fefbb70429b0a517e4b1badb449cd11092790aba6e19b914899872f4fb481c8dc47a33422fc05072ac99c958e40dae53d96ebd87cfbde67a0f050203a89e487da5e03364951830e43771d36abfbe8f5a7da8e7aa891f36a68dbe9a3b0e3dfbd1afd6327a3ced4a5cd8a5b256fef46d200df4af2e2da4dbb786ea0404bb968b6d961e4fc76f89e70ad7c9e11d6aee6526b75b399811f73c053a29582ba9295ea4d5a8fffb5a8ccbac008d291dd60e2041371acfc4c432a0ae0fcd8fa25c9551123c95da64caa134edaee5893e19c3c76075bef419c09681a67f4ede6f28d747b53afd61ddc937d7de96a22c7db10ad8700cade888de5d6f450c15d796978ddb5e6a52e5044e90247c988686d992105c85f6d198e2de859330f973ded4d7e5d90de57051dbaf0db0febd4cf9d44da155e55293b0930f89c1d21cc227eba9615ca47cce41d16eaddb5bf5dc9bc8477df5cf21f460b83241e7d0fa3707f9d2b322b9aaa42747d0653168b095ca0a83f38426688f6f10143cbd1b84c08583b09ed6192c7366ecc23af528fc2e8c585560f9bd0fcc255b82fc70723a92506bb475ebc1f5ae34a902bf2aa75997ed90a54762c8e83720833b2fd607eee1beb347a75d3bd0f174ed450a72cce79f1be426de9d6f1a6feff052674af141b3cea89f8e749118392e9533c62ddad870e60d509fd7abfa0bc33c2774b29a0170089b30d82047d6e130c49f6965f9871d1928b7f13e3e40ad8e3dc85195f4b312f9f6d8e4158aca23a611f6c6c798983555139942536f6ac59bbd6cc88b9933f22e81429e835bfd4fec27c67520d64a0ad8fd7feb6a3fbe52dc56cbbf59644b0fad0c462ed02ffbf7258e4b94bdedefb187fbdb729a0d56a36e876ac76de766eed416f39ab4e8b1982b8d0a87cd33182ae81ecf1d1d5202cc3e82c5762646d15db5f13cde3e81c83715195f9af9f27e01e1829ce529fa0f715db1f5d227bb201c7c127ea8d0e9c21739c7e9c6a0d8d5a1aaea5216c549f3715f889e583555ac1bfd77339f3eff1bee75ee2fc45457f5c3ffe9401b8b67f5bb3f305f3269fe6153ba34de3fa90016c76811cd54b4b49b17b244b1a4f6edfa2eaf46e2819aded26005b4ed712e8b700ae7b6123fa2c179640ee523f864360d116ee243f13c66d2cd61d422709648d905ab17edf0d0075d2fed443889e15344069b69b2d3d8273f197f8468baf167074bf6dfdeea5871f0c0652ab2801f394ef6fbf841e8072c8bf65026d85d441ca61e78785a2e7ca1e743640fecd6dfad8b77adcbb8bcb8ce8532ad0cd8b3e51269c26ad037545273f756c1a5511925408a5045af469ca947f9a3f5457bcc325d05291a192abe75b4da7c97a61adc2fa247984edb5a03285f1c3b99f13f6a22f007029faffdd38b62f7bf909ce602e4e06ab1ec4543013d354d0dd86d8933a53c17ead02faf0cc740d7191fe475be2f7940c234f8c73420774a7213fd2a477847527172c02a54928de5fde5f15616760e6f7ff3c03a233aec880a939d9f1ca68be7f474fd13184fe8f6deb0c4ea01617ea207d5d765d067fddba58b94f3b59d5996e9f5434f483e2f0079c48050f3ba941b589294c41a0f350451d566fe58a9c9688cc3a75da314ff4b3473eeac58664c5922ae4efae850fe0f7f11dcc089bc0b4df9a64547a35b2559f4a4a3e7d3782d850997baa589534921becde8dc3f76380ae36bd9730956aae9f59b121d8ae4dbbc586c6b45ad9d5c17cf6821b746177bc9fcb727db3f4aa190688c48826421de5ebcd429e0d9b479e66e676e8f9a3b4bd92621f47357a7b1b27942121f5a6e0087e4192a5f8cf4da942cc9d86eac5e',
          'some context info',
          '08b8b2b733424243760fe426a4b54908632110a66c2f6591eabd3345e3e4eb98fa6e264bf09efe12ee50f8f54e9f77b1e355f6c50544e23fb1433ddf73be84d879de7c0046dc4996d9e773f4bc9efe5738829adb26c81b37c93a1b270b20329d658675fc6ea534e0810a4432826bf58c941efb65d57a338bbd2e26640f89ffbc1a858efcb8550ee3a5e1998bd177e93a7363c344fe6b199ee5d02e82d522c4feba15452f80288a821a579116ec6dad2b3b310da903401aa62100ab5d1a36553e06203b33890cc9b832f79ef80560ccb9a39ce767967ed628c6ad573cb116dbefefd75499da96bd68a8a97b928a8bbc103b6621fcde2beca1231d206be6cd9ec7aff6f6c94fcd7204ed3455c68c83f4a41da4af2b74ef5c53f1d8ac70bdcb7ed185ce81bd84359d44254d95629e9855a94a7c1958d1f8ada5d0532ed8a5aa3fb2d17ba70eb6248e594e1a2297acbbb39d502f1a8c6eb6f1ce22b3de1a1f40cc24554119a831a9aad6079cad88425de6bde1a9187ebb6092cf67bf2b13fd65f27088d78b7e883c8759d2c4f5c65adb7553878ad575f9fad878e80a0c9ba63bcbcc2732e69485bbc9c90bfbd62481d9089beccf80cfe2df16a2cf65bd92dd597b0707e0917af48bbb75fed413d238f5555a7a569d80c3414a8d0859dc65a46128bab27af87a71314f318c782b23ebfe808b82b0ce26401d2e22f04d83d1255dc51addd3b75a2b1ae0784504df543af8969be3ea7082ff7fc9888c144da2af58429ec96031dbcad3dad9af0dcbaaaf268cb8fcffead94f3c7ca495e056a9b47acdb751fb73e666c6c655ade8297297d07ad1ba5e43f1bca32301651339e22904cc8c42f58c30c04aafdb038dda0847dd988dcda6f3bfd15c4b4c4525004aa06eeff8ca61783aacec57fb3d1f92b0fe2fd1a85f6724517b65e614ad6808d6f6ee34dff7310fdc82aebfd904b01e1dc54b2927094b2db68d6f903b68401adebf5a7e08d78ff4ef5d63653a65040cf9bfd4aca7984a74d37145986780fc0b16ac451649de6188a7dbdf191f64b5fc5e2ab47b57f7f7276cd419c17a3ca8e1b939ae49e488acba6b965610b5480109c8b17b80e1b7b750dfc7598d5d5011fd2dcc5600a32ef5b52a1ecc820e308aa342721aac0943bf6686b64b2579376504ccc493d97e6aed3fb0f9cd71a43dd497f01f17c0e2cb3797aa2a2f256656168e6c496afc5fb93246f6b1116398a346f1a641f3b041e989f7914f90cc2c7fff357876e506b50d334ba77c225bc307ba537152f3f1610e4eafe595f6d9d90d11faa933a15ef1369546868a7f3a45a96768d40fd9d03412c091c6315cf4fde7cb68606937380db2eaaa707b4c4185c32eddcdd306705e4dc1ffc872eeee475a64dfac86aba41c0618983f8741c5ef68d3a101e8a3b8cac60c905c15fc910840b94c00a0b9d0');
    }, skip: 'ECIES with AEAD and HKDF not implemented');
  });
}

Uint8List bytesFromHexString(String s) => Uint8List.fromList(List.generate(
    s.length ~/ 2, (i) => int.parse(s.substring(i * 2, i * 2 + 2), radix: 16)));

BigInt bigIntFromHexString(String s) => bytesFromHexString(s)
    .fold(BigInt.zero, (a, b) => a * BigInt.from(256) + BigInt.from(b));
