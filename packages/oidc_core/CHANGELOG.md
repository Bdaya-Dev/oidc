## 1.0.1

 - **FIX**(oidc_core): honor expectedIssuer in validateUser (Entra multi-tenant) ([#389](https://github.com/Bdaya-Dev/oidc/issues/389)). ([4abc4e74](https://github.com/Bdaya-Dev/oidc/commit/4abc4e74282968cdf51ccccedfe99bff8f678e86))
 - **FIX**(oidc_core): send dpop_jkt on the direct authorization request ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)) ([#391](https://github.com/Bdaya-Dev/oidc/issues/391)). ([c5e7420a](https://github.com/Bdaya-Dev/oidc/commit/c5e7420a1db47bd00217e5f9426666cc965c8b4f))

## 1.0.0

> Note: This release has breaking changes.

 - **FIX**(oidc_core): also ungate AUTO refresh-on-expiry from grant_types_supported ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([7e543b98](https://github.com/Bdaya-Dev/oidc/commit/7e543b98262334b17ebadce8c5761a6170a86025))
 - **FIX**: update packages/oidc_core/lib/src/managers/user_manager_base.dart. ([d62828c0](https://github.com/Bdaya-Dev/oidc/commit/d62828c06efc3fc9257d54a8818f189eb7e99b22))
 - **FIX**(oidc_core): kid-miss refetch on the cacheStore-less verification path. ([8eecbe28](https://github.com/Bdaya-Dev/oidc/commit/8eecbe28a99e5b0b0eba31c034ca8256c894d79f))
 - **FIX**(oidc_core): refetch JWKS on unknown kid with per-issuer cooldown. ([badeba7b](https://github.com/Bdaya-Dev/oidc/commit/badeba7bcfdea7c22f6f5b0707894b5dd5b741dd))
 - **FIX**(oidc_core): single-location client auth on token exchange and introspection (RFC 6749 §2.3). ([36f67e39](https://github.com/Bdaya-Dev/oidc/commit/36f67e39f8b02a614059325254204c047def938e))
 - **FIX**(oidc_core): validate RFC 9207 iss on authorization error responses. ([5916b65e](https://github.com/Bdaya-Dev/oidc/commit/5916b65e4a7ac58dae13ac5990d44e4b2f15b056))
 - **FIX**(oidc_core): always send id_token_hint on RP-initiated logout. ([434af9ab](https://github.com/Bdaya-Dev/oidc/commit/434af9ab0a02e55c189bceacc72767cac7076ede))
 - **FIX**(oidc_core): reject UserInfo responses missing sub (OIDC Core §5.3.2). ([f133c5b2](https://github.com/Bdaya-Dev/oidc/commit/f133c5b2a44dfd684379945244e70293e2663ac9))
 - **FIX**(oidc_core): send client auth in exactly one location on refresh (RFC 6749 §2.3). ([f6bf79a8](https://github.com/Bdaya-Dev/oidc/commit/f6bf79a866793750961d902dbdf87a5e1423e1fa))
 - **FIX**(oidc_core): percent-encode client_secret_basic credentials (RFC 6749 §2.3.1). ([94964778](https://github.com/Bdaya-Dev/oidc/commit/949647783dcb05c7d1658ce47e19c88b4a461e1f))
 - **FIX**(oidc_darwin): implement flowTimeoutSeconds for the Apple ASWebAuthenticationSession flow. ([482f0186](https://github.com/Bdaya-Dev/oidc/commit/482f0186b8cdb37d309118de187e1c8496555d9a))
 - **FIX**: handle whitespace-only payloads. ([2751b841](https://github.com/Bdaya-Dev/oidc/commit/2751b841c8cef1f06c9e4ced7cf6df2dc5a6fd75))
 - **FIX**(oidc_core): strip terminating slash when building well-known URL ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([975d446f](https://github.com/Bdaya-Dev/oidc/commit/975d446f4fa08478e9434463c55c917bbd3a39f8))
 - **FIX**: resolve all four library bugs; drive honest unit coverage to ~95% ([#368](https://github.com/Bdaya-Dev/oidc/issues/368)). ([c86bee17](https://github.com/Bdaya-Dev/oidc/commit/c86bee17189a0a70fee947c685e91a55062b1d35))
 - **FIX**(oidc_core): close 7 P0 spec-audit findings ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([60907e96](https://github.com/Bdaya-Dev/oidc/commit/60907e96f33dce8bf961b26ed43cec20f56e595e))
 - **FIX**: handle refresh responses without id_token. ([4af363be](https://github.com/Bdaya-Dev/oidc/commit/4af363bed630d18394b28af1664f334aca3df8d9))
 - **FIX**(oidc_core): restore web/WASM compatibility for offline error handling. ([0c2e894a](https://github.com/Bdaya-Dev/oidc/commit/0c2e894a232514f0b6bfa1e7c3e8414756f1027d))
 - **FIX**(core): harden DPoP thumbprint + JARM verification (adversarial-review fixes). ([69ac51aa](https://github.com/Bdaya-Dev/oidc/commit/69ac51aa16e602eab00765590fc0f221a0b213dd))
 - **FIX**(core): DPoP — pad short EC coordinates (RFC 7638 jkt correctness). ([bd5568e7](https://github.com/Bdaya-Dev/oidc/commit/bd5568e73650e4ecdd8623141347300cbcef2b93))
 - **FIX**(core): update device-code flow test for the fail-closed JWT default. ([fa333f89](https://github.com/Bdaya-Dev/oidc/commit/fa333f899914ba47fc05bfb312de414cbb1df114))
 - **FIX**: handle empty response. ([03179667](https://github.com/Bdaya-Dev/oidc/commit/031796675c1b27cd8d32a036bd56dfcb9a9fedad))
 - **FIX**(oidc_core): harden ID-token/UserInfo validation (P0 spec-compliance). ([1e7cfee9](https://github.com/Bdaya-Dev/oidc/commit/1e7cfee91f0de9391fea699300cac079f874843e))
 - **FIX**: pre-v1 correctness — certification claim, license, Android queries, honest native option docs. ([3b8ef447](https://github.com/Bdaya-Dev/oidc/commit/3b8ef447f2a1c0af68ec6711c77d435531fb827f))
 - **FEAT**(oidc_core): deferred audit best-practice hardening (alg-pin, signed-userinfo, issuer, back-channel logout). ([7259290d](https://github.com/Bdaya-Dev/oidc/commit/7259290d48db2e5b59299b7c78bb99e97bf325b8))
 - **FEAT**(android): apply typed Custom Tabs options natively (Phase 1). ([10e903eb](https://github.com/Bdaya-Dev/oidc/commit/10e903ebcbdb7fa8cb33c7f2f4d30b58db26d33e))
 - **FEAT**(oidc_core): enforce RFC 9207 iss require-when-advertised + error-path ([#324](https://github.com/Bdaya-Dev/oidc/issues/324)). ([3f324712](https://github.com/Bdaya-Dev/oidc/commit/3f324712f978c0c5af465261f9b9e3f300d6d398))
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
 - **FEAT**(storage): harden token storage at rest (RFC 9700 §4.9.3). ([76111b4a](https://github.com/Bdaya-Dev/oidc/commit/76111b4a1022a140c0b510e088becaed54835c0f))
 - **FEAT**(core): DPoP phase 1b — attach proofs to token-endpoint requests. ([c0207476](https://github.com/Bdaya-Dev/oidc/commit/c0207476c469f1ce14c0b9828af536219325094d))
 - **FEAT**(oidc): batch-2 audit hardening (loopback timeout, auth_time/max_age, resilient discovery parse, unverified-userinfo guard). ([d7f5965a](https://github.com/Bdaya-Dev/oidc/commit/d7f5965ac4ecbad0d7a79849e0e89d729a736169))
 - **FEAT**(core): DPoP (RFC 9449) crypto core — proof builder + key/thumbprint + manager. ([43f566d5](https://github.com/Bdaya-Dev/oidc/commit/43f566d509f6be194ba5f9190f7f8d19dc21ca4d))
 - **FEAT**(oidc_core): batch-3 audit hardening (signed_metadata verify, JWKS cache TTL, implicit/hybrid nonce assert). ([27a7f34d](https://github.com/Bdaya-Dev/oidc/commit/27a7f34d44723489c339b5169a3ad110919a9d6f))
 - **FEAT**(oidc_core): typed logout capability flags on provider metadata. ([74a6613a](https://github.com/Bdaya-Dev/oidc/commit/74a6613af511e1d5ff90e79957d61ed6a62d7ad4))
 - **FEAT**(core): Dynamic Client Registration + management (RFC 7591 / RFC 7592). ([55226655](https://github.com/Bdaya-Dev/oidc/commit/552266557dc0c5a87d3873f92e10240d52c64a4c))
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

## 0.16.1+1

 - **DOCS**: remove logo branding from screenshots. ([2acf65d3](https://github.com/Bdaya-Dev/oidc/commit/2acf65d34fb47c0449653a73373168df3deb1735))

## 0.16.1

 - **FEAT**(oidc_core): add extraTokenHeaders parameter to loginPassword. ([e00c753b](https://github.com/Bdaya-Dev/oidc/commit/e00c753be7f774b23b8a585c590df8936deaaf97))

## 0.16.0

> Note: This release has breaking changes.

 - **REFACTOR**: remove unnecessary @protected annotations from offline mode tracking variables. ([56da9bab](https://github.com/Bdaya-Dev/oidc/commit/56da9bab4d555c8134d68c7e0151e7fe6d3753be))
 - **FEAT**: update copy_with_extension and copy_with_extension_gen dependencies to support version range. ([3569919e](https://github.com/Bdaya-Dev/oidc/commit/3569919ecd6e7575b792d5c3a4e7c503265fc456))
 - **FEAT**: update dependencies and adjust test configurations for improved compatibility. ([18fef073](https://github.com/Bdaya-Dev/oidc/commit/18fef073f4a66e3e9dda7f73e756992ecd47c587))
 - **FEAT**: update dependencies and enhance offline mode test handling. ([a57d6490](https://github.com/Bdaya-Dev/oidc/commit/a57d64906bef50ac362bea16045ea6ba98f7b3f0))
 - **FEAT**: enhance offline mode handling in tests and user manager. ([e0cae79a](https://github.com/Bdaya-Dev/oidc/commit/e0cae79adf3fa8ccf18a530dbdda7cc339a75c0d))
 - **BREAKING** **FEAT**: Add offline mode events and error handling. ([7479fd15](https://github.com/Bdaya-Dev/oidc/commit/7479fd15cf0029e9b865333709a98363b5119d64))

## 0.15.0

> Note: This release has breaking changes.

 - **FIX**: refactor oidcExecuteHook to handle request and response modifications. ([806c6411](https://github.com/Bdaya-Dev/oidc/commit/806c641166c0634716fdd58f43f10d187f3defe4))
 - **BREAKING** **FIX**: hasInit is set to true too early in init() of OidcUserManagerBase ([#275](https://github.com/Bdaya-Dev/oidc/issues/275)). ([d704aa5f](https://github.com/Bdaya-Dev/oidc/commit/d704aa5fe7449051831fc062919712a1c5075a13))
 - **BREAKING** **FEAT**: Support WASM ([#253](https://github.com/Bdaya-Dev/oidc/issues/253)). ([8b2931ef](https://github.com/Bdaya-Dev/oidc/commit/8b2931ef64c7b25609db563e3d14bf37f5504922))

## 0.14.2+1

 - **DOCS**: Add openid certification mark ([#240](https://github.com/Bdaya-Dev/oidc/issues/240)). ([89313199](https://github.com/Bdaya-Dev/oidc/commit/8931319937b9c263abae9ac873433dd6bd5fa637))

## 0.14.2

 - **REFACTOR**: remove unnecessary library declaration and test annotation from device_authorization_test.dart. ([a8886cfe](https://github.com/Bdaya-Dev/oidc/commit/a8886cfe5c431612be2e3b7dd1db98db53dd6356))
 - **FEAT**: add token revocation methods to OidcUserManager. ([4850788f](https://github.com/Bdaya-Dev/oidc/commit/4850788f72f759479c67b16776ff4c43bc3f6b47))
 - **FEAT**: add token revocation support with request and response models. ([a6b635f0](https://github.com/Bdaya-Dev/oidc/commit/a6b635f03659f486bebfe3c53d7df0a26e3a5b4c))

## 0.14.1

 - **FEAT**: update changelogs to reflect breaking changes and new features for multiple OIDC platforms. ([4caca121](https://github.com/Bdaya-Dev/oidc/commit/4caca121f63fd21d71aaffa2730b092fc26a7da5))

## 0.14.0

  - **BREAKING** **FEAT**: Added `launchUrl` parameter to `OidcPlatformSpecificOptions_Native`, to simplify modifying the url launching logic without overriding the manager.
  - **BREAKING** **FEAT**: Added support for multiple managers by adding the `id` property to `OidcUserManagerBase`.
    - Added the `managerId` parameter to:
      - Multiple methods in `OidcStore`.
      - `OidcState`
    - See [#206](https://github.com/Bdaya-Dev/oidc/issues/206) for motivation.
  - **FIX**: Added some missing fields in json serialization.

## 0.13.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: support hooks ([#228](https://github.com/Bdaya-Dev/oidc/issues/228)). ([f2d9d9c6](https://github.com/Bdaya-Dev/oidc/commit/f2d9d9c692e0cf0baac36f186be337ff62e142df))

## 0.12.0

> Note: This release has breaking changes.

 - **REFACTOR**: minor lints and refactors. ([5ab9af70](https://github.com/Bdaya-Dev/oidc/commit/5ab9af70140be2a11f54d62a9d93c9c6edc9e554))
 - **BREAKING** **CHORE**(deps): upgrade flutter_appauth to v9.0.0 ([#199](https://github.com/Bdaya-Dev/oidc/issues/199)). ([f027af34](https://github.com/Bdaya-Dev/oidc/commit/f027af3460a833780cc77ed2cce11f692c7a8ce5))

## 0.11.0

> Note: This release has breaking changes.

 - **FIX**: set idTokenHint null if no postLogoutRedirectUri set ([#192](https://github.com/Bdaya-Dev/oidc/issues/192)). ([bcf47cbd](https://github.com/Bdaya-Dev/oidc/commit/bcf47cbde8c36619ce89055b296fd162eb3c30f9))
 - **BREAKING** **CHORE**: regenerate files with new json serializer. ([35523a61](https://github.com/Bdaya-Dev/oidc/commit/35523a617753d3058e7065be79b2a4cf2f322199))

## 0.10.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: minimal implement nonce hashing  ([#172](https://github.com/Bdaya-Dev/oidc/issues/172)). ([d4daf387](https://github.com/Bdaya-Dev/oidc/commit/d4daf387b660332513fcb13dcd1e855098c566ee))

## 0.9.1

 - **FEAT**: Added `OidcTokenExpiredEvent` and `OidcTokenExpiringEvent` ([#91](https://github.com/Bdaya-Dev/oidc/issues/91)). ([85ba41ce](https://github.com/Bdaya-Dev/oidc/commit/85ba41cef689b852e102a65ec6550580489fb4bc))

## 0.9.0

> Note: This release has breaking changes.

 - **FIX**: expand successful status range to include 300-399 status code to allow for 304 , see. ([717d5330](https://github.com/Bdaya-Dev/oidc/commit/717d5330e54f7e96556f69954c8c164c9fac85d8))
 - **FIX**: improve OidcEndpoints error handling. ([5f15c774](https://github.com/Bdaya-Dev/oidc/commit/5f15c7745e9e01264b3b3fe5af27eaef5a4c7738))
 - **FIX**: update oidc_web_core version. ([2717b23c](https://github.com/Bdaya-Dev/oidc/commit/2717b23c6808502f8121d0ee195edaeec26a5ab5))
 - **FEAT**: support offline auth. ([cced6013](https://github.com/Bdaya-Dev/oidc/commit/cced601362d32ce3b4ac402f78fcc48da10225c6))
 - **FEAT**: add keepUnverifiedTokens and keepExpiredTokens to user manager settings. ([117931bd](https://github.com/Bdaya-Dev/oidc/commit/117931bd580ac04be16bc3e3d39c49c6a0077bb1))
 - **FEAT**: add getIdToken to OidcUserManagerSettings. ([dceabc89](https://github.com/Bdaya-Dev/oidc/commit/dceabc89df5ecdc6cafe54b7411b8208b485b370))
 - **FEAT**: updated oidc_core example. ([676657b1](https://github.com/Bdaya-Dev/oidc/commit/676657b1f12f54d034947d8d85ca34da9c316816))
 - **DOCS**: update changelogs. ([b0ffeb43](https://github.com/Bdaya-Dev/oidc/commit/b0ffeb43744db5a794b948958d8ec935c8eaef32))
 - **BREAKING** **FIX**: Opening in new tab not working reliably in Safari for iOS [#31](https://github.com/Bdaya-Dev/oidc/issues/31). ([2e30028b](https://github.com/Bdaya-Dev/oidc/commit/2e30028b79f7ed1e7835d4656278b022a9c0ec62))

## 0.7.0

> Note: This release has breaking changes.

  - **BREAKING** **DEPS**: update min dart version to 3.4.0
  - **FEAT**: added `OidcUserManagerBase`.     
  - **FIX**: improve `OidcEndpoints` error handling.
  - **DOCS**: updated the [docs website](https://bdaya-dev.github.io/oidc/) with new entries to the added features.

## 0.6.3

 - **DEPS**: Use `jose_plus: ^0.4.4` which uses [package:clock](https://pub.dev/packages/clock) JWT validation to simplify testing.
 - **FEAT**: Added `OidcDateTime` extension which contains `secondsSinceEpoch` and `fromSecondsSinceEpoch` helper methods

## 0.6.2

 - **FIX**: Serialize query parameters.
 - **FIX**: Removed false positive warnings that came from url_launcher

## 0.6.1

 - **FEAT**: Support overriding the discovery document.

## 0.6.0+1

 - **DOCS**: fixed docs link.

## 0.6.0

> Note: This release has breaking changes.

 - **FEAT**: added claimNames and claimSources to OidcUserInfoResponse.
 - **BREAKING** **CHANGE**: changed nonce to get stored in secureTokens namespace.

## 0.5.1

 - **FEAT**: added device authorization endpoint.

## 0.5.0+1

 - **FIX**: added `userInfo` to `fromIdToken`.
 - **DOCS**: added oidc_core docs and updated example.

## 0.5.0

## 0.4.1

 - **FEAT**: add response form userInfo endpoint to the user object.
 - **FEAT**: use package:clock for better testing.

## 0.4.0+1

 - **FIX**: token date calculations.

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **CHANGE**: all packages.

## 0.3.2

 - **FEAT**: support logout.

## 0.3.1

 - **FEAT**: initial version.

## 0.3.0

 - Working authorization code flow, without refresh_token support.

## 0.2.0

 - **FEAT**: added more helpers.

## 0.1.0+1

- Added topics.

## 0.1.0

- Initial version.
