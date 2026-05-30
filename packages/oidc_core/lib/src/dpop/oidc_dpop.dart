/// Low-level building blocks for DPoP (Demonstrating Proof of Possession),
/// [RFC 9449](https://datatracker.ietf.org/doc/html/rfc9449).
///
/// These are pure functions over a [JsonWebKey]; the per-session key lifecycle,
/// nonce cache, and request wiring live in `OidcDPoPManager`.
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';

const _base64UrlNoPad = _Base64UrlNoPad();

class _Base64UrlNoPad {
  const _Base64UrlNoPad();
  String call(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
}

/// The DPoP proof JOSE header `typ` value (RFC 9449 §4.2).
const oidcDPoPProofTyp = 'dpop+jwt';

/// The HTTP request header that carries a DPoP proof JWT (RFC 9449 §4).
const oidcDPoPHeaderName = 'DPoP';

/// The HTTP response header that conveys a server-provided DPoP nonce
/// (RFC 9449 §8 / §9).
const oidcDPoPNonceHeaderName = 'DPoP-Nonce';

/// The OAuth error code a server returns to demand a DPoP nonce
/// (RFC 9449 §8 / §9).
const oidcDPoPUseNonceError = 'use_dpop_nonce';

/// Projects [key] to its **public** JWK members only (RFC 9449 §4.2 requires
/// the embedded `jwk` to contain no private key material).
///
/// Supports EC (`crv,x,y`), RSA (`n,e`) and OKP (`crv,x`).
Map<String, dynamic> oidcDPoPPublicJwk(JsonWebKey key) {
  final kty = key['kty'] as String?;
  switch (kty) {
    case 'EC':
      return {'kty': kty, 'crv': key['crv'], 'x': key['x'], 'y': key['y']};
    case 'RSA':
      return {'kty': kty, 'n': key['n'], 'e': key['e']};
    case 'OKP':
      return {'kty': kty, 'crv': key['crv'], 'x': key['x']};
    default:
      throw OidcException('Unsupported DPoP key type: `$kty`.');
  }
}

/// Computes the RFC 7638 JWK Thumbprint of [key] using SHA-256, returned as a
/// base64url (no padding) string.
///
/// This value is both the `jkt` confirmation claim and the `dpop_jkt`
/// authorization-request parameter (RFC 9449 §6).
String oidcJwkThumbprint(JsonWebKey key) {
  final kty = key['kty'] as String?;
  // The REQUIRED members per key type, in any order — the canonical form below
  // re-sorts them lexicographically (RFC 7638 §3.2).
  final Map<String, dynamic> required;
  switch (kty) {
    case 'EC':
      required = {'crv': key['crv'], 'kty': kty, 'x': key['x'], 'y': key['y']};
    case 'RSA':
      required = {'e': key['e'], 'kty': kty, 'n': key['n']};
    case 'OKP':
      required = {'crv': key['crv'], 'kty': kty, 'x': key['x']};
    default:
      throw OidcException('Unsupported DPoP key type: `$kty`.');
  }
  // Canonical JSON: required members only, lexicographically ordered by member
  // name, no whitespace (RFC 7638 §3.1).
  final canonical = jsonEncode(SplayTreeMap<String, dynamic>.of(required));
  final digest = sha256.convert(utf8.encode(canonical)).bytes;
  return _base64UrlNoPad(digest);
}

/// Generates a fresh, unique DPoP proof identifier (`jti`) with >= 96 bits of
/// entropy (RFC 9449 §4.2), as a base64url (no padding) string.
String oidcGenerateDPoPJti() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return _base64UrlNoPad(bytes);
}

/// Normalizes a target URI for the `htu` claim (RFC 9449 §4.2/§4.3): the scheme
/// and host lowercased, default ports dropped, and the query + fragment
/// removed.
String oidcNormalizeHtu(Uri uri) {
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

/// Computes the `ath` claim — base64url (no padding) of `SHA-256(ASCII(token))`
/// — binding a DPoP proof to an access token (RFC 9449 §4.2 / §7.1).
String oidcDPoPAth(String accessToken) {
  final digest = sha256.convert(ascii.encode(accessToken)).bytes;
  return _base64UrlNoPad(digest);
}

/// Builds a DPoP proof JWT (RFC 9449 §4.2) signed by [key] with [algorithm]
/// (e.g. `ES256`).
///
/// The protected header carries `typ=dpop+jwt`, `alg`, and the **public** `jwk`.
/// The payload carries `jti`, `htm` (uppercased), `htu` (normalized), `iat`,
/// plus `ath` when [accessToken] is given (resource requests only) and `nonce`
/// when [nonce] is given (after a server `use_dpop_nonce` challenge).
String oidcCreateDPoPProof({
  required JsonWebKey key,
  required String algorithm,
  required String htm,
  required Uri htu,
  String? accessToken,
  String? nonce,
  Duration clockSkew = Duration.zero,
}) {
  final iat = (clock.now().toUtc().add(clockSkew).millisecondsSinceEpoch / 1000)
      .floor();
  final claims = <String, dynamic>{
    'jti': oidcGenerateDPoPJti(),
    'htm': htm.toUpperCase(),
    'htu': oidcNormalizeHtu(htu),
    'iat': iat,
    if (accessToken != null) 'ath': oidcDPoPAth(accessToken),
    'nonce': ?nonce,
  };
  // `alg` is supplied ONLY via addRecipient; also setting it on the protected
  // header would trip jose_plus's equality guard. `typ` + the public `jwk` are
  // the only explicit protected-header parameters.
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..setProtectedHeader('typ', oidcDPoPProofTyp)
    ..setProtectedHeader('jwk', oidcDPoPPublicJwk(key))
    ..addRecipient(key, algorithm: algorithm);
  return builder.build().toCompactSerialization();
}
