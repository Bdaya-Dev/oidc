import 'package:json_annotation/json_annotation.dart';

import 'error.dart';
import 'success.dart';

abstract class OidcAuthResponseBase {
  @JsonKey(name: 'state')
  final String? state;
  @JsonKey(name: 'session_state')
  final String? sessionState;

  factory OidcAuthResponseBase.fromJson(Map<String, dynamic> src) {
    if (src.containsKey(OidcErrorAuthResponse.kerror)) {
      return OidcErrorAuthResponse.fromJson(src);
    } else {
      //a success response must contain at least one of:
      // - id_token
      // - code
      // - access_token
      assert(
        src.containsKey(OidcSuccessAuthResponse.kaccessToken) ||
            src.containsKey(OidcSuccessAuthResponse.kcode) ||
            src.containsKey(OidcSuccessAuthResponse.kidToken),
      );
      return OidcSuccessAuthResponse.fromJson(src);
    }
  }

  const OidcAuthResponseBase({
    this.state,
    this.sessionState,
  });
}
