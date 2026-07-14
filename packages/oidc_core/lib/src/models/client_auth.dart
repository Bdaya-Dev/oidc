import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:jose_plus/jose.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
part 'client_auth.g.dart';

final Codec<String, String> _utf8ThenBase64 = utf8.fuse(base64);

@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
)
class OidcClientAuthentication {
  const OidcClientAuthentication.none({
    required this.clientId,
  }) : location = OidcConstants_ClientAuthenticationMethods.none,
       clientSecret = null,
       clientAssertion = null,
       clientAssertionType = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  const OidcClientAuthentication.clientSecretBasic({
    required this.clientId,
    required String this.clientSecret,
  }) : location = OidcConstants_ClientAuthenticationMethods.clientSecretBasic,
       clientAssertionType = null,
       clientAssertion = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  const OidcClientAuthentication.clientSecretPost({
    required this.clientId,
    required String this.clientSecret,
  }) : location = OidcConstants_ClientAuthenticationMethods.clientSecretPost,
       clientAssertionType = null,
       clientAssertion = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  const OidcClientAuthentication.clientSecretJwt({
    required this.clientId,
    required String this.clientAssertion,
  }) : location = OidcConstants_ClientAuthenticationMethods.clientSecretJwt,
       clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
       clientSecret = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  const OidcClientAuthentication.privateKeyJwt({
    required this.clientId,
    required String this.clientAssertion,
  }) : location = OidcConstants_ClientAuthenticationMethods.privateKeyJwt,
       clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
       clientSecret = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  /// Authenticates with mutual TLS using the PKI method (RFC 8705 §2.1).
  ///
  /// No secret or assertion is placed in the request; the client is
  /// authenticated by the certificate presented on the TLS connection, so the
  /// only body parameter emitted is `client_id` (RFC 8705 §2.1). Establishing
  /// the certificate-bearing TLS transport is the responsibility of the native
  /// HTTP layer and is out of scope for this (platform-agnostic) model.
  const OidcClientAuthentication.tlsClientAuth({
    required this.clientId,
  }) : location = OidcConstants_ClientAuthenticationMethods.tlsClientAuth,
       clientSecret = null,
       clientAssertion = null,
       clientAssertionType = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  /// Authenticates with mutual TLS using a self-signed certificate
  /// (RFC 8705 §2.2).
  ///
  /// As with [OidcClientAuthentication.tlsClientAuth], no secret or assertion
  /// is sent; the client is authenticated by matching the presented
  /// certificate against a registered public key, so the only body parameter
  /// emitted is `client_id`. The certificate-bearing TLS transport is provided
  /// by the native HTTP layer.
  const OidcClientAuthentication.selfSignedTlsClientAuth({
    required this.clientId,
  }) : location =
           OidcConstants_ClientAuthenticationMethods.selfSignedTlsClientAuth,
       clientSecret = null,
       clientAssertion = null,
       clientAssertionType = null,
       _signingKey = null,
       _signingAlgorithm = null,
       _assertionLifetime = null;

  /// Authenticates with a `private_key_jwt` (RFC 7523 / OIDC §9) client
  /// assertion that the library MINTS fresh per request, signed by [signingKey]
  /// with [algorithm] (e.g. `RS256`, `ES256`). The public key must be
  /// registered with the OP. [signingKey] is held in memory and never
  /// serialized.
  OidcClientAuthentication.privateKeyJwtGenerated({
    required this.clientId,
    required JsonWebKey signingKey,
    String algorithm = 'RS256',
    Duration assertionLifetime = const Duration(minutes: 1),
  }) : location = OidcConstants_ClientAuthenticationMethods.privateKeyJwt,
       clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
       clientSecret = null,
       clientAssertion = null,
       _signingKey = signingKey,
       _signingAlgorithm = algorithm,
       _assertionLifetime = assertionLifetime;

  /// Authenticates with a `client_secret_jwt` (RFC 7523 / OIDC §9) client
  /// assertion that the library MINTS fresh per request, HMAC-signed with
  /// [clientSecret] using [algorithm] (an HMAC alg, e.g. `HS256`). The secret
  /// is never sent on the wire (only the assertion is).
  OidcClientAuthentication.clientSecretJwtGenerated({
    required this.clientId,
    required String clientSecret,
    String algorithm = 'HS256',
    Duration assertionLifetime = const Duration(minutes: 1),
  }) : location = OidcConstants_ClientAuthenticationMethods.clientSecretJwt,
       clientAssertionType = OidcConstants_ClientAssertionTypes.jwtBearer,
       clientSecret = null,
       clientAssertion = null,
       _signingKey = JsonWebKey.fromJson({
         'kty': 'oct',
         'k': base64Url.encode(utf8.encode(clientSecret)).replaceAll('=', ''),
         'alg': algorithm,
       }),
       _signingAlgorithm = algorithm,
       _assertionLifetime = assertionLifetime;

  /// Derives a ready-to-use client authentication from a Dynamic Client
  /// Registration response (RFC 7591 §3.2.1 / RFC 7592).
  ///
  /// The method is taken from [preferredMethod] when supplied, otherwise from
  /// the response's `token_endpoint_auth_method`, otherwise it defaults to
  /// `client_secret_basic` (RFC 7591 §2). The response's `client_secret` (when
  /// present) supplies the credential:
  ///
  /// - `none` → [OidcClientAuthentication.none].
  /// - `client_secret_basic` → [OidcClientAuthentication.clientSecretBasic].
  /// - `client_secret_post` → [OidcClientAuthentication.clientSecretPost].
  /// - `client_secret_jwt` → [OidcClientAuthentication.clientSecretJwtGenerated]
  ///   (assertions are minted per request from the issued secret).
  ///
  /// Throws an [OidcException] when the response carries no `client_id`, when a
  /// secret-based method is selected but no `client_secret` was issued, when
  /// the method is `private_key_jwt` (whose signing key is held by the client
  /// out of band and is never part of a registration response — construct
  /// [OidcClientAuthentication.privateKeyJwtGenerated] directly with that key),
  /// or when the method is otherwise unsupported/unknown.
  factory OidcClientAuthentication.fromRegistrationResponse(
    OidcClientRegistrationResponse response, {
    String? preferredMethod,
  }) {
    final clientId = response.clientId;
    if (clientId == null) {
      throw const OidcException(
        'Cannot derive client authentication: the registration response has '
        'no client_id.',
      );
    }
    final method =
        preferredMethod ??
        response.tokenEndpointAuthMethod ??
        OidcConstants_ClientAuthenticationMethods.clientSecretBasic;
    final secret = response.clientSecret;

    String requireSecret() {
      if (secret == null) {
        throw OidcException(
          'The registration response selected token_endpoint_auth_method '
          '"$method" but did not issue a client_secret.',
        );
      }
      return secret;
    }

    switch (method) {
      case OidcConstants_ClientAuthenticationMethods.none:
        return OidcClientAuthentication.none(clientId: clientId);
      case OidcConstants_ClientAuthenticationMethods.clientSecretBasic:
        return OidcClientAuthentication.clientSecretBasic(
          clientId: clientId,
          clientSecret: requireSecret(),
        );
      case OidcConstants_ClientAuthenticationMethods.clientSecretPost:
        return OidcClientAuthentication.clientSecretPost(
          clientId: clientId,
          clientSecret: requireSecret(),
        );
      case OidcConstants_ClientAuthenticationMethods.clientSecretJwt:
        return OidcClientAuthentication.clientSecretJwtGenerated(
          clientId: clientId,
          clientSecret: requireSecret(),
        );
      case OidcConstants_ClientAuthenticationMethods.privateKeyJwt:
        throw const OidcException(
          'token_endpoint_auth_method "private_key_jwt" cannot be derived from '
          'a registration response: the signing key is held by the client and '
          'is never returned by the server. Construct '
          'OidcClientAuthentication.privateKeyJwtGenerated directly with your '
          'private key.',
        );
      default:
        throw OidcException(
          'Unsupported token_endpoint_auth_method "$method".',
        );
    }
  }

  @JsonKey(includeToJson: false)
  final String location;
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String clientId;
  @JsonKey(name: OidcConstants_AuthParameters.clientSecret)
  final String? clientSecret;
  @JsonKey(name: OidcConstants_AuthParameters.clientAssertionType)
  final String? clientAssertionType;
  @JsonKey(name: OidcConstants_AuthParameters.clientAssertion)
  final String? clientAssertion;

  // Runtime-only signing material for the `*JwtGenerated` auth methods; never
  // serialized (json_serializable ignores private fields).
  final JsonWebKey? _signingKey;
  final String? _signingAlgorithm;
  final Duration? _assertionLifetime;

  String? getAuthorizationHeader() {
    if (location !=
        OidcConstants_ClientAuthenticationMethods.clientSecretBasic) {
      return null;
    }
    final secret = clientSecret;
    if (secret == null) {
      return null;
    }
    // RFC 6749 §2.3.1: the client_id and client_secret are each individually
    // encoded with the "application/x-www-form-urlencoded" encoding algorithm
    // (per Appendix B) BEFORE being concatenated with a colon and base64'd.
    final concat =
        '${Uri.encodeQueryComponent(clientId)}:'
        '${Uri.encodeQueryComponent(secret)}';
    return 'Basic ${_utf8ThenBase64.encode(concat)}';
  }

  Map<String, String> getBodyParameters() =>
      _$OidcClientAuthenticationToJson(this).cast<String, String>();

  /// Returns a request-ready credentials object.
  ///
  /// For the `*JwtGenerated` auth methods this mints a fresh, single-use
  /// `client_assertion` JWT (RFC 7523 §3 / OIDC §9): `iss` and `sub` are the
  /// client_id, `aud` is [audience] (the OP's token endpoint), plus `jti`,
  /// `iat` and a short `exp`, signed with the held key/secret. All other auth
  /// methods return `this` unchanged.
  OidcClientAuthentication resolveForRequest(Uri audience) {
    final key = _signingKey;
    final alg = _signingAlgorithm;
    if (key == null || alg == null) {
      return this;
    }
    final now = clock.now();
    final rng = Random.secure();
    final jti = base64Url
        .encode(List<int>.generate(16, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
    final assertion =
        (JsonWebSignatureBuilder()
              ..jsonContent = {
                'iss': clientId,
                'sub': clientId,
                'aud': audience.toString(),
                'jti': jti,
                'iat': now.millisecondsSinceEpoch ~/ 1000,
                'exp':
                    now
                        .add(_assertionLifetime ?? const Duration(minutes: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }
              ..setProtectedHeader('typ', 'JWT')
              ..addRecipient(key, algorithm: alg))
            .build()
            .toCompactSerialization();
    return location == OidcConstants_ClientAuthenticationMethods.privateKeyJwt
        ? OidcClientAuthentication.privateKeyJwt(
            clientId: clientId,
            clientAssertion: assertion,
          )
        : OidcClientAuthentication.clientSecretJwt(
            clientId: clientId,
            clientAssertion: assertion,
          );
  }
}
