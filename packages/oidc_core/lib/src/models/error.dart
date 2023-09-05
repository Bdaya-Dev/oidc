import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/helpers/converters.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'error.g.dart';

///
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: commonConverters,
)
class OidcErrorResponse extends JsonBasedResponse {
  ///
  const OidcErrorResponse({
    required super.src,
    required this.error,
    this.errorDescription,
    this.errorUri,
    this.iss,
    this.state,
  });

  ///creates an error response from json
  factory OidcErrorResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcErrorAuthResponseFromJson(src);

  /// error
  static const kerror = 'error';

  /// REQUIRED.
  ///
  /// Error code.
  @JsonKey(name: kerror)
  final String error;

  /// OPTIONAL.
  ///
  /// Human-readable ASCII encoded text description of the error.
  @JsonKey(name: 'error_description')
  final String? errorDescription;

  /// OPTIONAL.
  ///
  /// URI of a web page that includes additional information about the error.
  @JsonKey(name: 'error_uri')
  final Uri? errorUri;

  /// REQUIRED, if the Authorization Request included the state parameter.
  ///
  /// OAuth 2.0 state value.
  ///
  /// Set to the value received from the Client.
  @JsonKey(name: 'state')
  final String? state;

  /// OPTIONAL.
  ///
  /// The identifier of the authorization server which the client can use to
  /// prevent mixup attacks, if the client interacts with more than one
  /// authorization server.
  ///
  ///  See [RFC9207](https://www.rfc-editor.org/rfc/rfc9207.html) for additional details on when this parameter is necessary, and how the client can use it to prevent mixup attacks.
  @JsonKey(name: 'iss')
  final Uri? iss;
}
