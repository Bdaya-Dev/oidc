import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'client_auth.g.dart';

@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
)
class OidcClientAuthentication {
  const OidcClientAuthentication({
    required this.clientId,
    this.clientSecret,
  });

  @JsonKey(name: 'client_id')
  final String clientId;
  @JsonKey(name: 'client_secret')
  final String? clientSecret;

  String getBasicAuth() {
    assert(
      clientSecret != null,
      "Client secret can't be null when using basic auth.",
    );
    return base64.encode(
      utf8.encode(
        [
          clientId,
          if (clientSecret != null) clientSecret,
        ].join(':'),
      ),
    );
  }

  Map<String, String> getBodyParameters() =>
      _$OidcClientAuthenticationToJson(this).cast<String, String>();
}
