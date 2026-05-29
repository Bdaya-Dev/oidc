## 0.3.3

 - **UPGRADE**: Updated to use crypto_keys_plus 0.5.0 which uses pointycastle 4.0.0.

## 0.3.2

 - **FIX**: null-aware warnings (pull request [#25](https://github.com/appsup-dart/x509/pull/25) from faithoflifedev). ([d3f7fcb9](https://github.com/appsup-dart/x509/commit/d3f7fcb9956beefc6f41e67832a824304d09210b))
 - **FIX**: parse the 1.3.6.1.4.1.11129.2.4.2 OID used for the SCT list extension. ([9349b174](https://github.com/appsup-dart/x509/commit/9349b174fbce45242bbdef154bc96bde5b20e781))
 - **FEAT**: allow parsing of unknown extensions if they are non-critical (pull request [#22](https://github.com/appsup-dart/x509/issues/22) from sroddy). ([74b98a9c](https://github.com/appsup-dart/x509/commit/74b98a9c34884ec995646ac5716c81aec807b488))

## 0.3.1
 - lower `package:collection` constraints

## 0.3.0

  - **CHORE**: removed quiver dependency.
  - **CHORE**: use crypto_keys_plus instead.

## 0.2.5

 - **FIX**: parsing GeneralNames. ([b0e4cc0d](https://github.com/appsup-dart/x509/commit/b0e4cc0d26eaaaa756a9de1e6915c3a6bd71675b))
 - **FIX**: parsing certificates containing GeneralizedTime (pull request [#21](https://github.com/appsup-dart/x509/issues/21) from adamgillmore). ([850c55fb](https://github.com/appsup-dart/x509/commit/850c55fb60f4ebf705f5c3f5481635e5a4f498a3))
 - **FIX**: wrong cast in ObjectIdentifier.toAsn1() (pull request [#14](https://github.com/appsup-dart/x509/issues/14) from NicolaVerbeeck). ([95e838ca](https://github.com/appsup-dart/x509/commit/95e838ca08b5d049fb5bf6a29eecfd6486e89dcb))
 - **FEAT**: publish new version under x509_plus. ([b97cc1cc](https://github.com/appsup-dart/x509/commit/b97cc1cc5766d9ba97f2092a2f1eb839fa7dc4e9))
 - **FEAT**: ProxyCertInfo extension. ([17df803c](https://github.com/appsup-dart/x509/commit/17df803c9423c2d6329abfb8880353f46a78d145))
 - **FEAT**: NameConstraints extension. ([db387ef2](https://github.com/appsup-dart/x509/commit/db387ef29b76e7c41d59ce267f2a6365b016c5b0))
 - **FEAT**: QCStatements extension (pull request [#15](https://github.com/appsup-dart/x509/issues/15) from jeroentrappers). ([a5bbd73c](https://github.com/appsup-dart/x509/commit/a5bbd73ce9b1c3a30d063e4a4eed2d64837195bb))
 - **FEAT**: PrivateKeyUsagePeriod extension (pull request [#15](https://github.com/appsup-dart/x509/issues/15) from jeroentrappers). ([27cc8f50](https://github.com/appsup-dart/x509/commit/27cc8f5062665a0d6c873db529ab8bf6981c7556))
 - **FEAT**: support unknown policyidentifier (pull request [#12](https://github.com/appsup-dart/x509/issues/12) from nakajo2011). ([bb76649a](https://github.com/appsup-dart/x509/commit/bb76649a4abfc44a201cea4a66a6d2e4fd2a4187))
 - **DOCS**: add funding info. ([0b2a91ac](https://github.com/appsup-dart/x509/commit/0b2a91ac57acb7a632396fc410bedd8ba6df0aff))

## 0.2.4

- Require Dart 3.0
- Compatible with asn1lib: ^1.5.0


## 0.2.3

 - **FIX**: parsing certificates containing GeneralizedTime (pull request [#21](https://github.com/appsup-dart/x509/issues/21) from adamgillmore). ([850c55fb](https://github.com/appsup-dart/x509/commit/850c55fb60f4ebf705f5c3f5481635e5a4f498a3))
 - **FIX**: wrong cast in ObjectIdentifier.toAsn1() (pull request [#14](https://github.com/appsup-dart/x509/issues/14) from NicolaVerbeeck). ([95e838ca](https://github.com/appsup-dart/x509/commit/95e838ca08b5d049fb5bf6a29eecfd6486e89dcb))
 - **FEAT**: ProxyCertInfo extension. ([17df803c](https://github.com/appsup-dart/x509/commit/17df803c9423c2d6329abfb8880353f46a78d145))
 - **FEAT**: NameConstraints extension. ([db387ef2](https://github.com/appsup-dart/x509/commit/db387ef29b76e7c41d59ce267f2a6365b016c5b0))
 - **FEAT**: QCStatements extension (pull request [#15](https://github.com/appsup-dart/x509/issues/15) from jeroentrappers). ([a5bbd73c](https://github.com/appsup-dart/x509/commit/a5bbd73ce9b1c3a30d063e4a4eed2d64837195bb))
 - **FEAT**: PrivateKeyUsagePeriod extension (pull request [#15](https://github.com/appsup-dart/x509/issues/15) from jeroentrappers). ([27cc8f50](https://github.com/appsup-dart/x509/commit/27cc8f5062665a0d6c873db529ab8bf6981c7556))
 - **FEAT**: support unknown policyidentifier (pull request [#12](https://github.com/appsup-dart/x509/issues/12) from nakajo2011). ([bb76649a](https://github.com/appsup-dart/x509/commit/bb76649a4abfc44a201cea4a66a6d2e4fd2a4187))
 - **DOCS**: add funding info. ([0b2a91ac](https://github.com/appsup-dart/x509/commit/0b2a91ac57acb7a632396fc410bedd8ba6df0aff))

## 0.2.2

- Compatible with version `0.3.0` of `crypto_keys`

## 0.2.1

- Parse pem certificates

## 0.2.0

- Migrate null safety

## 0.1.4

- Bump `asn1lib` to 0.8.1.
- Support GeneralNames for using by Issuer/Subject Alternative Name

## 0.1.3

- Support for CertificatePolicies, CrlDistributionPoints and AuthorityInformationAccess extensions

## 0.1.2

- Support for EC keys

## 0.1.1

- Bugfix parsing strings stored as ASN1UTF8String

## 0.1.0

- Initial version
