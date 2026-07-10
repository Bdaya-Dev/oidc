## 0.6.0

> Note: This release has breaking changes.

 - **FIX**(oidc_web_core): secureTokens silently persisted as plaintext on Firefox ([#360](https://github.com/Bdaya-Dev/oidc/issues/360)). ([656025d8](https://github.com/Bdaya-Dev/oidc/commit/656025d8175c1c4e27c827622e0433be336dd245))
 - **FIX**(oidc_core): close 7 P0 spec-audit findings ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([60907e96](https://github.com/Bdaya-Dev/oidc/commit/60907e96f33dce8bf961b26ed43cec20f56e595e))
 - **FIX**(oidc_web_core): avoid COOP closed-window false positives. ([5b24209b](https://github.com/Bdaya-Dev/oidc/commit/5b24209bafc99d21f3d6f85e320e0a110feebe43))
 - **FIX**(oidc_web_core): detect closed auth window ([#303](https://github.com/Bdaya-Dev/oidc/issues/303)). ([36f7a340](https://github.com/Bdaya-Dev/oidc/commit/36f7a34010fe1e8d62834592cd1084f4c4e5e0e9))
 - **FEAT**(oidc_web_core): encrypt secureTokens at rest (AES-GCM via WebCrypto) ([#324](https://github.com/Bdaya-Dev/oidc/issues/324) item 15). ([cf504300](https://github.com/Bdaya-Dev/oidc/commit/cf504300b1922a7f68a82c39ab8dfb42aafe487d))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))

## 0.5.0

- **FEAT**: encrypt the `secureTokens` namespace (access/refresh/id tokens,
  the OIDC nonce) at rest in `OidcWebStore`. AES-GCM via WebCrypto, with a
  non-extractable 256-bit key persisted (as a structured-clone `CryptoKey`
  object, never its raw bytes) in IndexedDB and a fresh random IV per write.
  Values are stored as a versioned `oidcenc.v1.<iv>.<ciphertext>` envelope.
  This is **defense-in-depth against disk/backup scraping and casual
  inspection -- it is NOT protection against XSS**: same-origin script can
  still call `crypto.subtle.decrypt` or simply read decrypted tokens back
  out through the `OidcStore` API. Harden against XSS itself (CSP, trusted
  types, dependency hygiene) and prefer a BFF for high-value applications.
  (audit #324 item 15)
  - No new required settings: `const OidcWebStore()` still works, and
    encryption is on by default (`OidcWebStoreEncryption.preferred`).
  - Values written before this feature (or written by the `preferred`
    fallback) are read through transparently and re-encrypted on next write
    -- no forced re-login. This migration is **forward-only**: downgrading
    to a version predating this feature will see encrypted values as opaque
    strings.
  - If WebCrypto/IndexedDB are unavailable (a non-secure-context origin, or
    IndexedDB disabled/ephemeral in some private-browsing modes), the
    default `preferred` mode falls back to the previous plaintext behavior
    with a one-shot warning; pass `encryption: OidcWebStoreEncryption.required`
    to throw an `OidcException` instead of ever writing plaintext.
  - No new dependencies: WebCrypto and IndexedDB are both already exposed by
    `package:web`.

## 0.4.0+3

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

## 0.4.0+2

 - Update a dependency to the latest release.

## 0.4.0+1

 - **FIX**(oidc_web_core): use isA() for JS interop checks. ([724c9a2a](https://github.com/Bdaya-Dev/oidc/commit/724c9a2a0ce9792653c58d17ec5f4122750278f3))

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

## 0.3.1+3

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

## 0.3.1+2

 - Update a dependency to the latest release.

## 0.3.1+1

 - Update a dependency to the latest release.

## 0.3.1

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

## 0.3.0+5

 - Update a dependency to the latest release.

## 0.3.0+4

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

## 0.3.0+3

 - Update a dependency to the latest release.

## 0.3.0+2

 - Update a dependency to the latest release.

## 0.3.0+1

 - Update a dependency to the latest release.

## 0.3.0

> Note: This release has breaking changes.

 - **REVERT**: local version. ([e948477a](https://github.com/Bdaya-Dev/oidc/commit/e948477a7134b36f2cd7f80186632c0a57516afd))
 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.2.0

> Note: This release has breaking changes.

 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.1.0+1

- feat: initial release
