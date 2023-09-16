import 'package:jose_plus/jose.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';

final _logger = Logger('Oidc.User');

/// A user is a verified JWT id_token, with an optional access_token.
class OidcUser {
  ///
  OidcUser._({
    required this.idToken,
    required this.parsedIdToken,
    required this.token,
    required this.attributes,
    required this.keystore,
    required this.allowedAlgorithms,
    required this.userInfo,
  });

  /// Creates a OidcUser from an encoded id_token passed via [token].
  ///
  /// You can verify the idToken by passing the [keystore] parameter.
  ///
  /// You can also pass optional [attributes] that will get stored
  /// with the user.
  static Future<OidcUser> fromIdToken({
    required OidcToken token,
    bool strictVerification = false,
    JsonWebKeyStore? keystore,
    List<String>? allowedAlgorithms,
    Map<String, dynamic>? attributes,
  }) async {
    final idToken = token.idToken;
    if (idToken == null) {
      throw const OidcException(
        "Server didn't return the id_token.",
      );
    }
    JsonWebToken webToken;
    if (keystore == null) {
      webToken = JsonWebToken.unverified(idToken);
    } else {
      try {
        webToken = await JsonWebToken.decodeAndVerify(
          idToken,
          keystore,
          allowedArguments: allowedAlgorithms,
        );
      } catch (e, st) {
        if (strictVerification) {
          rethrow;
        }
        _logger.severe(
          'Failed to verify id_token, using unverified instead.',
          e,
          st,
        );
        webToken = JsonWebToken.unverified(idToken);
      }
    }

    return OidcUser._(
      idToken: idToken,
      parsedIdToken: webToken,
      token: token,
      attributes: attributes ?? const {},
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: const {},
    );
  }

  /// The jwt token this user was verified from.
  final String idToken;

  /// The parsed jwt token
  final JsonWebToken parsedIdToken;

  /// The claims that were decoded from the idToken
  JsonWebTokenClaims get claims => parsedIdToken.claims;

  /// The user Id
  String? get uid => claims.subject;

  /// The user Id, but if it's null, it will throw.
  String get uidRequired => uid!;

  /// The current token the user is holding.
  final OidcToken token;

  /// The keystore that was passed from [fromIdToken] (if any).
  final JsonWebKeyStore? keystore;

  /// The allowedAlgorithms that were passed from [fromIdToken] (if any).
  final List<String>? allowedAlgorithms;

  /// immutable custom attributes that are user-defined.
  ///
  /// these MUST be json encodable.
  final Map<String, dynamic> attributes;

  final Map<String, dynamic> userInfo;

  OidcUser withUserInfo(Map<String, dynamic> userInfo) {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      token: token,
      attributes: attributes,
      keystore: keystore,
      allowedAlgorithms: allowedAlgorithms,
      userInfo: userInfo,
    );
  }

  /// if an id_token exists in the [newToken], it will be re-verified.
  Future<OidcUser> replaceToken(OidcToken newToken) async {
    final idToken = newToken.idToken ?? this.idToken;

    JsonWebToken webToken;
    if (idToken != this.idToken) {
      final keystore = this.keystore;
      webToken = keystore == null
          ? JsonWebToken.unverified(idToken)
          : await JsonWebToken.decodeAndVerify(
              idToken,
              keystore,
              allowedArguments: allowedAlgorithms,
            );
    } else {
      webToken = parsedIdToken;
    }

    return OidcUser._(
      idToken: idToken,
      parsedIdToken: webToken,
      token: newToken,
      attributes: attributes,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }

  OidcUser setAttributes(Map<String, dynamic> attributes) {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      attributes: {
        ...this.attributes,
        ...attributes,
      },
      token: token,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }

  OidcUser clearAttributes() {
    return OidcUser._(
      idToken: idToken,
      parsedIdToken: parsedIdToken,
      attributes: const {},
      token: token,
      allowedAlgorithms: allowedAlgorithms,
      keystore: keystore,
      userInfo: userInfo,
    );
  }
}
