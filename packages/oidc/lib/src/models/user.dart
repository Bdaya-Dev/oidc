import 'package:jose/jose.dart';
import 'package:oidc/src/models/user_metadata.dart';

/// A user is a verified JWT id_token, with some metadata (like access_token and refresh_token).
class OidcUser {
  ///
  const OidcUser({
    required this.idToken,
    required this.parsedToken,
    this.metadata = const OidcUserMetadata.empty(),
  });

  /// Creates a OidcUser from an encoded idToken.
  ///
  /// You can verify the idToken by passing the [keystore] parameter.
  ///
  /// You can also pass optional [metadata] that will get stored with the user.
  static Future<OidcUser> fromIdToken({
    required String idToken,
    OidcUserMetadata? metadata,
    JsonWebKeyStore? keystore,
    List<String>? allowedAlgorithms,
  }) async {
    final token = keystore == null
        ? JsonWebToken.unverified(idToken)
        : await JsonWebToken.decodeAndVerify(
            idToken,
            keystore,
            allowedArguments: allowedAlgorithms,
          );

    return OidcUser(
      idToken: idToken,
      parsedToken: token,
      metadata: metadata ?? const OidcUserMetadata.empty(),
    );
  }

  /// The jwt token this user was verified from.
  final String idToken;

  /// The parsed jwt token
  final JsonWebToken parsedToken;

  /// The claims that were decoded from the idToken
  JsonWebTokenClaims get claims => parsedToken.claims;

  /// The user Id
  String? get uid => claims.subject;

  /// The user Id, but if it's null, it will throw.
  String get uidRequired => uid!;

  /// Extra metadata for the user
  final OidcUserMetadata metadata;
}
