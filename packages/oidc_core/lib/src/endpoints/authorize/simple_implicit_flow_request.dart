import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

/// This authorization request takes only the minimal parameters and generates
/// the rest.
///
/// this is a simpler version of [OidcAuthorizeRequest].
class OidcSimpleImplicitFlowRequest {
  /// Creates a simple authorization code request.
  OidcSimpleImplicitFlowRequest({
    required this.responseType,
    required this.scope,
    required this.clientId,
    required this.redirectUri,
    this.originalUri,
    this.display,
    this.prompt,
    this.maxAge,
    this.uiLocales,
    this.idTokenHint,
    this.loginHint,
    this.acrValues,
    this.extraStateData,
    this.extraParameters,
    this.options,
  });

  /// Arbitrary options that will be persisted in the state and roundtripped
  /// when the response is received.
  ///
  /// it MUST be json serializable.
  Map<String, dynamic>? options;

  /// possible values are in [OidcConstants_AuthorizationEndpoint_ResponseType].
  @JsonKey(name: OidcConstants_AuthParameters.responseType)
  List<String> responseType;

  /// Extra state data that will be persisted and roundtripped when the response
  /// is received.
  ///
  /// it MUST be json serializable.
  dynamic extraStateData;

  /// see [OidcAuthorizeRequest.scope].
  List<String> scope;

  /// see [OidcAuthorizeRequest.clientId].
  String clientId;

  /// see [OidcAuthorizeRequest.redirectUri].
  Uri redirectUri;

  /// The original uri to go back to after the authorization succeeds,
  /// if null, defaults to [redirectUri].
  Uri? originalUri;

  /// see [OidcAuthorizeRequest.display].
  String? display;

  /// see [OidcAuthorizeRequest.prompt].
  List<String>? prompt;

  /// see [OidcAuthorizeRequest.maxAge].
  Duration? maxAge;

  /// see [OidcAuthorizeRequest.uiLocales].
  List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.idTokenHint].
  String? idTokenHint;

  /// see [OidcAuthorizeRequest.loginHint].
  String? loginHint;

  /// see [OidcAuthorizeRequest.acrValues].
  List<String>? acrValues;

  /// see [OidcAuthorizeRequest.extra].
  Map<String, dynamic>? extraParameters;
}
