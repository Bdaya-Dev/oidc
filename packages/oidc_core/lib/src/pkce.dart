// coverage:ignore-file
// Source: https://github.com/nrubin29/pkce_dart/blob/master/lib/pkce.dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A pair of ([codeVerifier], [codeChallenge]) that can be used with PKCE
/// (Proof Key for Code Exchange).
class OidcPkcePair {
  const OidcPkcePair._(this.codeVerifier, this.codeChallenge);

  /// Generates a [OidcPkcePair].
  ///
  /// [length] is the length used to generate the [codeVerifier]. It must be
  /// between 32 and 96, inclusive, which corresponds to a [codeVerifier] of
  /// length between 43 and 128, inclusive. The spec recommends a length of 32.
  factory OidcPkcePair.generate({int length = 32}) {
    final verifier = generateVerifier(length: length);
    final challenge = generateS256Challenge(verifier);
    return OidcPkcePair._(verifier, challenge);
  }

  /// The code verifier.
  final String codeVerifier;

  /// The code challenge, computed as base64Url(sha256([codeVerifier])) with
  /// padding removed as per the spec.
  final String codeChallenge;

  static String generateVerifier({int length = 32}) {
    if (length < 32 || length > 96) {
      throw ArgumentError.value(
          length, 'length', 'The length must be between 32 and 96, inclusive.');
    }

    final random = Random.secure();
    return base64UrlEncode(List.generate(length, (_) => random.nextInt(256)))
        .split('=')
        .first;
  }

  static String generateS256Challenge(String verifier) {
    return base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
        .split('=')
        .first;
  }

  static String generatePlainChallenge(String verifier) {
    return verifier;
  }
}
