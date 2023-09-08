// ignore_for_file: lines_longer_than_80_chars

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'error.g.dart';

///
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcErrorResponse extends JsonBasedResponse {
  ///
  const OidcErrorResponse({
    required super.src,
    required this.error,
    this.errorDescription,
    this.errorUri,
    this.iss,
    this.sessionState,
    this.state,
  });

  ///creates an error response from json
  factory OidcErrorResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcErrorResponseFromJson(src);

  /// REQUIRED.
  ///
  /// Error code.
  @JsonKey(name: OidcConstants_AuthParameters.error)
  final String error;

  /// OPTIONAL.
  ///
  /// Human-readable ASCII encoded text description of the error.
  @JsonKey(name: OidcConstants_AuthParameters.errorDescription)
  final String? errorDescription;

  /// OPTIONAL.
  ///
  /// URI of a web page that includes additional information about the error.
  @JsonKey(name: OidcConstants_AuthParameters.errorUri)
  final Uri? errorUri;

  /// REQUIRED, if the Authorization Request included the state parameter.
  ///
  /// OAuth 2.0 state value.
  ///
  /// Set to the value received from the Client.
  @JsonKey(name: OidcConstants_AuthParameters.state)
  final String? state;

  /// Session State.
  ///
  /// JSON string that represents the End-User's login state at the OP.
  ///
  /// It MUST NOT contain the space (" ") character. This value is opaque to the RP.
  ///
  /// This is REQUIRED if session management is supported.
  @JsonKey(name: OidcConstants_AuthParameters.sessionState)
  final String? sessionState;

  /// OPTIONAL.
  ///
  /// The identifier of the authorization server which the client can use to
  /// prevent mixup attacks, if the client interacts with more than one
  /// authorization server.
  ///
  ///  See [RFC9207](https://www.rfc-editor.org/rfc/rfc9207.html) for additional details on when this parameter is necessary, and how the client can use it to prevent mixup attacks.
  @JsonKey(name: OidcConstants_AuthParameters.iss)
  final Uri? iss;
}
