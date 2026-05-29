/// [JSON Web Token](https://tools.ietf.org/html/rfc7519)
library;

import 'package:clock/clock.dart';

import 'jose.dart';
import 'jwk.dart';
import 'util.dart';
import 'dart:async';
import 'jws.dart';

/// The set of claims conveyed by the [JsonWebToken]
class JsonWebTokenClaims extends JsonObject {
  /// Constructs a [JsonWebTokenClaims] from a [json] map
  JsonWebTokenClaims.fromJson(super.json) : super.from();

  /// Identifies the principal that issued the JWT.
  Uri? get issuer => getTyped('iss');

  /// Session ID
  String? get sid => getTyped('sid');

  /// Identifies the principal that is the subject of the JWT.
  ///
  /// The claims in a JWT are normally statements about the subject.
  ///
  /// The subject value MUST either be scoped to be locally unique in the
  /// context of the issuer or be globally unique.
  String? get subject => this['sub'];

  /// Identifies the recipients that the JWT is intended for.
  ///
  /// Each principal intended to process the JWT MUST identify itself with a
  /// value in the audience claim. If the principal processing the claim does
  /// not identify itself with a value in the 'aud' claim when this claim is
  /// present, then the JWT MUST be rejected.
  List<String>? get audience => getTypedList('aud');

  /// Identifies the expiration time on or after which the JWT MUST NOT be
  /// accepted for processing.
  ///
  /// Implementers MAY provide for some small leeway, usually no more than a few
  /// minutes, to account for clock skew.
  DateTime? get expiry => getTyped('exp');

  /// Identifies the time before which the JWT MUST NOT be accepted for
  /// processing.
  ///
  /// Implementers MAY provide for some small leeway, usually no more than a few
  /// minutes, to account for clock skew.
  DateTime? get notBefore => getTyped('nbf');

  /// Identifies the time at which the JWT was issued.
  ///
  /// This claim can be used to determine the age of the JWT.
  DateTime? get issuedAt => getTyped('iat');

  /// Provides a unique identifier for the JWT.
  ///
  /// The identifier value MUST be assigned in a manner that ensures that there
  /// is a negligible probability that the same value will be accidentally
  /// assigned to a different data object; if the application uses multiple
  /// issuers, collisions MUST be prevented among values produced by different
  /// issuers as well.
  ///
  /// The 'jti' claim can be used to prevent the JWT from being replayed.
  String? get jwtId => this['jti'];

  Iterable<JoseException> validate({
    Duration expiryTolerance = const Duration(),
    Uri? issuer,
    String? clientId,
  }) sync* {
    final now = clock.now();
    final diff = now.difference(expiry!);
    if (diff > expiryTolerance) {
      yield JoseException(
        'JWT expired. Expiry ($expiry) is more than tolerance '
        '($expiryTolerance) before now ($now)',
      );
    }
    if (issuer != null && this.issuer != issuer) {
      yield JoseException(
        'Issuer does not match. Expected '
        '`$issuer`, was `${this.issuer}`',
      );
    }
    final aud = audience;
    if (clientId != null && (aud == null || !aud.contains(clientId))) {
      yield JoseException('Audiences does not contain clientId `$clientId`.');
    }
  }
}

/// Represents a JWT
class JsonWebToken {
  final JoseObject _joseObject;

  /// The claims conveyed by the [JsonWebToken]
  final JsonWebTokenClaims claims;

  bool? _verified;

  JsonWebToken._(this._joseObject, this.claims, this._verified);

  JsonWebToken._fromJws(JsonWebSignature jws)
      : this._(
            jws,
            JsonWebTokenClaims.fromJson(jws.unverifiedPayload.jsonContent),
            null);

  /// Decodes a JWT string from a JWS compact serialization, without verifying
  /// the integrity
  JsonWebToken.unverified(String serialization)
      : this._fromJws(JsonWebSignature.fromCompactSerialization(serialization));

  /// Decodes and verifies/decrypts a JWT string from a JWE or JWS compact
  /// serialization
  static Future<JsonWebToken> decodeAndVerify(
      String serialization, JsonWebKeyStore keyStore,
      {List<String>? allowedArguments}) async {
    var joseObject = JoseObject.fromCompactSerialization(serialization);
    var content = await joseObject.getPayload(keyStore,
        allowedAlgorithms: allowedArguments);
    JsonWebTokenClaims claims;
    if (content.mediaType == 'JWT') {
      claims = (await decodeAndVerify(content.stringContent, keyStore,
              allowedArguments: allowedArguments))
          .claims;
    } else {
      claims = JsonWebTokenClaims.fromJson(content.jsonContent);
    }
    return JsonWebToken._(joseObject, claims, true);
  }

  /// Serializes the [JsonWebToken] to a string
  String toCompactSerialization() => _joseObject.toCompactSerialization();

  /// Returns `true` if this JWT has been successfully verified, `false` if
  /// verification failed and `null` if no verification attempt has been made
  bool? get isVerified => _verified;

  /// Attempts to verify this JWT
  Future<bool> verify(JsonWebKeyStore keyStore,
      {List<String>? allowedArguments}) async {
    try {
      await _joseObject.getPayload(keyStore,
          allowedAlgorithms: allowedArguments);
      return _verified = true;
    } catch (e) {
      return _verified = false;
    }
  }
}
