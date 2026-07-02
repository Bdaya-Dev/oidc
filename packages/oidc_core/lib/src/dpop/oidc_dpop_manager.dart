import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';

/// Holds the per-session DPoP proof key + nonce cache and mints DPoP proofs
/// (RFC 9449).
///
/// A fresh manager (and key) is created per login session; the SAME key MUST be
/// reused for refreshes because the refresh token is sender-constrained to it
/// (RFC 9449 §5). Do not rotate the key mid-session.
class OidcDPoPManager {
  /// Creates a manager bound to an existing [key].
  OidcDPoPManager({required this.key, required this.settings});

  /// Generates a fresh proof key for [settings].
  factory OidcDPoPManager.generate(OidcDPoPSettings settings) =>
      OidcDPoPManager(
        key: JsonWebKey.generate(settings.algorithm.joseName),
        settings: settings,
      );

  /// The DPoP proof key. Holds private material — never embed it in a proof;
  /// only the public projection ([oidcDPoPPublicJwk]) is published.
  final JsonWebKey key;

  /// The DPoP settings.
  final OidcDPoPSettings settings;

  /// The RFC 7638 thumbprint of [key] — the `dpop_jkt` / `cnf.jkt` value.
  late final String thumbprint = oidcJwkThumbprint(key);

  // Per-endpoint nonce cache; the AS and each RS supply independent nonces.
  final _nonces = <String, String>{};

  /// The most recently cached DPoP nonce for [endpoint], if any.
  String? nonceFor(Uri endpoint) => _nonces[oidcNormalizeHtu(endpoint)];

  /// Caches a server-provided DPoP nonce for [endpoint] (from a
  /// `use_dpop_nonce` challenge).
  void setNonceFor(Uri endpoint, String nonce) =>
      _nonces[oidcNormalizeHtu(endpoint)] = nonce;

  /// Mints a DPoP proof for a token-endpoint `POST` (no `ath` — there is no
  /// access token yet).
  String createTokenProof(Uri tokenEndpoint) => oidcCreateDPoPProof(
    key: key,
    algorithm: settings.algorithm.joseName,
    htm: 'POST',
    htu: tokenEndpoint,
    nonce: nonceFor(tokenEndpoint),
    clockSkew: settings.clockSkew,
  );

  /// Mints a DPoP proof for a protected-resource / UserInfo request (includes
  /// the `ath` claim bound to [accessToken]).
  String createResourceProof({
    required String method,
    required Uri uri,
    required String accessToken,
  }) => oidcCreateDPoPProof(
    key: key,
    algorithm: settings.algorithm.joseName,
    htm: method,
    htu: uri,
    accessToken: accessToken,
    nonce: nonceFor(uri),
    clockSkew: settings.clockSkew,
  );
}
