import 'dart:convert';

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
  const OidcAuthorizeState({
    required super.id,
    required super.createdAt,
    required super.requestType,
    required this.redirectUri,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.originalUri,
    required this.nonce,
    required this.clientId,
    required this.extraTokenParams,
    required this.webLaunchMode,
    super.data,
  });

  ///
  factory OidcAuthorizeState.fromJson(Map<String, dynamic> src) =>
      _$OidcAuthorizeStateFromJson(src);

  /// restores [OidcAuthorizeState] from storage string
  factory OidcAuthorizeState.fromStorageString(String storageString) =>
      OidcAuthorizeState.fromJson(
        jsonDecode(storageString) as Map<String, dynamic>,
      );

  @JsonKey(name: 'extraTokenParams')
  final Map<String, dynamic>? extraTokenParams;

  @JsonKey(name: 'webLaunchMode')
  final String? webLaunchMode;

  /// The same code_challenge that was used to obtain the authorization_code
  /// via PKCE.
  @JsonKey(name: OidcConstants_AuthParameters.codeChallenge)
  final String? codeChallenge;

  /// The same code_verifier that was used to obtain the authorization_code
  /// via PKCE.
  @JsonKey(name: OidcConstants_AuthParameters.codeVerifier)
  final String? codeVerifier;

  /// The uri to go back to after the page in `redirectUri`
  /// processes the response.
  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  final Uri redirectUri;

  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String clientId;

  /// The uri to go back to after the page in `redirectUri`
  /// processes the response.
  @JsonKey(name: 'original_uri')
  final Uri? originalUri;

  @JsonKey(name: OidcConstants_AuthParameters.nonce)
  final String nonce;

  @override
  Map<String, dynamic> toJson() => _$OidcAuthorizeStateToJson(this);
}
