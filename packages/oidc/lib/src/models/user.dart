import 'package:jose/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'id_token_verification_options.dart';

/// A user is a verified JWT id_token, with some metadata (like access_token and refresh_token).
class OidcUser {
  ///
  const OidcUser({
    required this.idToken,
    required this.parsedToken,
    this.metadata = const {},
  });

  /// Creates a OidcUser from an encoded idToken.
  ///
  /// You can verify the idToken by passing the [verificationOptions] parameter,
  /// which requires at least the key.
  ///
  /// You can also pass optional [metadata] that will get stored with the user.
  static Future<OidcUser> fromIdToken({
    required String idToken,
    Map<String, dynamic> metadata = const {},
    OidcIdTokenVerificationOptions? verificationOptions,
  }) async {
    final keystore = verificationOptions?.keyStore;
    final token = verificationOptions == null || keystore == null
        ? JsonWebToken.unverified(idToken)
        : await JsonWebToken.decodeAndVerify(
            idToken,
            keystore,
            allowedArguments: verificationOptions.allowedAlgorithms,
          );

    return OidcUser(
      idToken: idToken,
      parsedToken: token,
      metadata: metadata,
    );
  }

  /// The jwt token this user was verified from.
  final String idToken;

  /// The claims that were decoded from the idToken
  JsonWebTokenClaims get claims => parsedToken.claims;

  /// The user Id
  String? get uid => claims.subject;

  /// The user Id, but if it's null, it will throw.
  String get uidRequired => uid!;

  /// Extra metadata for the user
  final Map<String, dynamic> metadata;

  /// Try getting the `access_token` from the [metadata].
  String? get accessToken =>
      metadata[OidcConstants_Store.accessToken] as String?;

  /// Try getting the `refresh_token` from the [metadata].
  String? get refreshToken =>
      metadata[OidcConstants_Store.refreshToken] as String?;

  /// The parsed jwt token
  final JsonWebToken parsedToken;
}
