/// Settings + algorithm selection for DPoP (RFC 9449).
library;

/// The asymmetric signature algorithm used for the DPoP proof key.
///
/// Only algorithms supported by `jose_plus` are offered (RSA-PSS / `PS256` is
/// not available).
enum OidcDPoPAlgorithm {
  /// ECDSA using P-256 and SHA-256 (the default).
  es256('ES256'),

  /// ECDSA using P-384 and SHA-384.
  es384('ES384'),

  /// ECDSA using P-521 and SHA-512.
  es512('ES512'),

  /// RSASSA-PKCS1-v1_5 using SHA-256.
  rs256('RS256');

  const OidcDPoPAlgorithm(this.joseName);

  /// The JOSE `alg` header value (e.g. `ES256`).
  final String joseName;
}

/// Enables and configures DPoP (Demonstrating Proof of Possession, RFC 9449)
/// for an `OidcUserManager`.
///
/// Setting `OidcUserManagerSettings.dpop` to a non-null value enables DPoP. A
/// single proof key is generated per session and reused for the whole token
/// set, because the refresh token becomes sender-constrained to it (RFC 9449
/// §5). The key is held in memory; on app restart it is lost and a fresh login
/// is required.
class OidcDPoPSettings {
  /// Creates DPoP settings.
  const OidcDPoPSettings({
    this.algorithm = OidcDPoPAlgorithm.es256,
    this.clockSkew = Duration.zero,
    this.bindAuthorizationCode = true,
  });

  /// The proof key algorithm. Defaults to [OidcDPoPAlgorithm.es256].
  final OidcDPoPAlgorithm algorithm;

  /// An optional offset added to the proof `iat` to tolerate client clock skew.
  final Duration clockSkew;

  /// Whether to bind the authorization code to the DPoP key via the `dpop_jkt`
  /// parameter on PAR / the authorization request (RFC 9449 §10). Defaults to
  /// true.
  final bool bindAuthorizationCode;
}
