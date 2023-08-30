import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

import 'base.dart';

part 'error.g.dart';

///
@JsonSerializable(
  createFactory: true,
  createToJson: false,
)
class OidcErrorAuthResponse extends OidcAuthorizeResponseBase {
  ///
  const OidcErrorAuthResponse({
    required super.src,
    required this.error,
    this.errorDescription,
    this.errorUri,
    super.sessionState,
    super.state,
  });

  ///creates an error response from json
  factory OidcErrorAuthResponse.fromJson(Map<String, dynamic> src) =>
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
  final String? errorUri;
}
