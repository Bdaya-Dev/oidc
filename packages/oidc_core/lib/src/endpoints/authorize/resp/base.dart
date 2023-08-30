import 'package:json_annotation/json_annotation.dart';

import 'package:oidc_core/src/endpoints/authorize/resp/error.dart';
import 'package:oidc_core/src/endpoints/authorize/resp/success.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

/// The base class for all /authorize responses.
abstract class OidcAuthorizeResponseBase extends JsonBasedResponse {
  ///
  const OidcAuthorizeResponseBase({
    required super.src,
    this.state,
    this.sessionState,
  });

  ///
  factory OidcAuthorizeResponseBase.fromJson(Map<String, dynamic> src) {
    if (src.containsKey(OidcErrorAuthResponse.kerror)) {
      return OidcErrorAuthResponse.fromJson(src);
    } else {
      return OidcAuthorizeResponseSuccess.fromJson(src);
    }
  }

  @JsonKey(name: 'state')
  final String? state;
  @JsonKey(name: 'session_state')
  final String? sessionState;
}
