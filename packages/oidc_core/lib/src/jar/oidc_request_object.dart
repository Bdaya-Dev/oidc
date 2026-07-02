import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';

/// Configuration for JWT-Secured Authorization Requests (JAR, RFC 9101):
/// signing the authorization request parameters into a `request` JWT.
///
/// The [signingKey] is a key associated with the client (RFC 9101 §6.1); for a
/// confidential client this can be the same key used for `private_key_jwt`.
class OidcRequestObjectSettings {
  ///
  const OidcRequestObjectSettings({
    required this.signingKey,
    required this.algorithm,
    this.lifetime = const Duration(minutes: 5),
    this.clockSkew = Duration.zero,
  });

  /// The JWS signing key (its `alg` must be supported by the authorization
  /// server's `request_object_signing_alg_values_supported`).
  final JsonWebKey signingKey;

  /// The JWS algorithm, e.g. `ES256`, `RS256`, `PS256`.
  final String algorithm;

  /// How long the request object is valid (sets `exp`).
  final Duration lifetime;

  /// Tolerance subtracted from `iat`/`nbf` to allow for clock skew.
  final Duration clockSkew;
}

/// Generates a random `jti` for a request object.
String oidcGenerateRequestObjectJti([Random? random]) {
  final rng = random ?? Random.secure();
  return base64Url
      .encode(List<int>.generate(16, (_) => rng.nextInt(256)))
      .replaceAll('=', '');
}

/// Builds a signed JWT-Secured Authorization Request object (RFC 9101 §4) from
/// the authorization [parameters].
///
/// The returned compact JWS is the value of the `request` authorization
/// parameter. `iss` is set to the client_id and `aud` to the authorization
/// server (its issuer), per RFC 9101 §6.1; `iat`/`exp`/`jti` are added. The
/// `typ` header is `oauth-authz-req+jwt` (RFC 9101 §10.8).
String oidcCreateRequestObject({
  required Map<String, dynamic> parameters,
  required JsonWebKey key,
  required String algorithm,
  required String issuer,
  required String audience,
  Duration lifetime = const Duration(minutes: 5),
  Duration clockSkew = Duration.zero,
  Random? random,
}) {
  final now = clock.now();
  final claims = <String, dynamic>{
    ...parameters,
    'iss': issuer,
    'aud': audience,
    'jti': oidcGenerateRequestObjectJti(random),
    'iat': now.subtract(clockSkew).millisecondsSinceEpoch ~/ 1000,
    'nbf': now.subtract(clockSkew).millisecondsSinceEpoch ~/ 1000,
    'exp': now.add(lifetime).millisecondsSinceEpoch ~/ 1000,
  };
  return (JsonWebSignatureBuilder()
        ..jsonContent = claims
        ..setProtectedHeader('typ', 'oauth-authz-req+jwt')
        ..addRecipient(key, algorithm: algorithm))
      .build()
      .toCompactSerialization();
}
