## 0.6.0

> Note: This release has breaking changes.

 - **FIX**: resolve all four library bugs; drive honest unit coverage to ~95% ([#368](https://github.com/Bdaya-Dev/oidc/issues/368)). ([c86bee17](https://github.com/Bdaya-Dev/oidc/commit/c86bee17189a0a70fee947c685e91a55062b1d35))
 - **FIX**(ci): stop swallowing web test failures; pin dart:io fixture tests to vm ([#363](https://github.com/Bdaya-Dev/oidc/issues/363)). ([6102d835](https://github.com/Bdaya-Dev/oidc/commit/6102d8353b0d330f888ea8b8e9b4c52937be2236))
 - **FIX**(release): add package-name entrypoints for jose_plus and x509_plus. ([4bbcb7f3](https://github.com/Bdaya-Dev/oidc/commit/4bbcb7f3df69cf393be29bd5997f49c15add7ff4))
 - **FIX**(jose_plus): normalize crypto_keys_plus/x509_plus constraints to caret syntax. ([d0a1d55d](https://github.com/Bdaya-Dev/oidc/commit/d0a1d55da2507e2f12b1244dcedaa1481fad1aed))
 - **FEAT**(crypto): RSASSA-PSS (PS256/384/512) + EdDSA/Ed25519. ([6c5c6741](https://github.com/Bdaya-Dev/oidc/commit/6c5c674149fe0504207c95aefbda7fedfca72ae9))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))

## 0.4.8
 - **FIX**: JWE JSON parsing now handles missing `recipients` / `header` by deriving a single recipient from the protected header and validates absent `encrypted_key` for non-`dir` algorithms.
 - **FEAT**: Support unpadded Base64URL protected header (new parsing test). 
 - **TEST**: Added fallback, AAD, key wrap, and error path tests.
 - **CHORE**: Refactored `JsonWebEncryption.fromJson` for clarity.

## [0.5.0](https://github.com/Bdaya-Dev/jose/compare/v0.4.8...v0.5.0) (2026-05-11)


### Features

* add support for es256k algorithm ([a2d046a](https://github.com/Bdaya-Dev/jose/commit/a2d046a334a9060fc258610ce2e23c4865bfa3b3))
* implement ECDH-ES key agreement (ECDH-ES, ECDH-ES+A*KW) ([280ccaa](https://github.com/Bdaya-Dev/jose/commit/280ccaabf2ab9c4142e78fc1ee6411ce235776c1))
* publish jose_plus ([35d4471](https://github.com/Bdaya-Dev/jose/commit/35d44717e8175f50c26d9221bdcdc06aee46871b))
* remove dependency on package:collection ([77f99be](https://github.com/Bdaya-Dev/jose/commit/77f99be1524fa81d23e4460f8cd8611b4c226736))
* support compressed data in jwe ([4f1dd72](https://github.com/Bdaya-Dev/jose/commit/4f1dd72d1b764fa174e11546f47efbc68a83f37c))
* Updated dependencies: crypto_keys_plus and x509_plus ([d24a89f](https://github.com/Bdaya-Dev/jose/commit/d24a89f5127c0b9f68ff40bc0822bd1ab2053183))
* Updated dependencies: crypto_keys_plus to 0.5.0 and x509_plus to 0.3.3. ([d2d8b1d](https://github.com/Bdaya-Dev/jose/commit/d2d8b1d3befd571d8d2ffaa59e5ef67e7573cd31))
* use clock package ([a762b4a](https://github.com/Bdaya-Dev/jose/commit/a762b4a12e7549cbf211e2fcda627691b9a0f4d4))
* use clock package ([157694d](https://github.com/Bdaya-Dev/jose/commit/157694d6bdec8ff0b3d6e54eb2341e3471ac4d20))


### Bug Fixes

* 26 ([b91fb1e](https://github.com/Bdaya-Dev/jose/commit/b91fb1edcfa89cee333a415f8a3ef252844b4775))
* add missing keyId when constructing a JWK with EcPublicKey (pull request [#38](https://github.com/Bdaya-Dev/jose/issues/38) from tallinn1960) ([b8d11f3](https://github.com/Bdaya-Dev/jose/commit/b8d11f325914ead348ae97fa7e344eb3dca7ee8f))
* allow double values when converting to DateTime and Duration (pull request [#33](https://github.com/Bdaya-Dev/jose/issues/33) from PixelToast) ([3b204b1](https://github.com/Bdaya-Dev/jose/commit/3b204b10101c7db7dc275279dcc4090a1494d238))
* check if the keyIds exist before checking for the keyId mismatch ([a16a31c](https://github.com/Bdaya-Dev/jose/commit/a16a31c9fc4109aedd59b2b26dbc915909f09533))
* check if the keyIds exist before checking for the keyId mismatch ([4d5feb5](https://github.com/Bdaya-Dev/jose/commit/4d5feb5a3d4f0ec35f0be5c7f1442c893f99ff55))
* improved key resolution in JsonWebKeyStore ([b07799a](https://github.com/Bdaya-Dev/jose/commit/b07799aac1f56a9a21483feac026272aab30cc5d))
* **jwe:** fallback parsing for missing recipients/header, support unpadded protected header; refactor fromJson and add focused tests (fallback, AAD, key wrap, error paths). ([ef8b783](https://github.com/Bdaya-Dev/jose/commit/ef8b78364c35a927518154ee8f41db3bc36201f8))
* key_ops JWK field according to the RFC (pull request [#62](https://github.com/Bdaya-Dev/jose/issues/62) from sgt) ([331df9f](https://github.com/Bdaya-Dev/jose/commit/331df9fff020e808b9bd902f453554afe82c80c9))
* make unprotected header in JWE optional (pull request [#43](https://github.com/Bdaya-Dev/jose/issues/43) from heacare) ([aefeeb0](https://github.com/Bdaya-Dev/jose/commit/aefeeb043fd5203314a691deaece87fb4fbc54c2))
* merge upstream - fix JWK header key trust vulnerability ([a0b51cd](https://github.com/Bdaya-Dev/jose/commit/a0b51cd5d1a1e44d3489318b40a0aab1de99fddf))
* parse jws from json with multiple signatures ([#57](https://github.com/Bdaya-Dev/jose/issues/57)) ([87215b7](https://github.com/Bdaya-Dev/jose/commit/87215b7868f0402d9868928e8be756c0111b5cfb))
* parsing jws from json ([d4b19d2](https://github.com/Bdaya-Dev/jose/commit/d4b19d2254103f92aab13e71c04cffbab61eec88))
* parsing jws from json ([05c04f4](https://github.com/Bdaya-Dev/jose/commit/05c04f4329d1ea0fbe54ab57b7ecb602fc541635))
* proper error when there is a missing audience claim. ([05f4db7](https://github.com/Bdaya-Dev/jose/commit/05f4db7523f7106dc8b5c9ce06ddb57f268df062))
* try all keys when kid is absent ([8fd4860](https://github.com/Bdaya-Dev/jose/commit/8fd486004f267bd728372f2dc549c87ffb27fd19))
* type mismatch error on keyOperations getter (pull request [#37](https://github.com/Bdaya-Dev/jose/issues/37) from samataro) ([8afde0f](https://github.com/Bdaya-Dev/jose/commit/8afde0fda8f0e5232e115dbeff25d2367b7521cb))
* use 12 byte iv with AESGCM (pull request [#39](https://github.com/Bdaya-Dev/jose/issues/39) from tallinn1960) ([5b7e24d](https://github.com/Bdaya-Dev/jose/commit/5b7e24da01fc3e782203ace5be9752055b54b33d))


### Code Refactoring

* support for archive ^4.0.0 ([d6150a5](https://github.com/Bdaya-Dev/jose/commit/d6150a5aae365127936c821888e0923ac2ba45d3))

## 0.4.7
 - **DEPS**: Remove dependency on `package:collection`
 - **UPGRADE**: Updated to use crypto_keys_plus 0.5.0 which uses pointycastle 4.0.0.
 - **UPGRADE**: Updated to use x509_plus 0.3.3.

## 0.4.6

 - **FIX**: parsing jws from json. ([05c04f43](https://github.com/appsup-dart/jose/commit/05c04f4329d1ea0fbe54ab57b7ecb602fc541635))


## 0.4.5

 - **FIX**: check if the keyIds exist before checking for the keyId mismatch. ([4d5feb5a](https://github.com/appsup-dart/jose/commit/4d5feb5a3d4f0ec35f0be5c7f1442c893f99ff55))

## 0.4.4

 - **FIX**: proper error when there is a missing audience claim. ([05f4db75](https://github.com/appsup-dart/jose/commit/05f4db7523f7106dc8b5c9ce06ddb57f268df062))
 - **FEAT**: use clock package. ([157694d6](https://github.com/appsup-dart/jose/commit/157694d6bdec8ff0b3d6e54eb2341e3471ac4d20))

## 0.4.3
 - **fix**: proper error when there is a missing `aud` claim.

## 0.4.2
 - **feat**: add `sid` to JWT claims.

## 0.4.1
 - **FIX**: lower `package:collection` constraints.
 
## 0.4.0
 - **FIX**: use `x509_plus` and `crypto_keys_plus`.

## 0.3.5+1

 - **FIX**: try all keys when kid is absent. ([8fd48600](https://github.com/appsup-dart/jose/commit/8fd486004f267bd728372f2dc549c87ffb27fd19))
 - **FIX**: parse jws from json with multiple signatures ([#57](https://github.com/appsup-dart/jose/issues/57)). ([87215b78](https://github.com/appsup-dart/jose/commit/87215b7868f0402d9868928e8be756c0111b5cfb))
 - **FIX**: key_ops JWK field according to the RFC (pull request [#62](https://github.com/appsup-dart/jose/issues/62) from sgt). ([331df9ff](https://github.com/appsup-dart/jose/commit/331df9fff020e808b9bd902f453554afe82c80c9))
 - **FIX**: improved key resolution in JsonWebKeyStore. ([b07799aa](https://github.com/appsup-dart/jose/commit/b07799aac1f56a9a21483feac026272aab30cc5d))


## 0.3.5

 - **REFACTOR**: support for archive ^4.0.0. ([d6150a5a](https://github.com/appsup-dart/jose/commit/d6150a5aae365127936c821888e0923ac2ba45d3))
 - **FEAT**: support compressed data in jwe. ([4f1dd72d](https://github.com/appsup-dart/jose/commit/4f1dd72d1b764fa174e11546f47efbc68a83f37c))

## 0.3.4

 - **FEAT**: Support latest `package:http` ([#50](https://github.com/appsup-dart/jose/pull/50))


## 0.3.3

 - **FIX**: allow double values when converting to DateTime and Duration (pull request [#33](https://github.com/appsup-dart/jose/issues/33) from PixelToast). ([3b204b10](https://github.com/appsup-dart/jose/commit/3b204b10101c7db7dc275279dcc4090a1494d238))
 - **FIX**: type mismatch error on keyOperations getter (pull request [#37](https://github.com/appsup-dart/jose/issues/37) from samataro). ([8afde0fd](https://github.com/appsup-dart/jose/commit/8afde0fda8f0e5232e115dbeff25d2367b7521cb))
 - **FIX**: add missing keyId when constructing a JWK with EcPublicKey (pull request [#38](https://github.com/appsup-dart/jose/issues/38) from tallinn1960). ([b8d11f32](https://github.com/appsup-dart/jose/commit/b8d11f325914ead348ae97fa7e344eb3dca7ee8f))
 - **FIX**: use 12 byte iv with AESGCM (pull request [#39](https://github.com/appsup-dart/jose/issues/39) from tallinn1960). ([5b7e24da](https://github.com/appsup-dart/jose/commit/5b7e24da01fc3e782203ace5be9752055b54b33d))
 - **FIX**: make unprotected header in JWE optional (pull request [#43](https://github.com/appsup-dart/jose/issues/43) from heacare). ([aefeeb04](https://github.com/appsup-dart/jose/commit/aefeeb043fd5203314a691deaece87fb4fbc54c2))
 - **FEAT**: add support for es256k algorithm. ([a2d046a3](https://github.com/appsup-dart/jose/commit/a2d046a334a9060fc258610ce2e23c4865bfa3b3))


## 0.3.2

- Compatible with version `0.3.0` of `crypto_keys`

## 0.3.1

- JsonWebKey.parsePem handles CERTIFICATE
- `DefaultJsonWebKeySetLoader`: if possible, use HTTP headers to determine cache expiration. 

## 0.3.0

- Migrate null safety

## 0.2.2
- Bump `asn1lib` to 0.8.1.

## 0.2.1+1

- Fix docs

## 0.2.1

- Added JsonWebKey constructors for creating EC and RSA keys
- Added factory constructor for creating a JsonWebKey from crypto keys
- Added factory constructor for creating a JsonWebKey from a pem string
- Support for P-256K curve 

## 0.2.0

- Support RSAES-OAEP
- Allow x509 parameters in JWK
- JsonWebAlgorithm class
- Generating random non-symmetric keys
- cryptoKeyPair getter on JsonWebKey returning a `KeyPair` from `crypto_keys` package
- **Breaking Change**: loading jwk set from `package` or `file` url no longer supported by default. The new class 
`JsonWebKeySetLoader` can be used to override this behavior or manage the way jwk sets are loaded from an url. 

## 0.1.2

- Add `allowedAlgorithms` argument also in JWT

## 0.1.1

- Fix security issue: JWS with algorithm `none` was previously verified, 
now you can specify which algorithms are allowed and by default `none` is 
not allowed.  

## 0.1.0

- Initial version
