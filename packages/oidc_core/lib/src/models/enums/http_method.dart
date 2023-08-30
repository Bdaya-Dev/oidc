import 'package:json_annotation/json_annotation.dart';

/// the HTTP method to use when sending the /authorize request.
@JsonEnum(valueField: 'value')
enum OidcAuthorizeRequestHttpMethod {
  /// send the requst as POST, and the body as application/x-www-form-urlencoded
  post('POST'),

  /// send the requst as GET, and the body as query parameters
  get('GET');

  const OidcAuthorizeRequestHttpMethod(this.value);

  /// The HTTP method.
  final String value;
}
