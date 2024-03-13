import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'request.g.dart';

@JsonSerializable(
  createFactory: false,
  createToJson: true,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcEndSessionRequest extends JsonBasedRequest {
  const OidcEndSessionRequest({
    this.idTokenHint,
    this.logoutHint,
    this.clientId,
    this.postLogoutRedirectUri,
    this.state,
    this.uiLocales,
    super.extra,
  });

  /// RECOMMENDED.
  ///
  /// ID Token previously issued by the OP to the RP passed to the Logout
  /// Endpoint as a hint about the End-User's current authenticated session
  /// with the Client.
  ///
  /// This is used as an indication of the identity of the End-User that the RP
  /// is requesting be logged out by the OP.
  @JsonKey(name: OidcConstants_AuthParameters.idTokenHint)
  final String? idTokenHint;

  /// OPTIONAL.
  ///
  /// Hint to the Authorization Server about the End-User that is logging out.
  ///
  /// The value and meaning of this parameter is left up to the OP's discretion.
  ///
  /// For instance, the value might contain an email address, phone number,
  /// username, or session identifier pertaining to the RP's session with the OP
  /// for the End-User.
  ///
  /// (This parameter is intended to be analogous to the login_hint parameter
  /// that is used in Authentication Requests; whereas, `logout_hint` is used in
  /// RP-Initiated Logout Requests.)
  @JsonKey(name: OidcConstants_AuthParameters.logoutHint)
  final String? logoutHint;

  /// OPTIONAL.
  ///
  /// OAuth 2.0 Client Identifier valid at the Authorization Server.
  ///
  /// When both client_id and id_token_hint are present, the OP MUST verify that
  /// the Client Identifier matches the one used when issuing the ID Token.
  ///
  /// The most common use case for this parameter is to specify the Client
  /// Identifier when post_logout_redirect_uri is used but id_token_hint is not.
  ///
  /// Another use is for symmetrically encrypted ID Tokens used as id_token_hint
  /// values that require the Client Identifier to be specified by other means,
  /// so that the ID Tokens can be decrypted by the OP.
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  final String? clientId;

  /// OPTIONAL.
  ///
  /// URI to which the RP is requesting that the End-User's User Agent be
  /// redirected after a logout has been performed.
  ///
  /// This URI SHOULD use the https scheme and MAY contain port, path, and query
  /// parameter components; however, it MAY use the http scheme, provided that
  /// the Client Type is confidential, and provided the OP allows the use of
  /// http RP URIs.
  ///
  /// The URI MAY use an alternate scheme, such as one that is intended to
  /// identify a callback into a native application.
  ///
  /// The value MUST have been previously registered with the OP, either using
  /// the post_logout_redirect_uris Registration parameter or via another
  /// mechanism.
  ///
  /// An id_token_hint is also RECOMMENDED when this parameter is included.
  @JsonKey(name: OidcConstants_AuthParameters.postLogoutRedirectUri)
  final Uri? postLogoutRedirectUri;

  /// OPTIONAL.
  ///
  /// Opaque value used by the RP to maintain state between the logout request
  /// and the callback to the endpoint specified by the
  /// `post_logout_redirect_uri` parameter.
  ///
  /// If included in the logout request, the OP passes this value back to the
  /// RP using the state parameter when redirecting the User Agent back to
  /// the RP.
  @JsonKey(name: OidcConstants_AuthParameters.state)
  final String? state;

  /// OPTIONAL.
  ///
  /// End-User's preferred languages and scripts for the user interface,
  /// represented as a space-separated list of BCP47 language tag values,
  /// ordered by preference.
  ///
  /// For instance, the value "fr-CA fr en" represents a preference for French
  /// as spoken in Canada, then French (without a region designation), followed
  /// by English (without a region designation).
  ///
  /// An error SHOULD NOT result if some or all of the requested locales are not
  /// supported by the OpenID Provider.
  @JsonKey(
    name: OidcConstants_AuthParameters.uiLocales,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  final List<String>? uiLocales;

  @override
  Map<String, dynamic> toMap() => {
        ..._$OidcEndSessionRequestToJson(this),
        ...super.toMap(),
      };

  Uri generateUri(Uri endpoint) => endpoint.replace(
        queryParameters: {
          ...endpoint.queryParameters,
          ...OidcInternalUtilities.serializeQueryParameters(toMap()),
        },
      );
}
