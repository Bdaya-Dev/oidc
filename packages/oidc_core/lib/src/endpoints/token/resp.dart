import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:oidc_core/src/models/json_based_object.dart';

part 'resp.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
  constructor: '_',
)
class OidcTokenResponse extends JsonBasedResponse {
  const OidcTokenResponse._({
    required super.src,
    this.tokenType,
    this.accessToken,
    this.scope,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
    this.sessionState,
  });

  factory OidcTokenResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcTokenResponseFromJson(src);

  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    fromJson: OidcInternalUtilities.splitSpaceDelimitedStringNullable,
  )
  final List<String>? scope;

  /// OPTIONAL.
  ///
  /// The access token issued by the authorization server.
  @JsonKey(name: OidcConstants_AuthParameters.accessToken)
  final String? accessToken;

  /// REQUIRED.
  ///
  /// The type of the access token issued.
  ///
  /// Value is case insensitive.
  @JsonKey(name: OidcConstants_AuthParameters.tokenType)
  final String? tokenType;

  /// REQUIRED, in the OIDC spec.
  ///
  /// ID Token value associated with the authenticated session.
  @JsonKey(name: OidcConstants_AuthParameters.idToken)
  final String? idToken;

  bool get isOidc => idToken?.isNotEmpty ?? false;

  /// RECOMMENDED.
  ///
  /// The lifetime in seconds of the access token.
  ///
  /// For example, the value 3600 denotes that the access token will expire in
  /// one hour from the time the response was generated.
  ///
  /// If omitted, the authorization server SHOULD provide the expiration time
  /// via other means or document the default value.
  @JsonKey(
    name: OidcConstants_AuthParameters.expiresIn,
    fromJson: OidcInternalUtilities.durationFromJson,
  )
  final Duration? expiresIn;

  /// OPTIONAL.
  ///
  /// The refresh token, which can be used to obtain new access tokens based on
  /// the grant passed in the corresponding token request.
  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  final String? refreshToken;

  /// The session state used in the session management spec.
  @JsonKey(name: OidcConstants_AuthParameters.sessionState)
  final String? sessionState;
}
