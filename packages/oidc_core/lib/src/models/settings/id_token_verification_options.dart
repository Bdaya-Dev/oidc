import 'package:jose_plus/jose.dart';

///
class OidcIdTokenVerificationOptions {
  ///
  const OidcIdTokenVerificationOptions({
    this.keyStore,
    this.allowedAlgorithms,
    this.validateAudience = false,
    this.validateIssuer = false,
    this.expiryTolerance = Duration.zero,
    this.clientId,
  });

  /// A key store to lookup [JsonWebKey]s
  final JsonWebKeyStore? keyStore;

  /// Allowed algorithms.
  final List<String>? allowedAlgorithms;

  /// whether to validate the `aud` header in the jwt contains the client id.
  final bool validateAudience;

  /// whether to validate the `iss` header in the jwt is the same issuer as in the
  /// discovery document.
  final bool validateIssuer;

  /// some small leeway, usually no more than a few
  /// minutes, to account for clock skew.
  final Duration expiryTolerance;

  /// the client id to validate
  final String? clientId;
}
