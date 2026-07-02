import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Reads the `alg` from a compact-JWS [jwt]'s JOSE header, or null if it can't
/// be parsed.
String? oidcReadJwtAlg(String jwt) {
  final parts = jwt.split('.');
  if (parts.length < 2) return null;
  try {
    final header =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))))
            as Map<String, dynamic>;
    return header['alg'] as String?;
  } on Object {
    return null;
  }
}

/// Computes an OpenID Connect `at_hash` / `c_hash` value (OIDC Core §3.2.2.9 /
/// §3.3.2.11): the base64url (no padding) encoding of the LEFT-MOST HALF of the
/// hash of `ASCII(value)`, using the SHA-2 hash matching the id_token's JOSE
/// [alg] (`*256` -> SHA-256, `*384` -> SHA-384, `*512` -> SHA-512).
///
/// Returns null when [alg] is not a supported SHA-2-family algorithm or when
/// [value] is not ASCII, so the caller can skip the check rather than fail
/// spuriously.
String? oidcComputeTokenHash(String alg, String value) {
  final hash = _hashForAlg(alg);
  if (hash == null) {
    return null;
  }
  if (value.codeUnits.any((c) => c > 0x7F)) {
    return null;
  }
  final digest = hash.convert(ascii.encode(value)).bytes;
  final half = digest.sublist(0, digest.length ~/ 2);
  return base64Url.encode(half).replaceAll('=', '');
}

Hash? _hashForAlg(String alg) {
  if (alg.endsWith('256')) {
    return sha256;
  }
  if (alg.endsWith('384')) {
    return sha384;
  }
  if (alg.endsWith('512')) {
    return sha512;
  }
  return null;
}
