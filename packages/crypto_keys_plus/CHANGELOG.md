## 0.5.0
  -   **UPGRADE**: migrated to pointycastle 4.0.0.

## 0.4.0
  -   **REFACTOR**: remove dependency on quiver.
  -   **FIX**: return null instead of throwning when seeing an uknown curve/key type...  

## 0.3.0+1

 - **REFACTOR**: use OAEPEncoding.withSHA256 implementation from pointycastle. ([00510d2e](https://github.com/appsup-dart/crypto_keys/commit/00510d2e3df5b24541230832c162f06c571cd18c))
 - **REFACTOR**: use ECCurve_secp256k1 implementation of pointycastle. ([fa323419](https://github.com/appsup-dart/crypto_keys/commit/fa323419ee9b8512707b7903a43a86d3dca89e70))
 - **FIX**: A256GCM-encrypted content produced by this package not always decrypted correctly by other tools (pull request [#10](https://github.com/appsup-dart/crypto_keys/issues/10) of tallinn1960). ([45d65b35](https://github.com/appsup-dart/crypto_keys/commit/45d65b357e7bf313b64f25cb80bd23c9d9d682e2))
 - **FIX**: add missing ES256K algorithm to list of supported algorithms (pull request [#11](https://github.com/appsup-dart/crypto_keys/issues/11) from muhammadsaddamnur). ([c7e32c67](https://github.com/appsup-dart/crypto_keys/commit/c7e32c67b92953e30a1b791f4572c5d70567b75a))


## 0.3.0

- It is now a static error to pass a nullable algorithm parameter to `createVerifier` and `createSigner`

## 0.2.0

- Port to null-safety

## 0.1.4

- Upgraded dependency to Pointy Castle's new 2.0.0 release.

## 0.1.3

- Added support for P-256K curve

## 0.1.2

- Added RSAES-OAEP-256
- Generate assymetric key pairs

## 0.1.1

- Fix for running on web
- Added RSAES-OAEP 

## 0.1.0

- Initial version
