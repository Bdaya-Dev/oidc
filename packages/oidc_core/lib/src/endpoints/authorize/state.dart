import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

part 'state.g.dart';

/// Represents a state that takes a snapshot of the request parameters
/// and some settings to ensure nothing changes during the flow.
@JsonSerializable(
  createFactory: true,
  createToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcAuthorizeState extends OidcState {
  ///
  OidcAuthorizeState({
    required this.redirectUri,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.originalUri,
    required this.nonce,
    required this.clientId,
    required this.extraTokenParams,
    required this.extraTokenHeaders,
    required this.options,
    this.maxAge,
    super.id,
    super.createdAt,
    super.data,
    super.managerId,
  }) : super(
         operationDiscriminator:
             OidcConstants_OperationDiscriminators.authorize,
       );

  ///
  factory OidcAuthorizeState.fromJson(Map<String, dynamic> src) =>
      _$OidcAuthorizeStateFromJson(src);

  @JsonKey(name: OidcConstants_Store.extraTokenHeaders)
  Map<String, String>? extraTokenHeaders;

  @JsonKey(name: OidcConstants_Store.extraTokenParams)
  Map<String, dynamic>? extraTokenParams;

  @JsonKey(name: OidcConstants_Store.options)
  Map<String, dynamic>? options;

  /// The same code_challenge that was used to obtain the authorization_code
  /// via PKCE.
  @JsonKey(name: OidcConstants_AuthParameters.codeChallenge)
  String? codeChallenge;

  /// The same code_verifier that was used to obtain the authorization_code
  /// via PKCE.
  @JsonKey(name: OidcConstants_AuthParameters.codeVerifier)
  String? codeVerifier;

  /// The redirectUri that was passed.
  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  Uri redirectUri;

  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  String clientId;

  /// The uri to go back to after the page in `redirectUri`
  /// processes the response.
  @JsonKey(name: OidcConstants_Store.originalUri)
  Uri? originalUri;

  @JsonKey(name: OidcConstants_AuthParameters.nonce)
  String nonce;

  /// The `max_age` that was requested on the authorization request, persisted
  /// so the returned id_token's `auth_time` can be validated against it
  /// (OpenID Connect Core §3.1.2.1) after the redirect round-trip. Serialized
  /// as integer seconds via [OidcDurationSecondsConverter].
  @JsonKey(name: OidcConstants_AuthParameters.maxAge)
  Duration? maxAge;

  @override
  Map<String, dynamic> toJson() => _$OidcAuthorizeStateToJson(this);
}
