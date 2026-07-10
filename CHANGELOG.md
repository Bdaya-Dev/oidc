# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-07-10

### Changes

---

Packages with breaking changes:

 - [`crypto_keys_plus` - `v0.6.0`](#crypto_keys_plus---v060)
 - [`jose_plus` - `v0.6.0`](#jose_plus---v060)
 - [`oidc` - `v0.15.0`](#oidc---v0150)
 - [`oidc_android` - `v0.9.0`](#oidc_android---v090)
 - [`oidc_cli` - `v0.1.0`](#oidc_cli---v010)
 - [`oidc_core` - `v0.17.0`](#oidc_core---v0170)
 - [`oidc_darwin` - `v2.0.0`](#oidc_darwin---v200)
 - [`oidc_desktop` - `v0.8.0`](#oidc_desktop---v080)
 - [`oidc_platform_interface` - `v0.8.0`](#oidc_platform_interface---v080)
 - [`oidc_web_core` - `v0.6.0`](#oidc_web_core---v060)
 - [`x509_plus` - `v0.4.0`](#x509_plus---v040)

Packages with other changes:

 - [`oidc_default_store` - `v0.6.1`](#oidc_default_store---v061)
 - [`oidc_linux` - `v0.5.0+4`](#oidc_linux---v0504)
 - [`oidc_loopback_listener` - `v0.3.1`](#oidc_loopback_listener---v031)
 - [`oidc_web` - `v0.7.1`](#oidc_web---v071)
 - [`oidc_windows` - `v0.4.0+4`](#oidc_windows---v0404)

---

#### `crypto_keys_plus` - `v0.6.0`

 - **FIX**(crypto_keys_plus): resolve pub.dev publish dry-run warnings. ([5bee9a89](https://github.com/Bdaya-Dev/oidc/commit/5bee9a8954e4fc5412f20db826aa7fe053eebabb))
 - **FEAT**(crypto): RSASSA-PSS (PS256/384/512) + EdDSA/Ed25519. ([6c5c6741](https://github.com/Bdaya-Dev/oidc/commit/6c5c674149fe0504207c95aefbda7fedfca72ae9))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))

#### `jose_plus` - `v0.6.0`

 - **FIX**(ci): stop swallowing web test failures; pin dart:io fixture tests to vm ([#363](https://github.com/Bdaya-Dev/oidc/issues/363)). ([6102d835](https://github.com/Bdaya-Dev/oidc/commit/6102d8353b0d330f888ea8b8e9b4c52937be2236))
 - **FIX**(release): add package-name entrypoints for jose_plus and x509_plus. ([4bbcb7f3](https://github.com/Bdaya-Dev/oidc/commit/4bbcb7f3df69cf393be29bd5997f49c15add7ff4))
 - **FIX**(jose_plus): normalize crypto_keys_plus/x509_plus constraints to caret syntax. ([d0a1d55d](https://github.com/Bdaya-Dev/oidc/commit/d0a1d55da2507e2f12b1244dcedaa1481fad1aed))
 - **FEAT**(crypto): RSASSA-PSS (PS256/384/512) + EdDSA/Ed25519. ([6c5c6741](https://github.com/Bdaya-Dev/oidc/commit/6c5c674149fe0504207c95aefbda7fedfca72ae9))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))

#### `oidc` - `v0.15.0`

 - **FIX**(oidc_darwin): implement flowTimeoutSeconds for the Apple ASWebAuthenticationSession flow. ([482f0186](https://github.com/Bdaya-Dev/oidc/commit/482f0186b8cdb37d309118de187e1c8496555d9a))
 - **FIX**(example): add patrol RunnerUITests UI-testing target for iOS. ([21b740f6](https://github.com/Bdaya-Dev/oidc/commit/21b740f645be41a0792299660d2a96db26fb378a))
 - **FIX**(example): wrap patrol conformance placeholder with SharedValue.wrapApp. ([831df91c](https://github.com/Bdaya-Dev/oidc/commit/831df91c7f041a96af10bf1c80ef92f49d45a2c8))
 - **FIX**(example): use FlutterFragmentActivity for Auth Tab (ComponentActivity). ([e6e9be47](https://github.com/Bdaya-Dev/oidc/commit/e6e9be47683d80897a6dce6f92433408c89155f4))
 - **FIX**: pre-v1 correctness — certification claim, license, Android queries, honest native option docs. ([3b8ef447](https://github.com/Bdaya-Dev/oidc/commit/3b8ef447f2a1c0af68ec6711c77d435531fb827f))
 - **FIX**(spm,native): SwiftPM layout migration + conformance fixes; fix Android build. ([47f7bd25](https://github.com/Bdaya-Dev/oidc/commit/47f7bd25feb5d4b7a2e3db67165a44ecdf4dae29))
 - **FIX**(native): harden iOS threading, simplify Android redirect to one-line setup. ([a7553f32](https://github.com/Bdaya-Dev/oidc/commit/a7553f326c1d67ac2bd057b0864688d73df24661))
 - **FIX**: handle refresh responses without id_token. ([4af363be](https://github.com/Bdaya-Dev/oidc/commit/4af363bed630d18394b28af1664f334aca3df8d9))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))
 - **BREAKING** **FEAT**(oidc_core): remove the strictJwtVerification fail-open opt-out. ([ee2146f9](https://github.com/Bdaya-Dev/oidc/commit/ee2146f9fa966c352a7c751673550bdcb5e7c0a5))
 - **BREAKING** **FEAT**(oidc_android): switch to Auth Tab only, remove Custom Tabs path. ([05bf0181](https://github.com/Bdaya-Dev/oidc/commit/05bf01811e299c472d49efb303fb657c939f0bd4))
 - **BREAKING** **FEAT**(oidc_android): add flowTimeoutSeconds to fix headless CI hang. ([01c844f5](https://github.com/Bdaya-Dev/oidc/commit/01c844f5bd98a3d983b9e50f9fa2192ed7013e50))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **BREAKING** **FEAT**(options): redesign native options API (v1 clean break, no AppAuth framing). ([a78954fe](https://github.com/Bdaya-Dev/oidc/commit/a78954feb4c4c6dfb0abc15f7e0a308be74d4e95))
 - **BREAKING** **FEAT**(oidc_macos): first-party ASWebAuthenticationSession; drop flutter_appauth. ([dc13f411](https://github.com/Bdaya-Dev/oidc/commit/dc13f411a3bfca4572a0f0e8fea2705365314d3c))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))
 - **BREAKING** **CHORE**: v1 dependency upgrade + drop the pigeon global-tool wrapper. ([45b62a3e](https://github.com/Bdaya-Dev/oidc/commit/45b62a3ef3f5b42cfb590111c9e37e144bbc11b0))

#### `oidc_android` - `v0.9.0`

 - **FIX**(example): use FlutterFragmentActivity for Auth Tab (ComponentActivity). ([e6e9be47](https://github.com/Bdaya-Dev/oidc/commit/e6e9be47683d80897a6dce6f92433408c89155f4))
 - **FIX**(oidc_android): remove duplicate mainHandler declaration. ([ae0f70c2](https://github.com/Bdaya-Dev/oidc/commit/ae0f70c20b4c011f35365be44673713622eeacc9))
 - **FIX**(oidc_android): use flowId self-check instead of Handler.removeCallbacks. ([c8f585a3](https://github.com/Bdaya-Dev/oidc/commit/c8f585a36912af3ef379fdb88eb046035b8d22dd))
 - **FIX**: pre-v1 correctness — certification claim, license, Android queries, honest native option docs. ([3b8ef447](https://github.com/Bdaya-Dev/oidc/commit/3b8ef447f2a1c0af68ec6711c77d435531fb827f))
 - **FIX**(native): harden iOS threading, simplify Android redirect to one-line setup. ([a7553f32](https://github.com/Bdaya-Dev/oidc/commit/a7553f326c1d67ac2bd057b0864688d73df24661))
 - **FEAT**(android): Auth Tab redirect-capture path (Phase 4, opt-in). ([0b80aaf2](https://github.com/Bdaya-Dev/oidc/commit/0b80aaf2a253f31f7b4fee62e91a0f10fdd1fa25))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **FEAT**(android): apply typed Custom Tabs options natively (Phase 1). ([10e903eb](https://github.com/Bdaya-Dev/oidc/commit/10e903ebcbdb7fa8cb33c7f2f4d30b58db26d33e))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))
 - **BREAKING** **FEAT**(oidc_android): switch to Auth Tab only, remove Custom Tabs path. ([05bf0181](https://github.com/Bdaya-Dev/oidc/commit/05bf01811e299c472d49efb303fb657c939f0bd4))
 - **BREAKING** **FEAT**(oidc_android): add flowTimeoutSeconds to fix headless CI hang. ([01c844f5](https://github.com/Bdaya-Dev/oidc/commit/01c844f5bd98a3d983b9e50f9fa2192ed7013e50))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **BREAKING** **FEAT**(native): migrate native transport to Pigeon + automate codegen. ([fc7606f3](https://github.com/Bdaya-Dev/oidc/commit/fc7606f3329cc493281a438ff76482436b018709))
 - **BREAKING** **FEAT**(oidc_android): replace flutter_appauth with first-party Custom Tabs auth. ([ddd64296](https://github.com/Bdaya-Dev/oidc/commit/ddd642968ca95cc57f0745d3ec59b5d9bc3c290f))

#### `oidc_cli` - `v0.1.0`

 - **FEAT**(storage): harden token storage at rest (RFC 9700 §4.9.3). ([76111b4a](https://github.com/Bdaya-Dev/oidc/commit/76111b4a1022a140c0b510e088becaed54835c0f))
 - **BREAKING** **CHORE**: v1 dependency upgrade + drop the pigeon global-tool wrapper. ([45b62a3e](https://github.com/Bdaya-Dev/oidc/commit/45b62a3ef3f5b42cfb590111c9e37e144bbc11b0))

#### `oidc_core` - `v0.17.0`

 - **FIX**(oidc_core): also ungate AUTO refresh-on-expiry from grant_types_supported ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([7e543b98](https://github.com/Bdaya-Dev/oidc/commit/7e543b98262334b17ebadce8c5761a6170a86025))
 - **FIX**(oidc_core): strip terminating slash when building well-known URL ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([975d446f](https://github.com/Bdaya-Dev/oidc/commit/975d446f4fa08478e9434463c55c917bbd3a39f8))
 - **FIX**(oidc_core): refetch JWKS on unknown kid with per-issuer cooldown. ([badeba7b](https://github.com/Bdaya-Dev/oidc/commit/badeba7bcfdea7c22f6f5b0707894b5dd5b741dd))
 - **FIX**(oidc_core): single-location client auth on token exchange and introspection (RFC 6749 §2.3). ([36f67e39](https://github.com/Bdaya-Dev/oidc/commit/36f67e39f8b02a614059325254204c047def938e))
 - **FIX**(oidc_core): validate RFC 9207 iss on authorization error responses. ([5916b65e](https://github.com/Bdaya-Dev/oidc/commit/5916b65e4a7ac58dae13ac5990d44e4b2f15b056))
 - **FIX**(core): update device-code flow test for the fail-closed JWT default. ([fa333f89](https://github.com/Bdaya-Dev/oidc/commit/fa333f899914ba47fc05bfb312de414cbb1df114))
 - **FIX**(oidc_core): always send id_token_hint on RP-initiated logout. ([434af9ab](https://github.com/Bdaya-Dev/oidc/commit/434af9ab0a02e55c189bceacc72767cac7076ede))
 - **FIX**(oidc_core): reject UserInfo responses missing sub (OIDC Core §5.3.2). ([f133c5b2](https://github.com/Bdaya-Dev/oidc/commit/f133c5b2a44dfd684379945244e70293e2663ac9))
 - **FIX**(oidc_core): send client auth in exactly one location on refresh (RFC 6749 §2.3). ([f6bf79a8](https://github.com/Bdaya-Dev/oidc/commit/f6bf79a866793750961d902dbdf87a5e1423e1fa))
 - **FIX**(oidc_core): percent-encode client_secret_basic credentials (RFC 6749 §2.3.1). ([94964778](https://github.com/Bdaya-Dev/oidc/commit/949647783dcb05c7d1658ce47e19c88b4a461e1f))
 - **FIX**(oidc_darwin): implement flowTimeoutSeconds for the Apple ASWebAuthenticationSession flow. ([482f0186](https://github.com/Bdaya-Dev/oidc/commit/482f0186b8cdb37d309118de187e1c8496555d9a))
 - **FIX**: pre-v1 correctness — certification claim, license, Android queries, honest native option docs. ([3b8ef447](https://github.com/Bdaya-Dev/oidc/commit/3b8ef447f2a1c0af68ec6711c77d435531fb827f))
 - **FIX**(core): DPoP — pad short EC coordinates (RFC 7638 jkt correctness). ([bd5568e7](https://github.com/Bdaya-Dev/oidc/commit/bd5568e73650e4ecdd8623141347300cbcef2b93))
 - **FIX**(core): harden DPoP thumbprint + JARM verification (adversarial-review fixes). ([69ac51aa](https://github.com/Bdaya-Dev/oidc/commit/69ac51aa16e602eab00765590fc0f221a0b213dd))
 - **FIX**(oidc_core): harden ID-token/UserInfo validation (P0 spec-compliance). ([1e7cfee9](https://github.com/Bdaya-Dev/oidc/commit/1e7cfee91f0de9391fea699300cac079f874843e))
 - **FIX**(oidc_core): kid-miss refetch on the cacheStore-less verification path. ([8eecbe28](https://github.com/Bdaya-Dev/oidc/commit/8eecbe28a99e5b0b0eba31c034ca8256c894d79f))
 - **FIX**(oidc_core): restore web/WASM compatibility for offline error handling. ([0c2e894a](https://github.com/Bdaya-Dev/oidc/commit/0c2e894a232514f0b6bfa1e7c3e8414756f1027d))
 - **FIX**: handle whitespace-only payloads. ([2751b841](https://github.com/Bdaya-Dev/oidc/commit/2751b841c8cef1f06c9e4ced7cf6df2dc5a6fd75))
 - **FIX**(oidc_core): close 7 P0 spec-audit findings ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([60907e96](https://github.com/Bdaya-Dev/oidc/commit/60907e96f33dce8bf961b26ed43cec20f56e595e))
 - **FIX**: handle refresh responses without id_token. ([4af363be](https://github.com/Bdaya-Dev/oidc/commit/4af363bed630d18394b28af1664f334aca3df8d9))
 - **FIX**: update packages/oidc_core/lib/src/managers/user_manager_base.dart. ([d62828c0](https://github.com/Bdaya-Dev/oidc/commit/d62828c06efc3fc9257d54a8818f189eb7e99b22))
 - **FIX**: handle empty response. ([03179667](https://github.com/Bdaya-Dev/oidc/commit/031796675c1b27cd8d32a036bd56dfcb9a9fedad))
 - **FEAT**(storage): harden token storage at rest (RFC 9700 §4.9.3). ([76111b4a](https://github.com/Bdaya-Dev/oidc/commit/76111b4a1022a140c0b510e088becaed54835c0f))
 - **FEAT**(android): apply typed Custom Tabs options natively (Phase 1). ([10e903eb](https://github.com/Bdaya-Dev/oidc/commit/10e903ebcbdb7fa8cb33c7f2f4d30b58db26d33e))
 - **FEAT**(oidc_core): deferred audit best-practice hardening (alg-pin, signed-userinfo, issuer, back-channel logout). ([7259290d](https://github.com/Bdaya-Dev/oidc/commit/7259290d48db2e5b59299b7c78bb99e97bf325b8))
 - **FEAT**(core): JAR signed request objects + JARM signed responses (RFC 9101 / JARM). ([19480489](https://github.com/Bdaya-Dev/oidc/commit/19480489e61419472ba8642fd75332fda7f1349a))
 - **FEAT**(core): validate the Hybrid-flow front-channel id_token (OIDC Core §3.3.2). ([8dbc582b](https://github.com/Bdaya-Dev/oidc/commit/8dbc582ba4160fdef2e85287449cff7e38ae5f01))
 - **FEAT**(core): Pushed Authorization Requests (PAR, RFC 9126) — endpoint + model. ([6eb09f8a](https://github.com/Bdaya-Dev/oidc/commit/6eb09f8a42e6033606eba6b7cd6805fdc9aeb64a))
 - **FEAT**(core): Token Introspection (RFC 7662) + step-up challenge parsing (RFC 9470). ([ab0cdff0](https://github.com/Bdaya-Dev/oidc/commit/ab0cdff07cda9b0cf54c5d90be5b3fad14bfdfd6))
 - **FEAT**(core): Resource Indicators (RFC 8707) + Token Exchange (RFC 8693). ([43d8d664](https://github.com/Bdaya-Dev/oidc/commit/43d8d664ff2db657319830db73a3cbcc03a50b00))
 - **FEAT**(core): DPoP resource-endpoint nonce retry (RFC 9449 §9). ([1d733790](https://github.com/Bdaya-Dev/oidc/commit/1d733790d2def393b57ebc2b3702ffe9c9c480dc))
 - **FEAT**(core): validate c_hash + auth_time/max_age (OIDC Core §3.3.2.11 / §3.1.2.1). ([93c81845](https://github.com/Bdaya-Dev/oidc/commit/93c8184559b01062b01185870bd59bc5d6eeb576))
 - **FEAT**(core): DPoP phase 3 — dpop_jkt auth-code binding + UserInfo DPoP scheme. ([d28b736f](https://github.com/Bdaya-Dev/oidc/commit/d28b736f0fff30dca43adad9fe43d4a4648faf24))
 - **FEAT**(core): DPoP phase 2 — use_dpop_nonce retry (centralized in the token endpoint). ([bc059b27](https://github.com/Bdaya-Dev/oidc/commit/bc059b2729f4dc81339325b7e9bcf148aeb8ed68))
 - **FEAT**(core): mint private_key_jwt / client_secret_jwt client assertions. ([c7043fcc](https://github.com/Bdaya-Dev/oidc/commit/c7043fccc2a452b3a79db6506d09b0d97f2e0890))
 - **FEAT**(core): Dynamic Client Registration + management (RFC 7591 / RFC 7592). ([55226655](https://github.com/Bdaya-Dev/oidc/commit/552266557dc0c5a87d3873f92e10240d52c64a4c))
 - **FEAT**(core): DPoP phase 1b — attach proofs to token-endpoint requests. ([c0207476](https://github.com/Bdaya-Dev/oidc/commit/c0207476c469f1ce14c0b9828af536219325094d))
 - **FEAT**(oidc): batch-2 audit hardening (loopback timeout, auth_time/max_age, resilient discovery parse, unverified-userinfo guard). ([d7f5965a](https://github.com/Bdaya-Dev/oidc/commit/d7f5965ac4ecbad0d7a79849e0e89d729a736169))
 - **FEAT**(core): DPoP (RFC 9449) crypto core — proof builder + key/thumbprint + manager. ([43f566d5](https://github.com/Bdaya-Dev/oidc/commit/43f566d509f6be194ba5f9190f7f8d19dc21ca4d))
 - **FEAT**(oidc_core): batch-3 audit hardening (signed_metadata verify, JWKS cache TTL, implicit/hybrid nonce assert). ([27a7f34d](https://github.com/Bdaya-Dev/oidc/commit/27a7f34d44723489c339b5169a3ad110919a9d6f))
 - **FEAT**(oidc_core): typed logout capability flags on provider metadata. ([74a6613a](https://github.com/Bdaya-Dev/oidc/commit/74a6613af511e1d5ff90e79957d61ed6a62d7ad4))
 - **FEAT**(oidc_core): enforce RFC 9207 iss require-when-advertised + error-path ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([3f324712](https://github.com/Bdaya-Dev/oidc/commit/3f324712f978c0c5af465261f9b9e3f300d6d398))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))
 - **BREAKING** **FIX**(core): always send PKCE (default S256), never downgrade (OAuth 2.1 / RFC 9700). ([99d1284a](https://github.com/Bdaya-Dev/oidc/commit/99d1284a274194fdc9cb030bbb240a5d4013f24f))
 - **BREAKING** **FIX**(core): fail-closed id_token verification + stricter validation (security). ([b4d92eaf](https://github.com/Bdaya-Dev/oidc/commit/b4d92eaf468a4405a8fef18602bcf132fcd254cc))
 - **BREAKING** **FEAT**(core): wire PAR (RFC 9126) into the authorization-code login flow. ([d2b44c32](https://github.com/Bdaya-Dev/oidc/commit/d2b44c323d2e0775595609ee619b42f2695d1e39))
 - **BREAKING** **FEAT**(core): id_token aud-strictness + at_hash validation (security). ([747d8a72](https://github.com/Bdaya-Dev/oidc/commit/747d8a72833a06feb5f8398fa26ce6d2cf74069e))
 - **BREAKING** **FEAT**(options): redesign native options API (v1 clean break, no AppAuth framing). ([a78954fe](https://github.com/Bdaya-Dev/oidc/commit/a78954feb4c4c6dfb0abc15f7e0a308be74d4e95))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))
 - **BREAKING** **FEAT**(core): revoke tokens on logout by default (RFC 7009). ([90a8cebd](https://github.com/Bdaya-Dev/oidc/commit/90a8cebdaa44359bb44f0f4103d39837780254f7))
 - **BREAKING** **FEAT**(oidc_android): add flowTimeoutSeconds to fix headless CI hang. ([01c844f5](https://github.com/Bdaya-Dev/oidc/commit/01c844f5bd98a3d983b9e50f9fa2192ed7013e50))
 - **BREAKING** **FEAT**(oidc_core): remove the strictJwtVerification fail-open opt-out. ([ee2146f9](https://github.com/Bdaya-Dev/oidc/commit/ee2146f9fa966c352a7c751673550bdcb5e7c0a5))
 - **BREAKING** **CHORE**: v1 dependency upgrade + drop the pigeon global-tool wrapper. ([45b62a3e](https://github.com/Bdaya-Dev/oidc/commit/45b62a3ef3f5b42cfb590111c9e37e144bbc11b0))

#### `oidc_darwin` - `v2.0.0`

 - **FIX**(oidc_darwin): implement flowTimeoutSeconds for the Apple ASWebAuthenticationSession flow. ([482f0186](https://github.com/Bdaya-Dev/oidc/commit/482f0186b8cdb37d309118de187e1c8496555d9a))
 - **DOCS**(oidc_darwin): add the on-device verification checklist. ([b22a1c06](https://github.com/Bdaya-Dev/oidc/commit/b22a1c06316a33198dbcd2826bee4fe4f9c608c8))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))

#### `oidc_desktop` - `v0.8.0`

 - **FEAT**(oidc): batch-2 audit hardening (loopback timeout, auth_time/max_age, resilient discovery parse, unverified-userinfo guard). ([d7f5965a](https://github.com/Bdaya-Dev/oidc/commit/d7f5965ac4ecbad0d7a79849e0e89d729a736169))
 - **BREAKING** **CHORE**: retire oidc_flutter_appauth (flutter_appauth fully removed). ([4805b1b4](https://github.com/Bdaya-Dev/oidc/commit/4805b1b4eff7c292a5cf826f2595f2ddd8b82944))

#### `oidc_platform_interface` - `v0.8.0`

 - **FIX**(oidc_platform_interface): declare meta as a direct dependency. ([21b79a43](https://github.com/Bdaya-Dev/oidc/commit/21b79a436649435c97221a4adf29321c9873d2bd))
 - **FIX**(native): harden iOS threading, simplify Android redirect to one-line setup. ([a7553f32](https://github.com/Bdaya-Dev/oidc/commit/a7553f326c1d67ac2bd057b0864688d73df24661))
 - **FEAT**(observability): native browser events via the existing OidcEvent stream (Phase 3). ([91d1f5bd](https://github.com/Bdaya-Dev/oidc/commit/91d1f5bdfa1526aec170474181ec71ad1bf38c59))
 - **BREAKING** **FEAT**: merge oidc_ios + oidc_macos into a unified oidc_darwin plugin. ([db73858e](https://github.com/Bdaya-Dev/oidc/commit/db73858e71b3b869326867b05b9d1ead3629acb9))
 - **BREAKING** **FEAT**(native): migrate native transport to Pigeon + automate codegen. ([fc7606f3](https://github.com/Bdaya-Dev/oidc/commit/fc7606f3329cc493281a438ff76482436b018709))
 - **BREAKING** **FEAT**(oidc_macos): first-party ASWebAuthenticationSession; drop flutter_appauth. ([dc13f411](https://github.com/Bdaya-Dev/oidc/commit/dc13f411a3bfca4572a0f0e8fea2705365314d3c))
 - **BREAKING** **CHORE**: v1 dependency upgrade + drop the pigeon global-tool wrapper. ([45b62a3e](https://github.com/Bdaya-Dev/oidc/commit/45b62a3ef3f5b42cfb590111c9e37e144bbc11b0))

#### `oidc_web_core` - `v0.6.0`

 - **FIX**(oidc_web_core): secureTokens silently persisted as plaintext on Firefox ([#360](https://github.com/Bdaya-Dev/oidc/issues/360)). ([656025d8](https://github.com/Bdaya-Dev/oidc/commit/656025d8175c1c4e27c827622e0433be336dd245))
 - **FIX**(oidc_core): close 7 P0 spec-audit findings ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([60907e96](https://github.com/Bdaya-Dev/oidc/commit/60907e96f33dce8bf961b26ed43cec20f56e595e))
 - **FIX**(oidc_web_core): avoid COOP closed-window false positives. ([5b24209b](https://github.com/Bdaya-Dev/oidc/commit/5b24209bafc99d21f3d6f85e320e0a110feebe43))
 - **FIX**(oidc_web_core): detect closed auth window ([#303](https://github.com/Bdaya-Dev/oidc/issues/303)). ([36f7a340](https://github.com/Bdaya-Dev/oidc/commit/36f7a34010fe1e8d62834592cd1084f4c4e5e0e9))
 - **FEAT**(oidc_web_core): encrypt secureTokens at rest (AES-GCM via WebCrypto) ([#324](https://github.com/Bdaya-Dev/oidc/issues/324) item 15). ([cf504300](https://github.com/Bdaya-Dev/oidc/commit/cf504300b1922a7f68a82c39ab8dfb42aafe487d))
 - **BREAKING** **REFACTOR**: remove rxdart; adopt bdaya_shared_value ^5.0.0. ([0d65d7fd](https://github.com/Bdaya-Dev/oidc/commit/0d65d7fde062e2db7ffbdd31a47735c59954045a))

#### `x509_plus` - `v0.4.0`

 - **FIX**(ci): stop swallowing web test failures; pin dart:io fixture tests to vm ([#363](https://github.com/Bdaya-Dev/oidc/issues/363)). ([6102d835](https://github.com/Bdaya-Dev/oidc/commit/6102d8353b0d330f888ea8b8e9b4c52937be2236))
 - **FIX**(release): add package-name entrypoints for jose_plus and x509_plus. ([4bbcb7f3](https://github.com/Bdaya-Dev/oidc/commit/4bbcb7f3df69cf393be29bd5997f49c15add7ff4))
 - **BREAKING** **FEAT**: consolidate jose_plus, crypto_keys_plus, x509_plus into the workspace. ([3fffc6cd](https://github.com/Bdaya-Dev/oidc/commit/3fffc6cd51f2abb0ead643acc2ec4d5741fac8e5))

#### `oidc_default_store` - `v0.6.1`

 - **FIX**(oidc_core): close 7 P0 spec-audit findings ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([60907e96](https://github.com/Bdaya-Dev/oidc/commit/60907e96f33dce8bf961b26ed43cec20f56e595e))
 - **FEAT**(storage): harden token storage at rest (RFC 9700 §4.9.3). ([76111b4a](https://github.com/Bdaya-Dev/oidc/commit/76111b4a1022a140c0b510e088becaed54835c0f))

#### `oidc_linux` - `v0.5.0+4`

 - **FIX**(spm,native): SwiftPM layout migration + conformance fixes; fix Android build. ([47f7bd25](https://github.com/Bdaya-Dev/oidc/commit/47f7bd25feb5d4b7a2e3db67165a44ecdf4dae29))

#### `oidc_loopback_listener` - `v0.3.1`

 - **FEAT**(oidc): batch-2 audit hardening (loopback timeout, auth_time/max_age, resilient discovery parse, unverified-userinfo guard). ([d7f5965a](https://github.com/Bdaya-Dev/oidc/commit/d7f5965ac4ecbad0d7a79849e0e89d729a736169))

#### `oidc_web` - `v0.7.1`

 - **FEAT**(oidc_web_core): encrypt secureTokens at rest (AES-GCM via WebCrypto) ([#324](https://github.com/Bdaya-Dev/oidc/issues/324) item 15). ([cf504300](https://github.com/Bdaya-Dev/oidc/commit/cf504300b1922a7f68a82c39ab8dfb42aafe487d))

#### `oidc_windows` - `v0.4.0+4`

 - **FIX**(spm,native): SwiftPM layout migration + conformance fixes; fix Android build. ([47f7bd25](https://github.com/Bdaya-Dev/oidc/commit/47f7bd25feb5d4b7a2e3db67165a44ecdf4dae29))


## 2026-02-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc` - `v0.14.0+2`](#oidc---v01402)
 - [`oidc_android` - `v0.8.0+3`](#oidc_android---v0803)
 - [`oidc_cli` - `v0.0.2+2`](#oidc_cli---v0022)
 - [`oidc_core` - `v0.16.1+1`](#oidc_core---v01611)
 - [`oidc_default_store` - `v0.6.0+2`](#oidc_default_store---v0602)
 - [`oidc_desktop` - `v0.7.0+3`](#oidc_desktop---v0703)
 - [`oidc_flutter_appauth` - `v0.7.0+3`](#oidc_flutter_appauth---v0703)
 - [`oidc_ios` - `v0.8.0+3`](#oidc_ios---v0803)
 - [`oidc_linux` - `v0.5.0+3`](#oidc_linux---v0503)
 - [`oidc_loopback_listener` - `v0.3.0+1`](#oidc_loopback_listener---v0301)
 - [`oidc_macos` - `v0.8.0+3`](#oidc_macos---v0803)
 - [`oidc_platform_interface` - `v0.7.0+3`](#oidc_platform_interface---v0703)
 - [`oidc_web` - `v0.7.0+3`](#oidc_web---v0703)
 - [`oidc_web_core` - `v0.4.0+3`](#oidc_web_core---v0403)
 - [`oidc_windows` - `v0.4.0+3`](#oidc_windows---v0403)

---

#### `oidc` - `v0.14.0+2`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_android` - `v0.8.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_cli` - `v0.0.2+2`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_core` - `v0.16.1+1`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_default_store` - `v0.6.0+2`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_desktop` - `v0.7.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_flutter_appauth` - `v0.7.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_ios` - `v0.8.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_linux` - `v0.5.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_loopback_listener` - `v0.3.0+1`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_macos` - `v0.8.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_platform_interface` - `v0.7.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_web` - `v0.7.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_web_core` - `v0.4.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

#### `oidc_windows` - `v0.4.0+3`

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))


## 2026-02-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc_core` - `v0.16.1`](#oidc_core---v0161)
 - [`oidc` - `v0.14.0+1`](#oidc---v01401)
 - [`oidc_android` - `v0.8.0+2`](#oidc_android---v0802)
 - [`oidc_cli` - `v0.0.2+1`](#oidc_cli---v0021)
 - [`oidc_default_store` - `v0.6.0+1`](#oidc_default_store---v0601)
 - [`oidc_desktop` - `v0.7.0+2`](#oidc_desktop---v0702)
 - [`oidc_flutter_appauth` - `v0.7.0+2`](#oidc_flutter_appauth---v0702)
 - [`oidc_ios` - `v0.8.0+2`](#oidc_ios---v0802)
 - [`oidc_linux` - `v0.5.0+2`](#oidc_linux---v0502)
 - [`oidc_macos` - `v0.8.0+2`](#oidc_macos---v0802)
 - [`oidc_platform_interface` - `v0.7.0+2`](#oidc_platform_interface---v0702)
 - [`oidc_web` - `v0.7.0+2`](#oidc_web---v0702)
 - [`oidc_web_core` - `v0.4.0+2`](#oidc_web_core---v0402)
 - [`oidc_windows` - `v0.4.0+2`](#oidc_windows---v0402)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc` - `v0.14.0+1`
 - `oidc_android` - `v0.8.0+2`
 - `oidc_cli` - `v0.0.2+1`
 - `oidc_default_store` - `v0.6.0+1`
 - `oidc_desktop` - `v0.7.0+2`
 - `oidc_flutter_appauth` - `v0.7.0+2`
 - `oidc_ios` - `v0.8.0+2`
 - `oidc_linux` - `v0.5.0+2`
 - `oidc_macos` - `v0.8.0+2`
 - `oidc_platform_interface` - `v0.7.0+2`
 - `oidc_web` - `v0.7.0+2`
 - `oidc_web_core` - `v0.4.0+2`
 - `oidc_windows` - `v0.4.0+2`

---

#### `oidc_core` - `v0.16.1`

 - **FEAT**(oidc_core): add extraTokenHeaders parameter to loginPassword. ([e00c753b](https://github.com/Bdaya-Dev/oidc/commit/e00c753be7f774b23b8a585c590df8936deaaf97))


## 2025-12-31

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.14.0`](#oidc---v0140)
 - [`oidc_core` - `v0.16.0`](#oidc_core---v0160)
 - [`oidc_default_store` - `v0.6.0`](#oidc_default_store---v060)

Packages with other changes:

 - [`oidc_cli` - `v0.0.2`](#oidc_cli---v002)
 - [`oidc_web_core` - `v0.4.0+1`](#oidc_web_core---v0401)
 - [`oidc_android` - `v0.8.0+1`](#oidc_android---v0801)
 - [`oidc_desktop` - `v0.7.0+1`](#oidc_desktop---v0701)
 - [`oidc_flutter_appauth` - `v0.7.0+1`](#oidc_flutter_appauth---v0701)
 - [`oidc_ios` - `v0.8.0+1`](#oidc_ios---v0801)
 - [`oidc_linux` - `v0.5.0+1`](#oidc_linux---v0501)
 - [`oidc_macos` - `v0.8.0+1`](#oidc_macos---v0801)
 - [`oidc_platform_interface` - `v0.7.0+1`](#oidc_platform_interface---v0701)
 - [`oidc_web` - `v0.7.0+1`](#oidc_web---v0701)
 - [`oidc_windows` - `v0.4.0+1`](#oidc_windows---v0401)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_android` - `v0.8.0+1`
 - `oidc_desktop` - `v0.7.0+1`
 - `oidc_flutter_appauth` - `v0.7.0+1`
 - `oidc_ios` - `v0.8.0+1`
 - `oidc_linux` - `v0.5.0+1`
 - `oidc_macos` - `v0.8.0+1`
 - `oidc_platform_interface` - `v0.7.0+1`
 - `oidc_web` - `v0.7.0+1`
 - `oidc_windows` - `v0.4.0+1`

---

#### `oidc` - `v0.14.0`

 - **FEAT**: improve offline mode integration tests with app startup handling. ([18a586c9](https://github.com/Bdaya-Dev/oidc/commit/18a586c933ddfdbf416510e95c63281d3401bedc))
 - **FEAT**: update dependencies and enhance offline mode test handling. ([a57d6490](https://github.com/Bdaya-Dev/oidc/commit/a57d64906bef50ac362bea16045ea6ba98f7b3f0))
 - **FEAT**: enhance offline mode handling in tests and user manager. ([e0cae79a](https://github.com/Bdaya-Dev/oidc/commit/e0cae79adf3fa8ccf18a530dbdda7cc339a75c0d))
 - **BREAKING** **FEAT**(oidc_default_store): use flutter_secure_storage. ([a9441511](https://github.com/Bdaya-Dev/oidc/commit/a9441511a9f27aa742cde2459b0654541b0aa356))
 - **BREAKING** **FEAT**: Add offline mode events and error handling. ([7479fd15](https://github.com/Bdaya-Dev/oidc/commit/7479fd15cf0029e9b865333709a98363b5119d64))

#### `oidc_core` - `v0.16.0`

 - **REFACTOR**: remove unnecessary @protected annotations from offline mode tracking variables. ([56da9bab](https://github.com/Bdaya-Dev/oidc/commit/56da9bab4d555c8134d68c7e0151e7fe6d3753be))
 - **FEAT**: update copy_with_extension and copy_with_extension_gen dependencies to support version range. ([3569919e](https://github.com/Bdaya-Dev/oidc/commit/3569919ecd6e7575b792d5c3a4e7c503265fc456))
 - **FEAT**: update dependencies and adjust test configurations for improved compatibility. ([18fef073](https://github.com/Bdaya-Dev/oidc/commit/18fef073f4a66e3e9dda7f73e756992ecd47c587))
 - **FEAT**: update dependencies and enhance offline mode test handling. ([a57d6490](https://github.com/Bdaya-Dev/oidc/commit/a57d64906bef50ac362bea16045ea6ba98f7b3f0))
 - **FEAT**: enhance offline mode handling in tests and user manager. ([e0cae79a](https://github.com/Bdaya-Dev/oidc/commit/e0cae79adf3fa8ccf18a530dbdda7cc339a75c0d))
 - **BREAKING** **FEAT**: Add offline mode events and error handling. ([7479fd15](https://github.com/Bdaya-Dev/oidc/commit/7479fd15cf0029e9b865333709a98363b5119d64))

#### `oidc_default_store` - `v0.6.0`

 - **BREAKING** **FEAT**(oidc_default_store): use flutter_secure_storage. ([a9441511](https://github.com/Bdaya-Dev/oidc/commit/a9441511a9f27aa742cde2459b0654541b0aa356))
 - **BREAKING** **FEAT**: Add offline mode events and error handling. ([7479fd15](https://github.com/Bdaya-Dev/oidc/commit/7479fd15cf0029e9b865333709a98363b5119d64))

#### `oidc_cli` - `v0.0.2`

 - **FIX**(oidc_cli): relax build_runner to avoid Flutter SDK pin conflicts. ([b8697530](https://github.com/Bdaya-Dev/oidc/commit/b86975307bde79bd00ba4b0ddacc558a875ed2f8))
 - **FEAT**(oidc_cli): add provider-agnostic CLI package. ([2598ba4f](https://github.com/Bdaya-Dev/oidc/commit/2598ba4ffa0882fed971b7ecd44c1516bf7bef55))

#### `oidc_web_core` - `v0.4.0+1`

 - **FIX**(oidc_web_core): use isA() for JS interop checks. ([724c9a2a](https://github.com/Bdaya-Dev/oidc/commit/724c9a2a0ce9792653c58d17ec5f4122750278f3))


## 2025-10-10

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.13.0`](#oidc---v0130)
 - [`oidc_android` - `v0.8.0`](#oidc_android---v080)
 - [`oidc_core` - `v0.15.0`](#oidc_core---v0150)
 - [`oidc_default_store` - `v0.5.0`](#oidc_default_store---v050)
 - [`oidc_desktop` - `v0.7.0`](#oidc_desktop---v070)
 - [`oidc_flutter_appauth` - `v0.7.0`](#oidc_flutter_appauth---v070)
 - [`oidc_ios` - `v0.8.0`](#oidc_ios---v080)
 - [`oidc_linux` - `v0.5.0`](#oidc_linux---v050)
 - [`oidc_loopback_listener` - `v0.3.0`](#oidc_loopback_listener---v030)
 - [`oidc_macos` - `v0.8.0`](#oidc_macos---v080)
 - [`oidc_platform_interface` - `v0.7.0`](#oidc_platform_interface---v070)
 - [`oidc_web` - `v0.7.0`](#oidc_web---v070)
 - [`oidc_web_core` - `v0.4.0`](#oidc_web_core---v040)
 - [`oidc_windows` - `v0.4.0`](#oidc_windows---v040)

Packages with other changes:

 - There are no other changes in this release.

---

#### `oidc` - `v0.13.0`

 - **FEAT**: add OIDC conformance test suite with API client and test runner. ([a651a7d8](https://github.com/Bdaya-Dev/oidc/commit/a651a7d814a424683d141fcc66156e5d17112baa))
 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FIX**: migrate to simple_secure_storage ([#270](https://github.com/Bdaya-Dev/oidc/issues/270)). ([723560a7](https://github.com/Bdaya-Dev/oidc/commit/723560a7e7d212290205724d7af6799f217ab778))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_android` - `v0.8.0`

 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_core` - `v0.15.0`

 - **FIX**: refactor oidcExecuteHook to handle request and response modifications. ([806c6411](https://github.com/Bdaya-Dev/oidc/commit/806c641166c0634716fdd58f43f10d187f3defe4))
 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_default_store` - `v0.5.0`

 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FIX**: migrate to simple_secure_storage ([#270](https://github.com/Bdaya-Dev/oidc/issues/270)). ([723560a7](https://github.com/Bdaya-Dev/oidc/commit/723560a7e7d212290205724d7af6799f217ab778))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_desktop` - `v0.7.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_flutter_appauth` - `v0.7.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_ios` - `v0.8.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_linux` - `v0.5.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_loopback_listener` - `v0.3.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_macos` - `v0.8.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_platform_interface` - `v0.7.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_web` - `v0.7.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_web_core` - `v0.4.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

#### `oidc_windows` - `v0.4.0`

 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))


## 2025-06-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc` - `v0.12.1+2`](#oidc---v01212)
 - [`oidc_android` - `v0.7.0+5`](#oidc_android---v0705)
 - [`oidc_core` - `v0.14.2+1`](#oidc_core---v01421)
 - [`oidc_default_store` - `v0.4.0+3`](#oidc_default_store---v0403)
 - [`oidc_desktop` - `v0.6.1+2`](#oidc_desktop---v0612)
 - [`oidc_flutter_appauth` - `v0.6.0+5`](#oidc_flutter_appauth---v0605)
 - [`oidc_ios` - `v0.7.0+5`](#oidc_ios---v0705)
 - [`oidc_linux` - `v0.4.1+2`](#oidc_linux---v0412)
 - [`oidc_loopback_listener` - `v0.2.0+1`](#oidc_loopback_listener---v0201)
 - [`oidc_macos` - `v0.7.0+5`](#oidc_macos---v0705)
 - [`oidc_platform_interface` - `v0.6.0+9`](#oidc_platform_interface---v0609)
 - [`oidc_web` - `v0.6.0+9`](#oidc_web---v0609)
 - [`oidc_web_core` - `v0.3.1+3`](#oidc_web_core---v0313)
 - [`oidc_windows` - `v0.3.1+14`](#oidc_windows---v03114)

---

#### `oidc` - `v0.12.1+2`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_android` - `v0.7.0+5`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_core` - `v0.14.2+1`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_default_store` - `v0.4.0+3`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_desktop` - `v0.6.1+2`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_flutter_appauth` - `v0.6.0+5`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_ios` - `v0.7.0+5`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_linux` - `v0.4.1+2`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_loopback_listener` - `v0.2.0+1`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_macos` - `v0.7.0+5`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_platform_interface` - `v0.6.0+9`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_web` - `v0.6.0+9`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_web_core` - `v0.3.1+3`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

#### `oidc_windows` - `v0.3.1+14`

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))


## 2025-06-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc_core` - `v0.14.2`](#oidc_core---v0142)
 - [`oidc_platform_interface` - `v0.6.0+8`](#oidc_platform_interface---v0608)
 - [`oidc_desktop` - `v0.6.1+1`](#oidc_desktop---v0611)
 - [`oidc_ios` - `v0.7.0+4`](#oidc_ios---v0704)
 - [`oidc_flutter_appauth` - `v0.6.0+4`](#oidc_flutter_appauth---v0604)
 - [`oidc_macos` - `v0.7.0+4`](#oidc_macos---v0704)
 - [`oidc_web` - `v0.6.0+8`](#oidc_web---v0608)
 - [`oidc_android` - `v0.7.0+4`](#oidc_android---v0704)
 - [`oidc_default_store` - `v0.4.0+2`](#oidc_default_store---v0402)
 - [`oidc_linux` - `v0.4.1+1`](#oidc_linux---v0411)
 - [`oidc` - `v0.12.1+1`](#oidc---v01211)
 - [`oidc_windows` - `v0.3.1+13`](#oidc_windows---v03113)
 - [`oidc_web_core` - `v0.3.1+2`](#oidc_web_core---v0312)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+8`
 - `oidc_desktop` - `v0.6.1+1`
 - `oidc_ios` - `v0.7.0+4`
 - `oidc_flutter_appauth` - `v0.6.0+4`
 - `oidc_macos` - `v0.7.0+4`
 - `oidc_web` - `v0.6.0+8`
 - `oidc_android` - `v0.7.0+4`
 - `oidc_default_store` - `v0.4.0+2`
 - `oidc_linux` - `v0.4.1+1`
 - `oidc` - `v0.12.1+1`
 - `oidc_windows` - `v0.3.1+13`
 - `oidc_web_core` - `v0.3.1+2`

---

#### `oidc_core` - `v0.14.2`

 - **REFACTOR**: remove unnecessary library declaration and test annotation from device_authorization_test.dart. ([a8886cfe](https://github.com/Bdaya-Dev/oidc/commit/a8886cfe5c431612be2e3b7dd1db98db53dd6356))
 - **FEAT**: add token revocation methods to OidcUserManager. ([4850788f](https://github.com/Bdaya-Dev/oidc/commit/4850788f72f759479c67b16776ff4c43bc3f6b47))
 - **FEAT**: add token revocation support with request and response models. ([a6b635f0](https://github.com/Bdaya-Dev/oidc/commit/a6b635f03659f486bebfe3c53d7df0a26e3a5b4c))


## 2025-06-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc` - `v0.12.1`](#oidc---v0121)
 - [`oidc_core` - `v0.14.1`](#oidc_core---v0141)
 - [`oidc_desktop` - `v0.6.1`](#oidc_desktop---v061)
 - [`oidc_linux` - `v0.4.1`](#oidc_linux---v041)
 - [`oidc_android` - `v0.7.0+3`](#oidc_android---v0703)
 - [`oidc_default_store` - `v0.4.0+1`](#oidc_default_store---v0401)
 - [`oidc_ios` - `v0.7.0+3`](#oidc_ios---v0703)
 - [`oidc_flutter_appauth` - `v0.6.0+3`](#oidc_flutter_appauth---v0603)
 - [`oidc_macos` - `v0.7.0+3`](#oidc_macos---v0703)
 - [`oidc_platform_interface` - `v0.6.0+7`](#oidc_platform_interface---v0607)
 - [`oidc_web_core` - `v0.3.1+1`](#oidc_web_core---v0311)
 - [`oidc_web` - `v0.6.0+7`](#oidc_web---v0607)
 - [`oidc_windows` - `v0.3.1+12`](#oidc_windows---v03112)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_android` - `v0.7.0+3`
 - `oidc_default_store` - `v0.4.0+1`
 - `oidc_ios` - `v0.7.0+3`
 - `oidc_flutter_appauth` - `v0.6.0+3`
 - `oidc_macos` - `v0.7.0+3`
 - `oidc_platform_interface` - `v0.6.0+7`
 - `oidc_web_core` - `v0.3.1+1`
 - `oidc_web` - `v0.6.0+7`
 - `oidc_windows` - `v0.3.1+12`

---

#### `oidc` - `v0.12.1`

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

#### `oidc_core` - `v0.14.1`

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

#### `oidc_desktop` - `v0.6.1`

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

#### `oidc_linux` - `v0.4.1`

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-06-12

### Changes

---

Packages with breaking changes:

 - [`oidc_linux` - `v0.4.0`](#oidc_linux---v040)

Packages with other changes:

 - [`oidc` - `v0.12.0`](#oidc---v0120)
 - [`oidc_core` - `v0.14.0`](#oidc_core---v0140)
 - [`oidc_default_store` - `v0.4.0`](#oidc_default_store---v040)
 - [`oidc_desktop` - `v0.6.0`](#oidc_desktop---v060)
 - [`oidc_web_core` - `v0.3.1`](#oidc_web_core---v031)
 - [`oidc_android` - `v0.7.0+2`](#oidc_android---v0702)
 - [`oidc_flutter_appauth` - `v0.6.0+2`](#oidc_flutter_appauth---v0602)
 - [`oidc_ios` - `v0.7.0+2`](#oidc_ios---v0702)
 - [`oidc_macos` - `v0.7.0+2`](#oidc_macos---v0702)
 - [`oidc_platform_interface` - `v0.6.0+6`](#oidc_platform_interface---v0606)
 - [`oidc_web` - `v0.6.0+6`](#oidc_web---v0606)
 - [`oidc_windows` - `v0.3.1+11`](#oidc_windows---v03111)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_android` - `v0.7.0+2`
 - `oidc_flutter_appauth` - `v0.6.0+2`
 - `oidc_ios` - `v0.7.0+2`
 - `oidc_macos` - `v0.7.0+2`
 - `oidc_platform_interface` - `v0.6.0+6`
 - `oidc_web` - `v0.6.0+6`
 - `oidc_windows` - `v0.3.1+11`

---

#### `oidc_linux` - `v0.4.0`

 - **DOCS**: Document multi-manager support. ([0b6090ad](https://github.com/Bdaya-Dev/oidc/commit/0b6090ad266838bd39d139201b68d44351a5ab7c))

#### `oidc` - `v0.12.0`

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

#### `oidc_core` - `v0.14.0`

 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))
 - **FEAT**: enhance OIDC conformance token handling in integration tests and user manager. ([1947c29f](https://github.com/Bdaya-Dev/oidc/commit/1947c29fbd9ab20d0bd62065f697dac2fba1f682))
 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

#### `oidc_default_store` - `v0.4.0`

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

#### `oidc_desktop` - `v0.6.0`

 - **FIX**: enable headless mode for Chrome in default Linux applications setup. ([dda1c2dc](https://github.com/Bdaya-Dev/oidc/commit/dda1c2dc9f43a034d553eb043294b80e000f82f3))
 - **FEAT**: implement custom URL launcher for OidcLinux platform. ([11d901fe](https://github.com/Bdaya-Dev/oidc/commit/11d901fede70dd8aaa9cb03df18c392142895ccb))
 - **FEAT**: improve auth URL launching with enhanced error handling and logging. ([58f3881a](https://github.com/Bdaya-Dev/oidc/commit/58f3881a3e629896acf933862bb1e6a131bb6b4e))

#### `oidc_web_core` - `v0.3.1`

 - **FEAT**: Enhance OIDC store with manager ID support. ([56f42f2d](https://github.com/Bdaya-Dev/oidc/commit/56f42f2d67fd97c587611870e412de8cb357c4e4))

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-06-06

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.11.0`](#oidc---v0110)
 - [`oidc_core` - `v0.13.0`](#oidc_core---v0130)
 - [`oidc_default_store` - `v0.3.0`](#oidc_default_store---v030)

Packages with other changes:

 - [`oidc_web_core` - `v0.3.0+5`](#oidc_web_core---v0305)
 - [`oidc_desktop` - `v0.5.0+5`](#oidc_desktop---v0505)
 - [`oidc_ios` - `v0.7.0+1`](#oidc_ios---v0701)
 - [`oidc_platform_interface` - `v0.6.0+5`](#oidc_platform_interface---v0605)
 - [`oidc_macos` - `v0.7.0+1`](#oidc_macos---v0701)
 - [`oidc_android` - `v0.7.0+1`](#oidc_android---v0701)
 - [`oidc_web` - `v0.6.0+5`](#oidc_web---v0605)
 - [`oidc_linux` - `v0.3.0+16`](#oidc_linux---v03016)
 - [`oidc_flutter_appauth` - `v0.6.0+1`](#oidc_flutter_appauth---v0601)
 - [`oidc_windows` - `v0.3.1+10`](#oidc_windows---v03110)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_web_core` - `v0.3.0+5`
 - `oidc_desktop` - `v0.5.0+5`
 - `oidc_ios` - `v0.7.0+1`
 - `oidc_platform_interface` - `v0.6.0+5`
 - `oidc_macos` - `v0.7.0+1`
 - `oidc_android` - `v0.7.0+1`
 - `oidc_web` - `v0.6.0+5`
 - `oidc_linux` - `v0.3.0+16`
 - `oidc_flutter_appauth` - `v0.6.0+1`
 - `oidc_windows` - `v0.3.1+10`

---

#### `oidc` - `v0.11.0`

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

#### `oidc_core` - `v0.13.0`

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

#### `oidc_default_store` - `v0.3.0`

 - **FIX**: oidc_default_store init() loads the shared preferences again and does not check if already given in ctor [#226](https://github.com/Bdaya-Dev/oidc/issues/226). ([111b0a98](https://github.com/Bdaya-Dev/oidc/commit/111b0a98e2eb57b32ab3c9ace3d9b543a2683f34))
 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))


## 2025-04-16

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.10.0`](#oidc---v0100)
 - [`oidc_android` - `v0.7.0`](#oidc_android---v070)
 - [`oidc_core` - `v0.12.0`](#oidc_core---v0120)
 - [`oidc_flutter_appauth` - `v0.6.0`](#oidc_flutter_appauth---v060)
 - [`oidc_ios` - `v0.7.0`](#oidc_ios---v070)
 - [`oidc_macos` - `v0.7.0`](#oidc_macos---v070)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+15`](#oidc_default_store---v02015)
 - [`oidc_platform_interface` - `v0.6.0+4`](#oidc_platform_interface---v0604)
 - [`oidc_web_core` - `v0.3.0+4`](#oidc_web_core---v0304)
 - [`oidc_linux` - `v0.3.0+15`](#oidc_linux---v03015)
 - [`oidc_windows` - `v0.3.1+9`](#oidc_windows---v0319)
 - [`oidc_desktop` - `v0.5.0+4`](#oidc_desktop---v0504)
 - [`oidc_web` - `v0.6.0+4`](#oidc_web---v0604)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_linux` - `v0.3.0+15`
 - `oidc_windows` - `v0.3.1+9`
 - `oidc_desktop` - `v0.5.0+4`
 - `oidc_web` - `v0.6.0+4`

---

#### `oidc` - `v0.10.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_android` - `v0.7.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_core` - `v0.12.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_flutter_appauth` - `v0.6.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_ios` - `v0.7.0`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_macos` - `v0.7.0`

 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

#### `oidc_default_store` - `v0.2.0+15`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

#### `oidc_platform_interface` - `v0.6.0+4`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))

#### `oidc_web_core` - `v0.3.0+4`

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))


## 2025-04-13

### Changes

---

Packages with breaking changes:

 - [`oidc_core` - `v0.11.0`](#oidc_core---v0110)

Packages with other changes:

 - [`oidc_platform_interface` - `v0.6.0+3`](#oidc_platform_interface---v0603)
 - [`oidc_android` - `v0.6.0+3`](#oidc_android---v0603)
 - [`oidc_linux` - `v0.3.0+14`](#oidc_linux---v03014)
 - [`oidc_ios` - `v0.6.0+3`](#oidc_ios---v0603)
 - [`oidc_windows` - `v0.3.1+8`](#oidc_windows---v0318)
 - [`oidc_flutter_appauth` - `v0.5.0+3`](#oidc_flutter_appauth---v0503)
 - [`oidc_macos` - `v0.6.0+3`](#oidc_macos---v0603)
 - [`oidc_desktop` - `v0.5.0+3`](#oidc_desktop---v0503)
 - [`oidc_default_store` - `v0.2.0+14`](#oidc_default_store---v02014)
 - [`oidc_web_core` - `v0.3.0+3`](#oidc_web_core---v0303)
 - [`oidc_web` - `v0.6.0+3`](#oidc_web---v0603)
 - [`oidc` - `v0.9.0+3`](#oidc---v0903)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+3`
 - `oidc_android` - `v0.6.0+3`
 - `oidc_linux` - `v0.3.0+14`
 - `oidc_ios` - `v0.6.0+3`
 - `oidc_windows` - `v0.3.1+8`
 - `oidc_flutter_appauth` - `v0.5.0+3`
 - `oidc_macos` - `v0.6.0+3`
 - `oidc_desktop` - `v0.5.0+3`
 - `oidc_default_store` - `v0.2.0+14`
 - `oidc_web_core` - `v0.3.0+3`
 - `oidc_web` - `v0.6.0+3`
 - `oidc` - `v0.9.0+3`

---

#### `oidc_core` - `v0.11.0`

 - **FIX**: set idTokenHint null if no postLogoutRedirectUri set ([#192](https://github.com/Bdaya-Dev/oidc/issues/192)). ([bcf47cbd](https://github.com/Bdaya-Dev/oidc/commit/bcf47cbde8c36619ce89055b296fd162eb3c30f9))
 - **BREAKING** **CHORE**: regenerate files with new json serializer. ([35523a61](https://github.com/Bdaya-Dev/oidc/commit/35523a617753d3058e7065be79b2a4cf2f322199))


## 2025-04-12

### Changes

---

Packages with breaking changes:

 - [`oidc_core` - `v0.10.0`](#oidc_core---v0100)

Packages with other changes:

 - [`oidc_platform_interface` - `v0.6.0+2`](#oidc_platform_interface---v0602)
 - [`oidc_linux` - `v0.3.0+13`](#oidc_linux---v03013)
 - [`oidc_android` - `v0.6.0+2`](#oidc_android---v0602)
 - [`oidc_ios` - `v0.6.0+2`](#oidc_ios---v0602)
 - [`oidc_windows` - `v0.3.1+7`](#oidc_windows---v0317)
 - [`oidc_flutter_appauth` - `v0.5.0+2`](#oidc_flutter_appauth---v0502)
 - [`oidc_macos` - `v0.6.0+2`](#oidc_macos---v0602)
 - [`oidc_desktop` - `v0.5.0+2`](#oidc_desktop---v0502)
 - [`oidc_web_core` - `v0.3.0+2`](#oidc_web_core---v0302)
 - [`oidc_default_store` - `v0.2.0+13`](#oidc_default_store---v02013)
 - [`oidc_web` - `v0.6.0+2`](#oidc_web---v0602)
 - [`oidc` - `v0.9.0+2`](#oidc---v0902)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_platform_interface` - `v0.6.0+2`
 - `oidc_linux` - `v0.3.0+13`
 - `oidc_android` - `v0.6.0+2`
 - `oidc_ios` - `v0.6.0+2`
 - `oidc_windows` - `v0.3.1+7`
 - `oidc_flutter_appauth` - `v0.5.0+2`
 - `oidc_macos` - `v0.6.0+2`
 - `oidc_desktop` - `v0.5.0+2`
 - `oidc_web_core` - `v0.3.0+2`
 - `oidc_default_store` - `v0.2.0+13`
 - `oidc_web` - `v0.6.0+2`
 - `oidc` - `v0.9.0+2`

---

#### `oidc_core` - `v0.10.0`

 - **BREAKING** **FEAT**: minimal implement nonce hashing  ([#172](https://github.com/Bdaya-Dev/oidc/issues/172)). ([d4daf387](https://github.com/Bdaya-Dev/oidc/commit/d4daf387b660332513fcb13dcd1e855098c566ee))


## 2024-11-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`oidc_core` - `v0.9.1`](#oidc_core---v091)
 - [`oidc` - `v0.9.0+1`](#oidc---v0901)
 - [`oidc_flutter_appauth` - `v0.5.0+1`](#oidc_flutter_appauth---v0501)
 - [`oidc_desktop` - `v0.5.0+1`](#oidc_desktop---v0501)
 - [`oidc_ios` - `v0.6.0+1`](#oidc_ios---v0601)
 - [`oidc_web` - `v0.6.0+1`](#oidc_web---v0601)
 - [`oidc_android` - `v0.6.0+1`](#oidc_android---v0601)
 - [`oidc_default_store` - `v0.2.0+12`](#oidc_default_store---v02012)
 - [`oidc_platform_interface` - `v0.6.0+1`](#oidc_platform_interface---v0601)
 - [`oidc_windows` - `v0.3.1+6`](#oidc_windows---v0316)
 - [`oidc_linux` - `v0.3.0+12`](#oidc_linux---v03012)
 - [`oidc_web_core` - `v0.3.0+1`](#oidc_web_core---v0301)
 - [`oidc_macos` - `v0.6.0+1`](#oidc_macos---v0601)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc` - `v0.9.0+1`
 - `oidc_flutter_appauth` - `v0.5.0+1`
 - `oidc_desktop` - `v0.5.0+1`
 - `oidc_ios` - `v0.6.0+1`
 - `oidc_web` - `v0.6.0+1`
 - `oidc_android` - `v0.6.0+1`
 - `oidc_default_store` - `v0.2.0+12`
 - `oidc_platform_interface` - `v0.6.0+1`
 - `oidc_windows` - `v0.3.1+6`
 - `oidc_linux` - `v0.3.0+12`
 - `oidc_web_core` - `v0.3.0+1`
 - `oidc_macos` - `v0.6.0+1`

---

#### `oidc_core` - `v0.9.1`

 - **FEAT**: Added `OidcTokenExpiredEvent` and `OidcTokenExpiringEvent` ([#91](https://github.com/Bdaya-Dev/oidc/issues/91)). ([85ba41ce](https://github.com/Bdaya-Dev/oidc/commit/85ba41cef689b852e102a65ec6550580489fb4bc))


## 2024-11-24

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.9.0`](#oidc---v090)
 - [`oidc_android` - `v0.6.0`](#oidc_android---v060)
 - [`oidc_core` - `v0.9.0`](#oidc_core---v090)
 - [`oidc_desktop` - `v0.5.0`](#oidc_desktop---v050)
 - [`oidc_flutter_appauth` - `v0.5.0`](#oidc_flutter_appauth---v050)
 - [`oidc_ios` - `v0.6.0`](#oidc_ios---v060)
 - [`oidc_macos` - `v0.6.0`](#oidc_macos---v060)
 - [`oidc_platform_interface` - `v0.6.0`](#oidc_platform_interface---v060)
 - [`oidc_web` - `v0.6.0`](#oidc_web---v060)
 - [`oidc_web_core` - `v0.3.0`](#oidc_web_core---v030)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+11`](#oidc_default_store---v02011)
 - [`oidc_windows` - `v0.3.1+5`](#oidc_windows---v0315)
 - [`oidc_linux` - `v0.3.0+11`](#oidc_linux---v03011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_default_store` - `v0.2.0+11`
 - `oidc_windows` - `v0.3.1+5`
 - `oidc_linux` - `v0.3.0+11`

---

#### `oidc` - `v0.9.0`

 - **FIX**: oidc not passing options properly. ([b2fdf5fe](https://github.com/Bdaya-Dev/oidc/commit/b2fdf5fe38787e0b1d89c192545accefa99f9a7d))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_android` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_core` - `v0.9.0`

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_desktop` - `v0.5.0`

 - **FIX**: typo in oidc_desktop. ([a6f67bd8](https://github.com/Bdaya-Dev/oidc/commit/a6f67bd8dd514bfa397649624272df550737e23e))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_flutter_appauth` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_ios` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_macos` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_platform_interface` - `v0.6.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web` - `v0.6.0`

 - **FEAT**: depend on oidc_web_core. ([f3331a8e](https://github.com/Bdaya-Dev/oidc/commit/f3331a8e2d3e39c5cb8d7728d104e1bb8d8ece75))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web_core` - `v0.3.0`

 - **REVERT**: local version. ([e948477a](https://github.com/Bdaya-Dev/oidc/commit/e948477a7134b36f2cd7f80186632c0a57516afd))
 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))


## 2024-11-24

### Changes

---

Packages with breaking changes:

 - [`oidc` - `v0.8.0`](#oidc---v080)
 - [`oidc_android` - `v0.5.0`](#oidc_android---v050)
 - [`oidc_core` - `v0.8.0`](#oidc_core---v080)
 - [`oidc_desktop` - `v0.4.0`](#oidc_desktop---v040)
 - [`oidc_flutter_appauth` - `v0.4.0`](#oidc_flutter_appauth---v040)
 - [`oidc_ios` - `v0.5.0`](#oidc_ios---v050)
 - [`oidc_macos` - `v0.5.0`](#oidc_macos---v050)
 - [`oidc_platform_interface` - `v0.5.0`](#oidc_platform_interface---v050)
 - [`oidc_web` - `v0.5.0`](#oidc_web---v050)
 - [`oidc_web_core` - `v0.2.0`](#oidc_web_core---v020)

Packages with other changes:

 - [`oidc_default_store` - `v0.2.0+10`](#oidc_default_store---v02010)
 - [`oidc_windows` - `v0.3.1+4`](#oidc_windows---v0314)
 - [`oidc_linux` - `v0.3.0+10`](#oidc_linux---v03010)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `oidc_default_store` - `v0.2.0+10`
 - `oidc_windows` - `v0.3.1+4`
 - `oidc_linux` - `v0.3.0+10`

---

#### `oidc` - `v0.8.0`

 - **FIX**: oidc not passing options properly. ([b2fdf5fe](https://github.com/Bdaya-Dev/oidc/commit/b2fdf5fe38787e0b1d89c192545accefa99f9a7d))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_android` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_core` - `v0.8.0`

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_desktop` - `v0.4.0`

 - **FIX**: typo in oidc_desktop. ([a6f67bd8](https://github.com/Bdaya-Dev/oidc/commit/a6f67bd8dd514bfa397649624272df550737e23e))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_flutter_appauth` - `v0.4.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_ios` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_macos` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_platform_interface` - `v0.5.0`

 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web` - `v0.5.0`

 - **FEAT**: depend on oidc_web_core. ([f3331a8e](https://github.com/Bdaya-Dev/oidc/commit/f3331a8e2d3e39c5cb8d7728d104e1bb8d8ece75))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

#### `oidc_web_core` - `v0.2.0`

 - **FIX**: [#68](https://github.com/Bdaya-Dev/oidc/issues/68). ([1b30c879](https://github.com/Bdaya-Dev/oidc/commit/1b30c879560bac4bdd02ee8d7771d1ce1764a074))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **DOCS**: update oidc_web_core readme. ([7a2a3f12](https://github.com/Bdaya-Dev/oidc/commit/7a2a3f123102316c81bfe702351bea01ec925e61))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

